//! Sandbox Lua (mlua) para executar ferramentas da pasta `tools/` com a API
//! `geny.*` (Fase 4 — TODO core-07).
//!
//! As ferramentas Lua são arquivos `.lua` com um manifesto embutido num
//! comentário de bloco:
//!
//! ```text
//! --[==[ Geny Tool
//! id: examples.greet
//! name: Cumprimentar
//! description: Devolve uma saudação personalizada em texto puro.
//! version: 0.1.0
//! confirmation: none
//! permissions: []
//! params:
//!   - name: who
//!     type: string
//!     required: false
//! ]==]--
//! ```
//!
//! Segurança da sandbox:
//! - Lua 5.4 compilada em modo seguro (`StdLib::ALL_SAFE`) — sem `io`, sem
//!   `package`/`require`, sem `dofile`/`loadfile`;
//! - globais perigosas removidas por defesa em profundidade e `os` reduzido a
//!   funções inofensivas de tempo;
//! - teto de memória via `set_memory_limit` e orçamento de instruções via
//!   hook de depuração — loops infinitos são interrompidos;
//! - a API `geny.*` expõe somente o que o host conceder (toast, storage e,
//!   opcionalmente, root com `allow_root`).

use std::fs;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;

use serde_json::Value as JsonValue;

use crate::confirmation::ConfirmationLevel;
use crate::error::{CoreError, Result};
use mlua::LuaSerdeExt;

/// Converte um erro do núcleo num erro Lua dentro dos callbacks do host.
fn lua_err(e: CoreError) -> mlua::Error {
    mlua::Error::RuntimeError(e.to_string())
}

/// Converte um erro Lua num erro do núcleo, com mensagens amigáveis para os
/// casos de limite de memória e orçamento de instruções.
fn map_lua_err(e: mlua::Error) -> CoreError {
    match &e {
        mlua::Error::MemoryError(_) => {
            CoreError::Execution("limite de memoria da sandbox excedido".into())
        }
        mlua::Error::RuntimeError(msg) if msg.contains("orcamento de instrucoes") => {
            CoreError::Execution(msg.clone())
        }
        other => CoreError::Execution(format!("lua: {other}")),
    }
}

/// Parâmetro declarado no manifesto de uma ferramenta Lua.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ManifestParam {
    /// Nome do parâmetro, como enviado no objeto JSON de chamada.
    pub name: String,
    /// Tipo declarado (`string`, `number`, `integer`, `boolean`, `array`,
    /// `object` ou `any`). Desconhecidos são tratados como `any`.
    pub kind: String,
    /// Se `true`, a chamada sem o parâmetro é rejeitada antes de executar.
    pub required: bool,
}

/// Manifesto de uma ferramenta Lua (bloco `--[==[ Geny Tool ... ]==]--`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ToolManifest {
    /// Identificador único, ex. `examples.greet`.
    pub id: String,
    /// Nome curto para a UI.
    pub name: String,
    /// Descrição (pode ocupar várias linhas no manifesto).
    pub description: String,
    /// Versão semver da ferramenta.
    pub version: String,
    /// Nível de confirmação humana exigido antes de cada execução.
    pub confirmation: ConfirmationLevel,
    /// Permissões declaradas, ex. `["root"]`.
    pub permissions: Vec<String>,
    /// Parâmetros aceitos pela ferramenta.
    pub params: Vec<ManifestParam>,
}

/// Divide `chave: valor` no primeiro dois-pontos (o valor pode conter `:`).
fn split_kv(line: &str) -> Option<(&str, &str)> {
    let (k, v) = line.split_once(':')?;
    let k = k.trim();
    if k.is_empty() {
        return None;
    }
    // chave deve ser um identificador simples (sem espaços internos)
    if k.chars().any(|c| c.is_whitespace()) {
        return None;
    }
    Some((k, v.trim()))
}

/// Analisa `[]`, `[root]` ou `[a, b]` numa lista de strings.
fn parse_list(value: &str) -> Vec<String> {
    let inner = value.trim().trim_start_matches('[').trim_end_matches(']');
    inner
        .split(',')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect()
}

/// Mapeia o texto do manifesto para `ConfirmationLevel`.
fn parse_confirmation(value: &str) -> Result<ConfirmationLevel> {
    match value.trim().to_ascii_lowercase().as_str() {
        "none" => Ok(ConfirmationLevel::None),
        "simple" => Ok(ConfirmationLevel::Simple),
        "explicit" => Ok(ConfirmationLevel::Explicit),
        "authenticated" => Ok(ConfirmationLevel::Authenticated),
        other => Err(CoreError::Validation {
            tool: "lua".into(),
            reason: format!("nivel de confirmacao desconhecido: {other}"),
        }),
    }
}

impl ToolManifest {
    /// Extrai e valida o manifesto embutido no código Lua.
    pub fn parse(source: &str) -> Result<ToolManifest> {
        let lines: Vec<&str> = source.lines().collect();
        let start = lines
            .iter()
            .position(|l| l.trim_start().starts_with("--[==[ Geny Tool"))
            .ok_or_else(|| CoreError::Validation {
                tool: "lua".into(),
                reason: "manifesto ausente: cabecalho '--[==[ Geny Tool' nao encontrado".into(),
            })?;
        let end = lines[start..]
            .iter()
            .position(|l| l.contains("]==]--"))
            .map(|p| p + start)
            .ok_or_else(|| CoreError::Validation {
                tool: "lua".into(),
                reason: "manifesto sem terminador ']==]--'".into(),
            })?;

        let mut id: Option<String> = None;
        let mut name: Option<String> = None;
        let mut description = String::new();
        let mut version: Option<String> = None;
        let mut confirmation: Option<ConfirmationLevel> = None;
        let mut permissions: Vec<String> = Vec::new();
        let mut params: Vec<ManifestParam> = Vec::new();
        let mut in_params = false;

        for raw in &lines[start + 1..end] {
            let trimmed = raw.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                continue;
            }
            // novo parâmetro em `params:` — ex.: `- name: who`
            if let Some(rest) = trimmed.strip_prefix("- ") {
                if let Some(("name", v)) = split_kv(rest) {
                    params.push(ManifestParam {
                        name: v.to_string(),
                        kind: "any".into(),
                        required: false,
                    });
                }
                continue;
            }
            // chaves indentadas `type:`/`required:` pertencem ao último parâmetro
            if in_params && (raw.starts_with(' ') || raw.starts_with('\t')) {
                if let Some((k, v)) = split_kv(trimmed) {
                    if let Some(last) = params.last_mut() {
                        match k {
                            "type" => last.kind = v.to_ascii_lowercase(),
                            "required" => last.required = v.eq_ignore_ascii_case("true"),
                            _ => {}
                        }
                    }
                    continue;
                }
            }
            // continuação de valor multilinha (ex.: description longa)
            if (raw.starts_with(' ') || raw.starts_with('\t')) && !description.is_empty() {
                description.push(' ');
                description.push_str(trimmed);
                continue;
            }
            if let Some((k, v)) = split_kv(trimmed) {
                match k {
                    "id" => id = Some(v.to_string()),
                    "name" => name = Some(v.to_string()),
                    "description" => {
                        description.clear();
                        description.push_str(v);
                    }
                    "version" => version = Some(v.to_string()),
                    "confirmation" => confirmation = Some(parse_confirmation(v)?),
                    "permissions" => permissions = parse_list(v),
                    "params" => {
                        in_params = true;
                        continue;
                    }
                    _ => {}
                }
            }
        }

        let missing = |field: &str| CoreError::Validation {
            tool: "lua".into(),
            reason: format!("campo obrigatorio do manifesto ausente: {field}"),
        };
        Ok(ToolManifest {
            id: id.ok_or_else(|| missing("id"))?,
            name: name.ok_or_else(|| missing("name"))?,
            description,
            version: version.ok_or_else(|| missing("version"))?,
            confirmation: confirmation.ok_or_else(|| missing("confirmation"))?,
            permissions,
            params,
        })
    }
}

/// Ferramenta Lua completa: manifesto + corpo do script.
#[derive(Debug, Clone)]
pub struct LuaTool {
    /// Manifesto validado.
    pub manifest: ToolManifest,
    /// Corpo Lua (código sem o comentário de manifesto).
    pub script: String,
}

impl LuaTool {
    /// Compila a fonte Lua: valida o manifesto e separa o corpo do script.
    pub fn from_source(source: &str) -> Result<LuaTool> {
        let manifest = ToolManifest::parse(source)?;
        // o terminador do manifesto é a primeira ocorrência — o manifesto
        // fica sempre no topo do arquivo
        let script = match source.split_once("]==]--") {
            Some((_, rest)) => rest.to_string(),
            None => source.to_string(),
        };
        Ok(LuaTool { manifest, script })
    }

    /// Converte o manifesto para uma `ToolDefinition` do registro padrão,
    /// permitindo anunciar ferramentas Lua no catálogo da ponte.
    pub fn definition(
        &self,
        context: crate::tools::registry::ToolContext,
    ) -> crate::tools::registry::ToolDefinition {
        use crate::tools::registry::{ParamSpec, ParamType};
        let map_kind = |kind: &str| match kind {
            "string" => ParamType::String,
            "number" => ParamType::Number,
            "integer" => ParamType::Integer,
            "boolean" => ParamType::Boolean,
            "array" => ParamType::Array,
            _ => ParamType::Object,
        };
        crate::tools::registry::ToolDefinition {
            id: self.manifest.id.clone(),
            name: self.manifest.name.clone(),
            description: self.manifest.description.clone(),
            params: self
                .manifest
                .params
                .iter()
                .map(|p| ParamSpec {
                    name: p.name.clone(),
                    r#type: map_kind(&p.kind),
                    required: p.required,
                    description: String::new(),
                    allowed_values: None,
                })
                .collect(),
            permissions: self.manifest.permissions.clone(),
            confirmation: self.manifest.confirmation,
            context,
            timeout_ms: 15_000,
        }
    }
}

/// Porta de serviços do host injetada na sandbox como API `geny.*`.
///
/// Implementada pela plataforma (Kotlin via UniFFI) ou por mocks nos testes.
pub trait LuaHost: Send + Sync {
    /// Mostra um toast local (`geny.toast`).
    fn toast(&self, _message: &str) -> Result<()> {
        Err(CoreError::Execution(
            "geny.toast indisponivel neste host".into(),
        ))
    }

    /// Lê um valor persistido (`geny.storage.get`). `None` = chave ausente.
    fn storage_get(&self, _key: &str) -> Result<Option<String>> {
        Ok(None)
    }

    /// Grava um valor persistido (`geny.storage.set`).
    fn storage_set(&self, _key: &str, _value: &str) -> Result<()> {
        Err(CoreError::Execution(
            "geny.storage.set indisponivel neste host".into(),
        ))
    }

    /// Executa comando privilegiado (`geny.root.run`). Só é exposto quando
    /// `SandboxConfig::allow_root` está ativo e o usuário habilitou o modo root.
    fn root_run(&self, _command: &str) -> Result<String> {
        Err(CoreError::ConfirmationDenied("root nao habilitado".into()))
    }
}

/// Host sem serviços (padrão) — toda chamada `geny.*` falha graciosamente.
#[derive(Debug, Default, Clone, Copy)]
pub struct NoopHost;

impl LuaHost for NoopHost {}

/// Variáveis de dispositivo somente leitura expostas como `geny.device`.
#[derive(Debug, Clone, Default)]
pub struct DeviceEnv {
    /// Nível de bateria em percentual, se disponível.
    pub battery_level: Option<i64>,
    /// Se o aparelho está carregando.
    pub charging: Option<bool>,
}

/// Configuração da sandbox.
#[derive(Debug, Clone)]
pub struct SandboxConfig {
    /// Teto de memória da VM Lua. Padrão: 8 MiB.
    pub memory_bytes: usize,
    /// Orçamento total de instruções VM antes de interromper o script.
    /// Padrão: 300 milhões (~1 s de CPU).
    pub instruction_budget: u64,
    /// Frequência do hook de interrupção (a cada N instruções). Padrão: 100 mil.
    pub hook_interval: u32,
    /// Expõe `geny.root` para ferramentas privilegiadas (Fase 7). Padrão: falso.
    pub allow_root: bool,
}

impl Default for SandboxConfig {
    fn default() -> Self {
        SandboxConfig {
            memory_bytes: 8 * 1024 * 1024,
            instruction_budget: 300_000_000,
            hook_interval: 100_000,
            allow_root: false,
        }
    }
}

/// Sandbox Lua segura para executar ferramentas `tools/`.
pub struct LuaSandbox {
    lua: mlua::Lua,
    host: Arc<dyn LuaHost>,
    config: SandboxConfig,
    /// Referência de tempo para `os.clock` (tempo de CPU da sandbox).
    started: std::time::Instant,
}

impl LuaSandbox {
    /// Cria a sandbox com globais higienizadas, limites configurados e a API
    /// `geny.*` injetada conforme o host e o dispositivo.
    pub fn new(host: Arc<dyn LuaHost>, device: DeviceEnv, config: SandboxConfig) -> Result<Self> {
        let lua = mlua::Lua::new_with(mlua::StdLib::ALL_SAFE, mlua::LuaOptions::new())
            .map_err(|e| CoreError::Internal(format!("lua indisponivel: {e}")))?;
        lua.set_memory_limit(config.memory_bytes)
            .map_err(|e| CoreError::Internal(format!("limite de memoria lua: {e}")))?;
        let sandbox = LuaSandbox {
            lua,
            host,
            config,
            started: std::time::Instant::now(),
        };
        sandbox.sanitize_globals()?;
        sandbox.inject_api(device)?;
        sandbox.install_budget_hook()?;
        Ok(sandbox)
    }

    /// Remove globais perigosas por defesa em profundidade (mesmo com
    /// `ALL_SAFE`) e reduz `os` a funções inofensivas de tempo.
    fn sanitize_globals(&self) -> Result<()> {
        let globals = self.lua.globals();
        for name in [
            "io",
            "package",
            "require",
            "dofile",
            "loadfile",
            "load",
            "loadstring",
            "collectgarbage",
        ] {
            globals
                .raw_set(name, mlua::Value::Nil)
                .map_err(map_lua_err)?;
        }
        let os = self.lua.create_table().map_err(map_lua_err)?;
        os.raw_set(
            "time",
            self.lua
                .create_function(|_, ()| {
                    Ok(std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .map(|d| d.as_secs())
                        .unwrap_or(0))
                })
                .map_err(map_lua_err)?,
        )
        .map_err(map_lua_err)?;
        let started = self.started;
        os.raw_set(
            "clock",
            self.lua
                .create_function(move |_, ()| Ok(started.elapsed().as_secs_f64()))
                .map_err(map_lua_err)?,
        )
        .map_err(map_lua_err)?;
        globals.raw_set("os", os).map_err(map_lua_err)?;
        Ok(())
    }

    /// Injeta a API `geny.*` (toast, storage, device e root opcional).
    fn inject_api(&self, device: DeviceEnv) -> Result<()> {
        let lua = &self.lua;
        let geny = lua.create_table().map_err(map_lua_err)?;

        // geny.toast(msg)
        let host = Arc::clone(&self.host);
        geny.raw_set(
            "toast",
            lua.create_function(move |_, msg: String| host.toast(&msg).map_err(lua_err))
                .map_err(map_lua_err)?,
        )
        .map_err(map_lua_err)?;

        // geny.storage.{get, set}
        let storage = lua.create_table().map_err(map_lua_err)?;
        let host = Arc::clone(&self.host);
        storage
            .raw_set(
                "get",
                lua.create_function(move |_, key: String| host.storage_get(&key).map_err(lua_err))
                    .map_err(map_lua_err)?,
            )
            .map_err(map_lua_err)?;
        let host = Arc::clone(&self.host);
        storage
            .raw_set(
                "set",
                lua.create_function(move |_, (key, value): (String, String)| {
                    host.storage_set(&key, &value).map_err(lua_err)?;
                    Ok(())
                })
                .map_err(map_lua_err)?,
            )
            .map_err(map_lua_err)?;
        geny.raw_set("storage", storage).map_err(map_lua_err)?;

        // geny.device (somente leitura)
        let device_t = lua.create_table().map_err(map_lua_err)?;
        if let Some(level) = device.battery_level {
            device_t
                .raw_set("battery_level", level)
                .map_err(map_lua_err)?;
        }
        if let Some(charging) = device.charging {
            device_t
                .raw_set("charging", charging)
                .map_err(map_lua_err)?;
        }
        geny.raw_set("device", device_t).map_err(map_lua_err)?;

        // geny.now_ms() — relógio de época em milissegundos
        geny.raw_set(
            "now_ms",
            lua.create_function(|_, ()| {
                Ok(std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .map(|d| d.as_millis() as i64)
                    .unwrap_or(0))
            })
            .map_err(map_lua_err)?,
        )
        .map_err(map_lua_err)?;

        // geny.root.run — só existe com allow_root (Fase 7)
        if self.config.allow_root {
            let root = lua.create_table().map_err(map_lua_err)?;
            let host = Arc::clone(&self.host);
            root.raw_set(
                "run",
                lua.create_function(move |_, cmd: String| {
                    // contrato Lua: local ok, output = geny.root.run(cmd)
                    let output = host.root_run(&cmd).map_err(lua_err)?;
                    Ok((true, output))
                })
                .map_err(map_lua_err)?,
            )
            .map_err(map_lua_err)?;
            geny.raw_set("root", root).map_err(map_lua_err)?;
        }

        self.lua
            .globals()
            .raw_set("geny", geny)
            .map_err(map_lua_err)?;
        Ok(())
    }

    /// Instala o hook que interrompe scripts que excedem o orçamento de
    /// instruções (defesa contra loops infinitos).
    fn install_budget_hook(&self) -> Result<()> {
        let used = Arc::new(AtomicU64::new(0));
        let budget = self.config.instruction_budget;
        let interval = self.config.hook_interval;
        self.lua
            .set_hook(
                mlua::HookTriggers::new().every_nth_instruction(interval),
                move |_lua, _dbg| {
                    let total = used.fetch_add(u64::from(interval), Ordering::Relaxed)
                        + u64::from(interval);
                    if total > budget {
                        Err(mlua::Error::RuntimeError(format!(
                            "orcamento de instrucoes excedido ({budget})"
                        )))
                    } else {
                        Ok(mlua::VmState::Continue)
                    }
                },
            )
            .map_err(|e| CoreError::Internal(format!("hook de orcamento de instrucoes: {e}")))?;
        Ok(())
    }

    /// Valida os parâmetros JSON contra o manifesto antes de executar.
    fn validate_params(&self, tool: &LuaTool, params: &JsonValue) -> Result<()> {
        let obj = params.as_object().ok_or_else(|| CoreError::Validation {
            tool: tool.manifest.id.clone(),
            reason: "parametros devem ser um objeto JSON".into(),
        })?;
        for p in &tool.manifest.params {
            let value = obj.get(&p.name);
            let is_missing = matches!(value, None | Some(JsonValue::Null));
            if is_missing {
                if p.required {
                    return Err(CoreError::Validation {
                        tool: tool.manifest.id.clone(),
                        reason: format!("parametro obrigatorio ausente: {}", p.name),
                    });
                }
                continue;
            }
            let v = value.unwrap_or(&JsonValue::Null);
            let ok = match p.kind.as_str() {
                "string" => v.is_string(),
                "boolean" => v.is_boolean(),
                "number" | "integer" => v.is_number(),
                "array" => v.is_array(),
                "object" => v.is_object(),
                _ => true,
            };
            if !ok {
                return Err(CoreError::Validation {
                    tool: tool.manifest.id.clone(),
                    reason: format!("parametro '{}' deveria ser {}", p.name, p.kind),
                });
            }
        }
        Ok(())
    }

    /// Executa `geny_run(params)` da ferramenta dentro da sandbox e devolve o
    /// resultado convertido para JSON.
    pub fn run(&self, tool: &LuaTool, params: &JsonValue) -> Result<JsonValue> {
        self.validate_params(tool, params)?;
        let lua = &self.lua;

        lua.load(&tool.script)
            .set_name(tool.manifest.id.as_str())
            .exec()
            .map_err(map_lua_err)?;

        let func: mlua::Function = lua.globals().raw_get("geny_run").map_err(map_lua_err)?;

        let args: mlua::Value = lua.to_value(params).map_err(map_lua_err)?;
        let result: mlua::Value = func.call(args).map_err(map_lua_err)?;

        match result {
            mlua::Value::Nil => Ok(JsonValue::Null),
            v => lua.from_value::<JsonValue>(v).map_err(map_lua_err),
        }
    }
}

/// Carrega todas as ferramentas Lua de um diretório (ordenadas por caminho).
pub fn load_tools_from_dir(dir: &Path) -> Result<Vec<LuaTool>> {
    let entries = fs::read_dir(dir)
        .map_err(|e| CoreError::Internal(format!("nao foi possivel ler {}: {e}", dir.display())))?;
    let mut paths: Vec<std::path::PathBuf> =
        entries.filter_map(|e| e.ok().map(|e| e.path())).collect();
    paths.sort();
    let mut tools = Vec::new();
    for path in paths {
        if path.extension().and_then(|e| e.to_str()) == Some("lua") {
            let src = fs::read_to_string(&path).map_err(|e| {
                CoreError::Internal(format!("leitura de {} falhou: {e}", path.display()))
            })?;
            tools.push(LuaTool::from_source(&src)?);
        }
    }
    Ok(tools)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;
    use std::sync::Mutex;

    /// Host de teste com storage, captura de toasts e root registrável.
    struct MockHost {
        storage: Mutex<HashMap<String, String>>,
        toasts: Mutex<Vec<String>>,
        root_calls: Mutex<Vec<String>>,
    }

    impl MockHost {
        fn new() -> Self {
            MockHost {
                storage: Mutex::new(HashMap::new()),
                toasts: Mutex::new(Vec::new()),
                root_calls: Mutex::new(Vec::new()),
            }
        }
    }

    impl LuaHost for MockHost {
        fn toast(&self, message: &str) -> Result<()> {
            self.toasts.lock().unwrap().push(message.to_string());
            Ok(())
        }
        fn storage_get(&self, key: &str) -> Result<Option<String>> {
            Ok(self.storage.lock().unwrap().get(key).cloned())
        }
        fn storage_set(&self, key: &str, value: &str) -> Result<()> {
            self.storage
                .lock()
                .unwrap()
                .insert(key.to_string(), value.to_string());
            Ok(())
        }
        fn root_run(&self, command: &str) -> Result<String> {
            self.root_calls.lock().unwrap().push(command.to_string());
            Ok(format!("executado: {command}"))
        }
    }

    fn examples_dir() -> std::path::PathBuf {
        std::path::PathBuf::from(concat!(env!("CARGO_MANIFEST_DIR"), "/../tools/examples"))
    }

    fn sandbox_with(host: Arc<dyn LuaHost>, config: SandboxConfig) -> LuaSandbox {
        LuaSandbox::new(host, DeviceEnv::default(), config).expect("sandbox criada")
    }

    #[test]
    fn manifesto_do_greet_e_parseado() {
        let tools = load_tools_from_dir(&examples_dir()).expect("exemplos carregados");
        let greet = tools
            .iter()
            .find(|t| t.manifest.id == "examples.greet")
            .expect("greet presente");
        assert_eq!(greet.manifest.name, "Cumprimentar");
        assert_eq!(greet.manifest.confirmation, ConfirmationLevel::None);
        assert!(greet.manifest.permissions.is_empty());
        let who = greet.manifest.params.first().expect("param who");
        assert_eq!(who.name, "who");
        assert_eq!(who.kind, "string");
        assert!(!who.required);
    }

    #[test]
    fn manifestos_dos_tres_exemplos_sao_validos() {
        let tools = load_tools_from_dir(&examples_dir()).expect("exemplos carregados");
        assert_eq!(tools.len(), 3, "greet, battery_report e system_cleaner");
        let cleaner = tools
            .iter()
            .find(|t| t.manifest.id == "examples.system_cleaner")
            .expect("system_cleaner presente");
        assert_eq!(
            cleaner.manifest.confirmation,
            ConfirmationLevel::Authenticated
        );
        assert_eq!(cleaner.manifest.permissions, vec!["root".to_string()]);
        // description multilinha é concatenada com espaço
        assert!(cleaner.manifest.description.contains("EXEMPLO EDUCATIVO"));
    }

    #[test]
    fn greet_executa_com_e_sem_parametro() {
        let sandbox = sandbox_with(Arc::new(NoopHost), SandboxConfig::default());
        let tools = load_tools_from_dir(&examples_dir()).unwrap();
        let greet = tools
            .iter()
            .find(|t| t.manifest.id == "examples.greet")
            .unwrap();

        let out = sandbox.run(greet, &serde_json::json!({})).unwrap();
        assert!(
            out["greeting"].as_str().unwrap().contains("mundo"),
            "saudacao padrao: {out}"
        );

        let out = sandbox
            .run(greet, &serde_json::json!({ "who": "Ana" }))
            .unwrap();
        assert!(out["greeting"].as_str().unwrap().contains("Ana"));
    }

    #[test]
    fn battery_report_usa_storage_toast_e_device() {
        let host = Arc::new(MockHost::new());
        let device = DeviceEnv {
            battery_level: Some(73),
            charging: Some(false),
        };
        let sandbox = LuaSandbox::new(
            Arc::clone(&host) as Arc<dyn LuaHost>,
            device,
            SandboxConfig::default(),
        )
        .unwrap();
        let tools = load_tools_from_dir(&examples_dir()).unwrap();
        let battery = tools
            .iter()
            .find(|t| t.manifest.id == "examples.battery_report")
            .unwrap();

        let out = sandbox.run(battery, &serde_json::json!({})).unwrap();
        assert_eq!(out["level"].as_i64(), Some(73));
        assert!(out["message"].as_str().unwrap().contains("73%"));
        assert_eq!(
            host.storage
                .lock()
                .unwrap()
                .get("last_level")
                .map(String::as_str),
            Some("73")
        );
        {
            let toasts = host.toasts.lock().unwrap();
            assert!(toasts.iter().any(|t| t.contains("Bateria")));
        } // guard liberado antes da segunda execução (evita deadlock do Mutex)

        // segunda leitura com bateria maior registra a tendência
        let device = DeviceEnv {
            battery_level: Some(80),
            charging: None,
        };
        let sandbox2 = LuaSandbox::new(
            Arc::clone(&host) as Arc<dyn LuaHost>,
            device,
            SandboxConfig::default(),
        )
        .unwrap();
        let out = sandbox2.run(battery, &serde_json::json!({})).unwrap();
        assert!(out["message"].as_str().unwrap().contains("subiu"));
    }

    #[test]
    fn system_cleaner_sem_root_falha_graciosamente() {
        // allow_root = false (padrão): geny.root nem existe na sandbox
        let sandbox = sandbox_with(Arc::new(NoopHost), SandboxConfig::default());
        let tools = load_tools_from_dir(&examples_dir()).unwrap();
        let cleaner = tools
            .iter()
            .find(|t| t.manifest.id == "examples.system_cleaner")
            .unwrap();

        let out = sandbox.run(cleaner, &serde_json::json!({})).unwrap();
        assert_eq!(out["ok"].as_bool(), Some(false));
        assert!(out["reason"].as_str().unwrap().contains("root"));
    }

    #[test]
    fn system_cleaner_com_root_respeita_dry_run() {
        let host = Arc::new(MockHost::new());
        let config = SandboxConfig {
            allow_root: true,
            ..SandboxConfig::default()
        };
        let sandbox = LuaSandbox::new(
            Arc::clone(&host) as Arc<dyn LuaHost>,
            DeviceEnv::default(),
            config,
        )
        .unwrap();
        let tools = load_tools_from_dir(&examples_dir()).unwrap();
        let cleaner = tools
            .iter()
            .find(|t| t.manifest.id == "examples.system_cleaner")
            .unwrap();

        // dry_run: mostra o comando mas não executa
        let out = sandbox
            .run(cleaner, &serde_json::json!({ "dry_run": true }))
            .unwrap();
        assert_eq!(out["ok"].as_bool(), Some(true));
        assert_eq!(out["dry_run"].as_bool(), Some(true));
        assert!(out["would_run"].as_str().unwrap().contains("trim-caches"));
        assert!(host.root_calls.lock().unwrap().is_empty());

        // execução real: chama o host
        let out = sandbox.run(cleaner, &serde_json::json!({})).unwrap();
        assert_eq!(out["ok"].as_bool(), Some(true));
        let calls = host.root_calls.lock().unwrap();
        assert_eq!(calls.len(), 1);
        assert!(calls[0].contains("pm trim-caches"));
    }

    #[test]
    fn sandbox_bloqueia_io_require_e_os_perigosos() {
        let sandbox = sandbox_with(Arc::new(NoopHost), SandboxConfig::default());
        let probe = r#"
            return {
                io = io ~= nil,
                require = require ~= nil,
                dofile = dofile ~= nil,
                loadfile = loadfile ~= nil,
                package = package ~= nil,
                load = load ~= nil,
                os_execute = os ~= nil and os.execute ~= nil,
                os_remove = os ~= nil and os.remove ~= nil,
                os_getenv = os ~= nil and os.getenv ~= nil,
                os_time = os ~= nil and os.time ~= nil
            }
        "#;
        let raw: mlua::Value = sandbox
            .lua
            .load(probe)
            .set_name("probe")
            .eval()
            .expect("probe roda");
        let result: JsonValue = sandbox.lua.from_value(raw).expect("tabela json");
        assert_eq!(result["io"].as_bool(), Some(false));
        assert_eq!(result["require"].as_bool(), Some(false));
        assert_eq!(result["dofile"].as_bool(), Some(false));
        assert_eq!(result["loadfile"].as_bool(), Some(false));
        assert_eq!(result["package"].as_bool(), Some(false));
        assert_eq!(result["load"].as_bool(), Some(false));
        assert_eq!(result["os_execute"].as_bool(), Some(false));
        assert_eq!(result["os_remove"].as_bool(), Some(false));
        assert_eq!(result["os_getenv"].as_bool(), Some(false));
        assert_eq!(result["os_time"].as_bool(), Some(true), "os.time é seguro");
    }

    #[test]
    fn now_ms_e_exposto_com_relogio_de_epoca() {
        let sandbox = sandbox_with(Arc::new(NoopHost), SandboxConfig::default());
        let source = concat!(
            "--[==[ Geny Tool\n",
            "id: test.clock\n",
            "name: Relogio\n",
            "description: consulta o tempo\n",
            "version: 0.1.0\n",
            "confirmation: none\n",
            "permissions: []\n",
            "params: []\n",
            "]==]--\n",
            "function geny_run(_p)\n",
            "  return { now = geny.now_ms(), clock = os.clock(), epoch = os.time() }\n",
            "end\n"
        );
        let tool = LuaTool::from_source(source).unwrap();
        let out = sandbox.run(&tool, &serde_json::json!({})).unwrap();
        let now = out["now"].as_i64().expect("now_ms inteiro");
        assert!(now > 1_600_000_000_000, "epoch ms plausivel: {now}");
        assert!(out["epoch"].as_i64().unwrap_or(0) > 1_600_000_000);
        assert!(out["clock"].as_f64().unwrap_or(-1.0) >= 0.0);
    }

    #[test]
    fn tentativa_de_usar_io_falha() {
        let sandbox = sandbox_with(Arc::new(NoopHost), SandboxConfig::default());
        let source = concat!(
            "--[==[ Geny Tool\n",
            "id: test.bad\n",
            "name: Ruim\n",
            "description: tenta io\n",
            "version: 0.1.0\n",
            "confirmation: none\n",
            "permissions: []\n",
            "params: []\n",
            "]==]--\n",
            "function geny_run(_p)\n",
            "  local f = io.open('/etc/passwd', 'r')\n",
            "  return { ok = f ~= nil }\n",
            "end\n"
        );
        let tool = LuaTool::from_source(source).unwrap();
        let err = sandbox.run(&tool, &serde_json::json!({})).unwrap_err();
        assert!(err.to_string().contains("lua"), "erro lua: {err}");
    }

    #[test]
    fn loop_infinito_e_interrompido_pelo_orcamento() {
        let config = SandboxConfig {
            instruction_budget: 2_000_000,
            hook_interval: 50_000,
            ..SandboxConfig::default()
        };
        let sandbox = sandbox_with(Arc::new(NoopHost), config);
        let source = concat!(
            "--[==[ Geny Tool\n",
            "id: test.loop\n",
            "name: Loop\n",
            "description: loop infinito\n",
            "version: 0.1.0\n",
            "confirmation: none\n",
            "permissions: []\n",
            "params: []\n",
            "]==]--\n",
            "function geny_run(_p)\n",
            "  while true do end\n",
            "end\n"
        );
        let tool = LuaTool::from_source(source).unwrap();
        let err = sandbox.run(&tool, &serde_json::json!({})).unwrap_err();
        assert!(
            err.to_string().contains("orcamento de instrucoes"),
            "erro esperado: {err}"
        );
    }

    #[test]
    fn limite_de_memoria_aplicado() {
        let config = SandboxConfig {
            memory_bytes: 256 * 1024,
            ..SandboxConfig::default()
        };
        let sandbox = sandbox_with(Arc::new(NoopHost), config);
        let source = concat!(
            "--[==[ Geny Tool\n",
            "id: test.mem\n",
            "name: Memoria\n",
            "description: aloca demais\n",
            "version: 0.1.0\n",
            "confirmation: none\n",
            "permissions: []\n",
            "params: []\n",
            "]==]--\n",
            "function geny_run(_p)\n",
            "  local t = {}\n",
            "  while true do t[#t+1] = ('x'):rep(1024) end\n",
            "  return {}\n",
            "end\n"
        );
        let tool = LuaTool::from_source(source).unwrap();
        let err = sandbox.run(&tool, &serde_json::json!({})).unwrap_err();
        assert!(
            err.to_string().contains("memoria"),
            "erro de memoria esperado: {err}"
        );
    }

    #[test]
    fn parametro_obrigatorio_ausente_e_rejeitado() {
        let sandbox = sandbox_with(Arc::new(NoopHost), SandboxConfig::default());
        let source = concat!(
            "--[==[ Geny Tool\n",
            "id: test.required\n",
            "name: Obrigatorio\n",
            "description: exige parametro\n",
            "version: 0.1.0\n",
            "confirmation: none\n",
            "permissions: []\n",
            "params:\n",
            "  - name: destino\n",
            "    type: string\n",
            "    required: true\n",
            "]==]--\n",
            "function geny_run(_p)\n",
            "  return { destino = _p.destino }\n",
            "end\n"
        );
        let tool = LuaTool::from_source(source).unwrap();
        let err = sandbox.run(&tool, &serde_json::json!({})).unwrap_err();
        assert!(matches!(err, CoreError::Validation { .. }), "erro: {err}");
        assert!(err.to_string().contains("destino"));

        // com o parâmetro presente, executa normalmente
        let out = sandbox
            .run(&tool, &serde_json::json!({ "destino": "Maputo" }))
            .unwrap();
        assert_eq!(out["destino"].as_str(), Some("Maputo"));
    }

    #[test]
    fn tipo_errado_e_rejeitado() {
        let sandbox = sandbox_with(Arc::new(NoopHost), SandboxConfig::default());
        let tools = load_tools_from_dir(&examples_dir()).unwrap();
        let greet = tools
            .iter()
            .find(|t| t.manifest.id == "examples.greet")
            .unwrap();
        let err = sandbox
            .run(greet, &serde_json::json!({ "who": 123 }))
            .unwrap_err();
        assert!(matches!(err, CoreError::Validation { .. }));
        assert!(err.to_string().contains("string"));
    }

    #[test]
    fn resultado_nao_tabela_vira_json() {
        let sandbox = sandbox_with(Arc::new(NoopHost), SandboxConfig::default());
        let source = concat!(
            "--[==[ Geny Tool\n",
            "id: test.scalar\n",
            "name: Escalar\n",
            "description: devolve numero\n",
            "version: 0.1.0\n",
            "confirmation: none\n",
            "permissions: []\n",
            "params: []\n",
            "]==]--\n",
            "function geny_run(_p)\n",
            "  return 42\n",
            "end\n"
        );
        let tool = LuaTool::from_source(source).unwrap();
        let out = sandbox.run(&tool, &serde_json::json!({})).unwrap();
        assert_eq!(out.as_i64(), Some(42));
    }

    #[test]
    fn manifesto_ausente_ou_sem_terminador_falha() {
        assert!(LuaTool::from_source("return 1").is_err());
        let sem_terminador = "--[==[ Geny Tool\nid: x\nname: X\ndescription: d\nversion: 0.1.0\nconfirmation: none\npermissions: []\nparams: []\n";
        assert!(LuaTool::from_source(sem_terminador).is_err());
    }

    #[test]
    fn confirmation_desconhecido_falha() {
        let bad = concat!(
            "--[==[ Geny Tool\n",
            "id: x\nname: X\ndescription: d\nversion: 0.1.0\n",
            "confirmation: talvez\npermissions: []\nparams: []\n",
            "]==]--\n",
            "function geny_run(_p) return {} end\n"
        );
        let err = LuaTool::from_source(bad).unwrap_err();
        assert!(err.to_string().contains("confirmacao"));
    }

    #[test]
    fn definicao_da_ferramenta_e_mapeada_para_o_registro() {
        use crate::tools::registry::ToolContext;
        let tools = load_tools_from_dir(&examples_dir()).unwrap();
        let greet = tools
            .iter()
            .find(|t| t.manifest.id == "examples.greet")
            .unwrap();
        let def = greet.definition(ToolContext::App);
        assert_eq!(def.id, "examples.greet");
        assert_eq!(def.params.len(), 1);
        assert_eq!(def.params[0].name, "who");
        assert_eq!(def.confirmation, ConfirmationLevel::None);
    }
}
