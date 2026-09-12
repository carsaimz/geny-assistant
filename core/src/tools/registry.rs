//! Registro de ferramentas: catálogo explícito e controlado (§2.5, §12).
//!
//! O modelo escolhe entre as ferramentas registradas — nunca inventa comandos.

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

use crate::confirmation::ConfirmationLevel;
use crate::error::{CoreError, Result};

/// Tipos de parâmetro suportados pelo validador leve (v0 sem JSON Schema completo).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ParamType {
    String,
    Number,
    Integer,
    Boolean,
    Array,
    Object,
}

/// Especificação de um parâmetro de ferramenta.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParamSpec {
    pub name: String,
    pub r#type: ParamType,
    #[serde(default)]
    pub required: bool,
    #[serde(default)]
    pub description: String,
    /// Valores permitidos (equivalente a `enum`).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub allowed_values: Option<Vec<String>>,
}

/// Contexto de execução declarado pela ferramenta.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ToolContext {
    /// Executa dentro do app, em primeiro plano.
    App,
    /// Executa a partir do serviço em primeiro plano (fundo).
    Service,
    /// Exige privilégios de superusuário (root) — sempre confirmado.
    Root,
}

/// Definição completa de uma ferramenta (§12.2).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolDefinition {
    /// Identificador único, formato `dominio.acao` (ex.: `apps.open`).
    pub id: String,
    /// Nome legível.
    pub name: String,
    /// Descrição em linguagem natural, usada pelo modelo.
    pub description: String,
    /// Esquema de parâmetros.
    pub params: Vec<ParamSpec>,
    /// Permissões Android necessárias (ex.: `android.permission.SEND_SMS`).
    #[serde(default)]
    pub permissions: Vec<String>,
    /// Nível de confirmação humana exigido.
    pub confirmation: ConfirmationLevel,
    /// Contexto de execução.
    pub context: ToolContext,
    /// Tempo limite de execução em milissegundos.
    #[serde(default = "default_timeout_ms")]
    pub timeout_ms: u64,
}

fn default_timeout_ms() -> u64 {
    10_000
}

impl ToolDefinition {
    /// Atalho para criar uma definição simples sem parâmetros.
    pub fn simple(
        id: &str,
        name: &str,
        description: &str,
        confirmation: ConfirmationLevel,
        context: ToolContext,
    ) -> Self {
        ToolDefinition {
            id: id.to_string(),
            name: name.to_string(),
            description: description.to_string(),
            params: Vec::new(),
            permissions: Vec::new(),
            confirmation,
            context,
            timeout_ms: default_timeout_ms(),
        }
    }
}

/// Registro central de ferramentas disponíveis no dispositivo.
#[derive(Debug, Clone, Default)]
pub struct ToolRegistry {
    tools: BTreeMap<String, ToolDefinition>,
}

impl ToolRegistry {
    pub fn new() -> Self {
        Self::default()
    }

    /// Registra uma ferramenta. Falha se o id for vazio ou duplicado.
    pub fn register(&mut self, def: ToolDefinition) -> Result<()> {
        if def.id.trim().is_empty() {
            return Err(CoreError::Internal("id de ferramenta vazio".into()));
        }
        if self.tools.contains_key(&def.id) {
            return Err(CoreError::Internal(format!(
                "ferramenta duplicada: {}",
                def.id
            )));
        }
        self.tools.insert(def.id.clone(), def);
        Ok(())
    }

    /// Registra várias ferramentas de uma vez.
    pub fn register_all(&mut self, defs: impl IntoIterator<Item = ToolDefinition>) -> Result<()> {
        for d in defs {
            self.register(d)?;
        }
        Ok(())
    }

    /// Consulta uma ferramenta pelo id.
    pub fn get(&self, id: &str) -> Option<&ToolDefinition> {
        self.tools.get(id)
    }

    /// Consulta obrigatória — erro [`CoreError::ToolNotFound`] se ausente.
    pub fn require(&self, id: &str) -> Result<&ToolDefinition> {
        self.tools
            .get(id)
            .ok_or_else(|| CoreError::ToolNotFound(id.to_string()))
    }

    /// Catálogo ordenado por id (a ordem é estável para prompts).
    pub fn list(&self) -> Vec<&ToolDefinition> {
        self.tools.values().collect()
    }

    /// Quantidade de ferramentas registradas.
    pub fn len(&self) -> usize {
        self.tools.len()
    }

    pub fn is_empty(&self) -> bool {
        self.tools.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn def(id: &str) -> ToolDefinition {
        ToolDefinition::simple(
            id,
            "Teste",
            "ferramenta de teste",
            ConfirmationLevel::None,
            ToolContext::App,
        )
    }

    #[test]
    fn registra_e_consulta() {
        let mut r = ToolRegistry::new();
        r.register(def("time.now")).unwrap();
        r.register(def("apps.list")).unwrap();
        assert_eq!(r.len(), 2);
        assert!(r.get("time.now").is_some());
        assert!(r.require("apps.list").is_ok());
    }

    #[test]
    fn rejeita_duplicado_e_vazio() {
        let mut r = ToolRegistry::new();
        r.register(def("a.b")).unwrap();
        assert!(r.register(def("a.b")).is_err());
        assert!(r.register(def("")).is_err());
    }

    #[test]
    fn ferramenta_inexistente_da_erro_especifico() {
        let r = ToolRegistry::new();
        let err = r.require("nao.existe").unwrap_err();
        assert!(matches!(err, CoreError::ToolNotFound(x) if x == "nao.existe"));
    }

    #[test]
    fn catalogo_ordenado_por_id() {
        let mut r = ToolRegistry::new();
        r.register_all([def("z.y"), def("a.b"), def("m.n")])
            .unwrap();
        let ids: Vec<String> = r.list().iter().map(|d| d.id.clone()).collect();
        assert_eq!(ids, vec!["a.b", "m.n", "z.y"]);
    }
}
