//! Backends de IA: local, remoto (API) e self-hosted (§7).
//!
//! O núcleo define apenas o contrato ([`LlmBackend`]); as implementações concretas
//! vivem na plataforma: llama.cpp/NDK (local), OkHttp/OpenAI-compat (remoto e
//! self-hosted). A seleção dinâmica usa heurística simples na Fase 1 e evolui
//! na Fase 6.

use serde::{Deserialize, Serialize};

use crate::error::Result;

/// Modo de operação do backend (§7.1).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum BackendMode {
    /// Inferência on-device (GGUF via llama.cpp).
    Local,
    /// API remota de terceiro (chave própria do usuário).
    Remote,
    /// Servidor do próprio usuário compatível com a API OpenAI.
    SelfHosted,
}

/// Pedido de conclusão enviado ao backend.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompletionRequest {
    pub system: String,
    /// Mensagens da janela de contexto no formato `{role, content}`.
    pub messages: Vec<serde_json::Value>,
    pub temperature: f32,
    pub max_tokens: u32,
}

/// Saída do modelo: texto puro ou pedido de chamada de ferramenta.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum CompletionOutput {
    Text {
        text: String,
    },
    ToolCall {
        tool_id: String,
        params: serde_json::Value,
    },
}

/// Resposta de conclusão.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CompletionResponse {
    pub output: CompletionOutput,
    /// Identificador do modelo que respondeu (ex.: `qwen2.5-1.5b-instruct-q4`).
    pub model: String,
}

/// Contrato comum de todos os backends de IA.
pub trait LlmBackend: Send + Sync {
    /// Identificador estável do backend.
    fn id(&self) -> &str;
    /// Modo de operação.
    fn mode(&self) -> BackendMode;
    /// Executa uma conclusão.
    fn complete(&self, request: &CompletionRequest) -> Result<CompletionResponse>;
}

/// Contexto do dispositivo usado na seleção dinâmica (§7.6).
#[derive(Debug, Clone, Copy)]
pub struct DeviceContext {
    /// Há conectividade de rede?
    pub online: bool,
    /// Nível de bateria em porcentagem (0–100).
    pub battery_pct: u8,
    /// Modo economia de energia ativo?
    pub battery_saver: bool,
    /// Temperatura do dispositivo elevada?
    pub thermal_high: bool,
}

impl Default for DeviceContext {
    fn default() -> Self {
        DeviceContext {
            online: true,
            battery_pct: 80,
            battery_saver: false,
            thermal_high: false,
        }
    }
}

/// Seleção dinâmica de backend (v0 — heurística simples, Fase 6 refina).
///
/// Regras:
/// - Offline: só backends `Local` servem.
/// - Economia de bateria ou thermal alto: prefere `Local`.
/// - Tarefa complexa + online + bateria saudável: prefere `Remote`/`SelfHosted`.
/// - Caso contrário: primeiro backend disponível na ordem fornecida.
pub fn select_backend<'a>(
    backends: &'a [&'a dyn LlmBackend],
    ctx: &DeviceContext,
    complex_task: bool,
) -> Option<&'a dyn LlmBackend> {
    let matches = |b: &dyn LlmBackend, mode: BackendMode| b.mode() == mode;

    if !ctx.online {
        return backends
            .iter()
            .copied()
            .find(|b| matches(*b, BackendMode::Local));
    }
    if ctx.battery_saver || ctx.thermal_high {
        return backends
            .iter()
            .copied()
            .find(|b| matches(*b, BackendMode::Local))
            .or_else(|| backends.first().copied());
    }
    if complex_task && ctx.battery_pct > 30 {
        if let Some(b) = backends
            .iter()
            .copied()
            .find(|b| matches(*b, BackendMode::Remote) || matches(*b, BackendMode::SelfHosted))
        {
            return Some(b);
        }
    }
    backends.first().copied()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    struct MockBackend {
        id: String,
        mode: BackendMode,
        calls: Mutex<Vec<String>>,
        response: CompletionResponse,
    }

    impl LlmBackend for MockBackend {
        fn id(&self) -> &str {
            &self.id
        }
        fn mode(&self) -> BackendMode {
            self.mode
        }
        fn complete(&self, _request: &CompletionRequest) -> Result<CompletionResponse> {
            self.calls.lock().unwrap().push("complete".into());
            Ok(self.response.clone())
        }
    }

    fn mk(id: &str, mode: BackendMode) -> MockBackend {
        MockBackend {
            id: id.to_string(),
            mode,
            calls: Mutex::new(Vec::new()),
            response: CompletionResponse {
                output: CompletionOutput::Text { text: "ok".into() },
                model: "mock".into(),
            },
        }
    }

    #[test]
    fn offline_forca_backend_local() {
        let local = mk("local", BackendMode::Local);
        let remote = mk("remote", BackendMode::Remote);
        let backends: Vec<&dyn LlmBackend> = vec![&remote, &local];
        let ctx = DeviceContext {
            online: false,
            ..Default::default()
        };
        assert_eq!(select_backend(&backends, &ctx, true).unwrap().id(), "local");
    }

    #[test]
    fn economia_de_bateria_prefere_local() {
        let local = mk("local", BackendMode::Local);
        let remote = mk("remote", BackendMode::Remote);
        let backends: Vec<&dyn LlmBackend> = vec![&remote, &local];
        let ctx = DeviceContext {
            battery_saver: true,
            ..Default::default()
        };
        assert_eq!(
            select_backend(&backends, &ctx, false).unwrap().id(),
            "local"
        );
    }

    #[test]
    fn tarefa_complexa_online_prefere_remoto() {
        let local = mk("local", BackendMode::Local);
        let remote = mk("remote", BackendMode::Remote);
        let backends: Vec<&dyn LlmBackend> = vec![&local, &remote];
        let ctx = DeviceContext {
            battery_pct: 90,
            ..Default::default()
        };
        assert_eq!(
            select_backend(&backends, &ctx, true).unwrap().id(),
            "remote"
        );
    }

    #[test]
    fn saida_ferramenta_serializa_corretamente() {
        let resp = CompletionResponse {
            output: CompletionOutput::ToolCall {
                tool_id: "apps.open".into(),
                params: serde_json::json!({"app": "camera"}),
            },
            model: "local".into(),
        };
        let json = serde_json::to_string(&resp.output).unwrap();
        assert!(json.contains("\"tool_call\""));
        assert!(json.contains("apps.open"));
    }
}
