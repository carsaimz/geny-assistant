//! Política de confirmação humana para ações sensíveis.
//!
//! Níveis (ver docs/TECHNICAL_SPEC.md §12.3):
//! 1. `None`           — ações inofensivas (consultar hora, listar apps).
//! 2. `Simple`         — ações reversíveis (criar nota, definir alarme).
//! 3. `Explicit`       — ações com impacto (enviar SMS, discar, apagar arquivo).
//! 4. `Authenticated`  — ações críticas (root, modificar sistema, transações).

use serde::{Deserialize, Serialize};

/// Nível de confirmação exigido por uma ferramenta.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ConfirmationLevel {
    None,
    Simple,
    Explicit,
    Authenticated,
}

impl ConfirmationLevel {
    /// Rótulo legível para UI e logs de auditoria (bilingue).
    pub fn label(&self) -> &'static str {
        match self {
            ConfirmationLevel::None => "nenhuma / none",
            ConfirmationLevel::Simple => "simples / simple",
            ConfirmationLevel::Explicit => "explicita / explicit",
            ConfirmationLevel::Authenticated => "autenticada / authenticated",
        }
    }
}

/// Pedido de confirmação enviado à camada de UI da plataforma.
#[derive(Debug, Clone, Serialize)]
pub struct ConfirmationRequest {
    /// Identificador da ferramenta que pede confirmação.
    pub tool_id: String,
    /// Nível de confirmação declarado pela ferramenta.
    pub level: ConfirmationLevel,
    /// Resumo legível da ação (ex.: "Enviar SMS para +258 84 000 0000").
    pub summary: String,
}

/// Decisão humana sobre um pedido de confirmação.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ConfirmationDecision {
    /// Aprovada. `remember` indica se o usuário autorizou sempre para a ferramenta.
    Approved { remember: bool },
    /// Negada pelo usuário ou pela política.
    Denied,
}

/// Porta de confirmação — implementada pela plataforma (diálogo Android, HUD etc.).
pub trait ConfirmationGate {
    fn decide(&self, request: &ConfirmationRequest) -> ConfirmationDecision;
}

/// Política automática para ambientes sem interação humana (testes, serviços
/// headless, CI). Aprova apenas `None` (e opcionalmente `Simple`); nega o resto.
///
/// Nunca deve ser usada na UI do usuário: lá a decisão é sempre humana.
#[derive(Debug, Clone, Default)]
pub struct AutoPolicy {
    /// Se `true`, permite também ações `Simple` (reversíveis).
    pub allow_simple: bool,
}

impl ConfirmationGate for AutoPolicy {
    fn decide(&self, request: &ConfirmationRequest) -> ConfirmationDecision {
        match request.level {
            ConfirmationLevel::None => ConfirmationDecision::Approved { remember: false },
            ConfirmationLevel::Simple if self.allow_simple => {
                ConfirmationDecision::Approved { remember: false }
            }
            _ => ConfirmationDecision::Denied,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn req(level: ConfirmationLevel) -> ConfirmationRequest {
        ConfirmationRequest {
            tool_id: "sms.send".into(),
            level,
            summary: "teste".into(),
        }
    }

    #[test]
    fn ordem_dos_niveis_e_crescente() {
        assert!(ConfirmationLevel::None < ConfirmationLevel::Simple);
        assert!(ConfirmationLevel::Simple < ConfirmationLevel::Explicit);
        assert!(ConfirmationLevel::Explicit < ConfirmationLevel::Authenticated);
    }

    #[test]
    fn auto_policy_aprova_apenas_none_por_padrao() {
        let policy = AutoPolicy::default();
        assert_eq!(
            policy.decide(&req(ConfirmationLevel::None)),
            ConfirmationDecision::Approved { remember: false }
        );
        assert_eq!(
            policy.decide(&req(ConfirmationLevel::Explicit)),
            ConfirmationDecision::Denied
        );
        assert_eq!(
            policy.decide(&req(ConfirmationLevel::Authenticated)),
            ConfirmationDecision::Denied
        );
    }

    #[test]
    fn auto_policy_com_allow_simple_aprova_simple() {
        let policy = AutoPolicy { allow_simple: true };
        assert_eq!(
            policy.decide(&req(ConfirmationLevel::Simple)),
            ConfirmationDecision::Approved { remember: false }
        );
    }

    #[test]
    fn serializacao_minuscula() {
        let json = serde_json::to_string(&ConfirmationLevel::Authenticated).unwrap();
        assert_eq!(json, "\"authenticated\"");
    }
}
