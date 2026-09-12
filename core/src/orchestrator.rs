//! Orquestrador: o núcleo lógico do assistente (§3.2).
//!
//! Pipeline: entrada do usuário → backend de IA → saída de texto OU pedido de
//! chamada de ferramenta → validação de esquema → confirmação humana → execução
//! → (seguimento opcional com o resultado da ferramenta).

use serde::Serialize;
use serde_json::{json, Value};

use crate::backend::{CompletionOutput, CompletionRequest, LlmBackend};
use crate::confirmation::{ConfirmationDecision, ConfirmationGate, ConfirmationRequest};
use crate::error::Result;
use crate::i18n::{self, Language};
use crate::session::{Message, Session};
use crate::tools::validator::validate_params;
use crate::tools::ToolRegistry;

/// Executor de ferramentas — implementado pela plataforma (Kotlin nativo,
/// sandbox Lua, root, integrações externas).
pub trait ToolExecutor {
    /// Executa a ferramenta e devolve o resultado como JSON.
    fn execute(&self, tool_id: &str, params: &Value) -> Result<Value>;
}

/// Resultado da execução de uma ferramenta.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum ToolOutcome {
    Ok { tool_id: String, data: Value },
    Denied { tool_id: String, reason: String },
    Failed { tool_id: String, error: String },
}

impl ToolOutcome {
    /// Identificador da ferramenta (qualquer variante).
    pub fn tool_id(&self) -> &str {
        match self {
            ToolOutcome::Ok { tool_id, .. }
            | ToolOutcome::Denied { tool_id, .. }
            | ToolOutcome::Failed { tool_id, .. } => tool_id,
        }
    }
}

/// Resultado de um ciclo completo de orquestração.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Outcome {
    /// Resposta textual direta do modelo.
    Text { text: String },
    /// Uma ferramenta foi selecionada e processada.
    Tool {
        result: ToolOutcome,
        /// Frase final do modelo após ver o resultado da ferramenta (opcional).
        followup: Option<String>,
    },
    /// Erro tratado (backend indisponível etc.).
    Error { message: String },
}

/// Orquestrador principal. Mantém a sessão e coordena backend + ferramentas.
pub struct Orchestrator {
    pub session: Session,
    pub language: Language,
    registry: ToolRegistry,
    backend: Box<dyn LlmBackend>,
    gate: Box<dyn ConfirmationGate>,
    executor: Box<dyn ToolExecutor>,
    /// Se `true`, após executar a ferramenta o modelo recebe o resultado para
    /// produzir uma frase final natural (segunda passagem).
    pub allow_tool_followup: bool,
}

impl Orchestrator {
    /// Constrói um orquestrador com as dependências injetadas.
    pub fn new(
        session_id: &str,
        language: Language,
        registry: ToolRegistry,
        backend: Box<dyn LlmBackend>,
        gate: Box<dyn ConfirmationGate>,
        executor: Box<dyn ToolExecutor>,
    ) -> Self {
        Orchestrator {
            session: Session::new(session_id),
            language,
            registry,
            backend,
            gate,
            executor,
            allow_tool_followup: true,
        }
    }

    /// Catálogo de ferramentas registradas (somente leitura).
    pub fn registry(&self) -> &ToolRegistry {
        &self.registry
    }

    /// Catálogo serializado para injeção no prompt de sistema.
    pub fn catalog_json(&self) -> String {
        serde_json::to_string(&self.registry.list()).unwrap_or_else(|_| "[]".to_string())
    }

    /// Processa uma entrada do usuário e devolve o resultado do ciclo.
    pub fn handle_input(&mut self, text: &str) -> Outcome {
        self.handle_input_result(text)
            .unwrap_or_else(|e| Outcome::Error {
                message: e.to_string(),
            })
    }

    fn handle_input_result(&mut self, text: &str) -> Result<Outcome> {
        self.session.push_user(text.to_string());

        let system = i18n::system_prompt(self.language, &self.catalog_json(), true);
        let messages: Vec<Value> = self
            .session
            .context_window()
            .iter()
            .map(|m| json!({"role": m.role, "content": m.content}))
            .collect();

        let response = self.backend.complete(&CompletionRequest {
            system,
            messages,
            temperature: 0.7,
            max_tokens: 1024,
        })?;

        match response.output {
            CompletionOutput::Text { text } => {
                self.session.push_assistant(text.clone());
                Ok(Outcome::Text { text })
            }
            CompletionOutput::ToolCall { tool_id, params } => {
                let outcome = self.run_tool(&tool_id, &params)?;
                let mut followup = None;

                if self.allow_tool_followup && matches!(outcome, ToolOutcome::Ok { .. }) {
                    let tool_msg = Message::tool_call(
                        format!("call-{}", outcome.tool_id()),
                        outcome_json(&outcome),
                    );
                    self.session.push(tool_msg);
                    if let Ok(second) = self.backend.complete(&CompletionRequest {
                        system: i18n::system_prompt(self.language, &self.catalog_json(), true),
                        messages: self
                            .session
                            .context_window()
                            .iter()
                            .map(|m| json!({"role": m.role, "content": m.content}))
                            .collect(),
                        temperature: 0.7,
                        max_tokens: 1024,
                    }) {
                        if let CompletionOutput::Text { text } = second.output {
                            followup = Some(text.clone());
                            self.session.push_assistant(text);
                        }
                    }
                } else {
                    self.session.push_assistant(format!(
                        "[ferramenta {} -> {}]",
                        outcome.tool_id(),
                        outcome_status(&outcome)
                    ));
                }

                Ok(Outcome::Tool {
                    result: outcome,
                    followup,
                })
            }
        }
    }

    /// Valida, confirma e executa uma ferramenta. Nunca propaga erro de
    /// execução — converte em [`ToolOutcome::Failed`] para o modelo/UI decidirem.
    fn run_tool(&mut self, tool_id: &str, params: &Value) -> Result<ToolOutcome> {
        let def = match self.registry.require(tool_id) {
            Ok(d) => d.clone(),
            Err(_) => {
                return Ok(ToolOutcome::Failed {
                    tool_id: tool_id.to_string(),
                    error: format!("ferramenta nao registrada: {tool_id}"),
                })
            }
        };

        if let Err(e) = validate_params(&def, params) {
            return Ok(ToolOutcome::Failed {
                tool_id: tool_id.to_string(),
                error: e.to_string(),
            });
        }

        let decision = self.gate.decide(&ConfirmationRequest {
            tool_id: tool_id.to_string(),
            level: def.confirmation,
            summary: format!("{} ({})", def.name, tool_id),
        });

        match decision {
            ConfirmationDecision::Denied => Ok(ToolOutcome::Denied {
                tool_id: tool_id.to_string(),
                reason: "confirmacao negada pelo usuario ou pela politica".into(),
            }),
            ConfirmationDecision::Approved { .. } => match self.executor.execute(tool_id, params) {
                Ok(data) => Ok(ToolOutcome::Ok {
                    tool_id: tool_id.to_string(),
                    data,
                }),
                Err(e) => Ok(ToolOutcome::Failed {
                    tool_id: tool_id.to_string(),
                    error: e.to_string(),
                }),
            },
        }
    }
}

fn outcome_json(outcome: &ToolOutcome) -> String {
    serde_json::to_string(outcome).unwrap_or_else(|_| "{}".to_string())
}

fn outcome_status(outcome: &ToolOutcome) -> &'static str {
    match outcome {
        ToolOutcome::Ok { .. } => "ok",
        ToolOutcome::Denied { .. } => "negada",
        ToolOutcome::Failed { .. } => "falhou",
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::backend::{BackendMode, CompletionResponse};
    use crate::confirmation::AutoPolicy;
    use crate::error::CoreError;
    use crate::tools::catalog::builtin_catalog;
    use std::sync::Mutex;

    // ---------- Mocks ----------

    struct ScriptedBackend {
        steps: Mutex<Vec<CompletionOutput>>,
    }

    impl ScriptedBackend {
        fn new(steps: Vec<CompletionOutput>) -> Self {
            ScriptedBackend {
                steps: Mutex::new(steps),
            }
        }
    }

    impl LlmBackend for ScriptedBackend {
        fn id(&self) -> &str {
            "mock"
        }
        fn mode(&self) -> BackendMode {
            BackendMode::Local
        }
        fn complete(&self, _request: &CompletionRequest) -> Result<CompletionResponse> {
            let mut steps = self.steps.lock().unwrap();
            if steps.is_empty() {
                return Ok(CompletionResponse {
                    output: CompletionOutput::Text { text: "fim".into() },
                    model: "mock".into(),
                });
            }
            Ok(CompletionResponse {
                output: steps.remove(0),
                model: "mock".into(),
            })
        }
    }

    struct MapExecutor;

    impl ToolExecutor for MapExecutor {
        fn execute(&self, tool_id: &str, params: &Value) -> Result<Value> {
            match tool_id {
                "time.now" => Ok(json!({"iso": "2025-12-25T08:00:00", "tz": "Africa/Maputo"})),
                "apps.open" => Ok(json!({"opened": params["app"]})),
                "notes.create" => Ok(json!({"created": true})),
                _ => Err(CoreError::Execution(format!(
                    "sem implementacao: {tool_id}"
                ))),
            }
        }
    }

    fn registry() -> ToolRegistry {
        let mut r = ToolRegistry::new();
        r.register_all(builtin_catalog()).unwrap();
        r
    }

    fn orch(steps: Vec<CompletionOutput>) -> Orchestrator {
        Orchestrator::new(
            "test-session",
            Language::PtBr,
            registry(),
            Box::new(ScriptedBackend::new(steps)),
            Box::new(AutoPolicy::default()),
            Box::new(MapExecutor),
        )
    }

    // ---------- Testes ----------

    #[test]
    fn fluxo_de_texto_puro() {
        let mut o = orch(vec![CompletionOutput::Text {
            text: "ola! em que posso ajudar?".into(),
        }]);
        let out = o.handle_input("oi");
        match out {
            Outcome::Text { text } => assert!(text.contains("ola")),
            other => panic!("esperava texto, veio {other:?}"),
        }
        assert_eq!(o.session.len(), 2);
    }

    #[test]
    fn chamada_de_ferramenta_ok_com_followup() {
        let mut o = orch(vec![
            CompletionOutput::ToolCall {
                tool_id: "time.now".into(),
                params: serde_json::Value::Null,
            },
            CompletionOutput::Text {
                text: "agora sao 08:00".into(),
            },
        ]);
        let out = o.handle_input("que horas sao?");
        match out {
            Outcome::Tool { result, followup } => {
                assert!(
                    matches!(result, ToolOutcome::Ok { ref tool_id, .. } if tool_id == "time.now")
                );
                assert_eq!(followup.as_deref(), Some("agora sao 08:00"));
            }
            other => panic!("esperava ferramenta, veio {other:?}"),
        }
    }

    #[test]
    fn acao_sensivel_sem_root_e_negada_sem_confirmacao_humana() {
        // sms.send exige confirmacao Explicita; AutoPolicy nega em testes.
        let mut o = orch(vec![CompletionOutput::ToolCall {
            tool_id: "sms.send".into(),
            params: json!({"to": "+258840000000", "body": "teste"}),
        }]);
        let out = o.handle_input("manda um sms");
        match out {
            Outcome::Tool { result, .. } => {
                assert!(
                    matches!(result, ToolOutcome::Denied { ref tool_id, .. } if tool_id == "sms.send")
                );
            }
            other => panic!("esperava ferramenta negada, veio {other:?}"),
        }
    }

    #[test]
    fn parametros_invalidos_falham_sem_executar() {
        let mut o = orch(vec![CompletionOutput::ToolCall {
            tool_id: "apps.open".into(),
            params: json!({"app_errado": "camera"}),
        }]);
        let out = o.handle_input("abre a camera");
        match out {
            Outcome::Tool { result, .. } => {
                assert!(matches!(result, ToolOutcome::Failed { .. }));
            }
            other => panic!("esperava falha, veio {other:?}"),
        }
    }

    #[test]
    fn ferramenta_desconhecida_falha_sem_panico() {
        let mut o = orch(vec![CompletionOutput::ToolCall {
            tool_id: "root.format.disk".into(),
            params: serde_json::Value::Null,
        }]);
        let out = o.handle_input("formata o disco");
        match out {
            Outcome::Tool { result, .. } => {
                assert!(
                    matches!(result, ToolOutcome::Failed { ref error, .. } if error.contains("nao registrada"))
                );
            }
            other => panic!("esperava falha, veio {other:?}"),
        }
    }

    #[test]
    fn erro_de_backend_vira_outcome_de_erro() {
        struct BrokenBackend;
        impl LlmBackend for BrokenBackend {
            fn id(&self) -> &str {
                "broken"
            }
            fn mode(&self) -> BackendMode {
                BackendMode::Local
            }
            fn complete(&self, _r: &CompletionRequest) -> Result<CompletionResponse> {
                Err(CoreError::Backend("modelo nao carregado".into()))
            }
        }
        let mut o = Orchestrator::new(
            "s",
            Language::En,
            registry(),
            Box::new(BrokenBackend),
            Box::new(AutoPolicy::default()),
            Box::new(MapExecutor),
        );
        let out = o.handle_input("oi");
        assert!(matches!(out, Outcome::Error { .. }));
    }
}
