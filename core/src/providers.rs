//! Provedores remotos e perfis de operação (Fase 6, TODO core-10, docs §7.3/§7.6).
//!
//! **PT** O catálogo descreve serviços OpenAI-compatíveis (gratuitos,
//! free-tier, premium e servidores do próprio usuário) — a UI preenche a
//! base URL a partir dele e o Kotlin pode consultar a mesma fonte via UniFFI.
//! Os perfis de operação restringem o modo `auto` do app: "offline total"
//! nunca fala com a nuvem, "servidor de casa" só fala com o servidor do
//! usuário, "híbrido" equilibra (rede + bateria ficam no chamador, que tem
//! o contexto real do dispositivo).
//! **EN** The catalog describes OpenAI-compatible services (free, free-tier,
//! premium and the user's own servers) — the UI fills the base URL from it
//! and Kotlin reads the same source via UniFFI. Operation profiles constrain
//! the app's `auto` mode: "offline total" never talks to the cloud,
//! "home server" only talks to the user's server, "hybrid" balances
//! (network + battery stay with the caller, which owns real device context).

use serde::{Deserialize, Serialize};

/// Nível comercial do provedor (docs §7.3).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ProviderTier {
    /// Serviço 100% gratuito.
    Free,
    /// Camada gratuita com cotas (chave obrigatória).
    FreeTier,
    /// Pago / por token.
    Premium,
    /// Servidor do próprio usuário (Ollama, LM Studio, vLLM, llama.cpp).
    SelfHosted,
}

/// Especificação de um provedor compatível com a API OpenAI.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ProviderSpec {
    /// Identificador estável (usado no nome do segredo no Keystore).
    pub id: &'static str,
    /// Rótulo curto para a UI.
    pub label: &'static str,
    pub tier: ProviderTier,
    /// URL base padrão (termina em `/v1` quando o serviço usa o padrão OpenAI).
    pub base_url: &'static str,
    /// Provedores self-hosted locais dispensam chave.
    pub requires_key: bool,
}

/// Catálogo conhecido — a UI também oferece "custom" (fora desta lista).
pub const PROVIDERS: &[ProviderSpec] = &[
    ProviderSpec {
        id: "openrouter",
        label: "OpenRouter",
        tier: ProviderTier::FreeTier,
        base_url: "https://openrouter.ai/api/v1",
        requires_key: true,
    },
    ProviderSpec {
        id: "groq",
        label: "Groq",
        tier: ProviderTier::FreeTier,
        base_url: "https://api.groq.com/openai/v1",
        requires_key: true,
    },
    ProviderSpec {
        id: "cerebras",
        label: "Cerebras",
        tier: ProviderTier::FreeTier,
        base_url: "https://api.cerebras.ai/v1",
        requires_key: true,
    },
    ProviderSpec {
        id: "mistral",
        label: "Mistral AI",
        tier: ProviderTier::FreeTier,
        base_url: "https://api.mistral.ai/v1",
        requires_key: true,
    },
    ProviderSpec {
        id: "openai",
        label: "OpenAI",
        tier: ProviderTier::Premium,
        base_url: "https://api.openai.com/v1",
        requires_key: true,
    },
    ProviderSpec {
        id: "ollama",
        label: "Ollama",
        tier: ProviderTier::SelfHosted,
        base_url: "http://localhost:11434/v1",
        requires_key: false,
    },
    ProviderSpec {
        id: "lm-studio",
        label: "LM Studio",
        tier: ProviderTier::SelfHosted,
        base_url: "http://localhost:1234/v1",
        requires_key: false,
    },
    ProviderSpec {
        id: "vllm",
        label: "vLLM",
        tier: ProviderTier::SelfHosted,
        base_url: "http://localhost:8000/v1",
        requires_key: false,
    },
    ProviderSpec {
        id: "llama-cpp",
        label: "llama.cpp server",
        tier: ProviderTier::SelfHosted,
        base_url: "http://localhost:8080/v1",
        requires_key: false,
    },
];

/// Procura um provedor pelo id (ex.: `groq`).
pub fn provider_by_id(id: &str) -> Option<&'static ProviderSpec> {
    PROVIDERS.iter().find(|p| p.id == id)
}

/// Catálogo completo serializado (UniFFI → Kotlin, depuração e UI).
pub fn providers_catalog_json() -> String {
    serde_json::to_string(PROVIDERS).unwrap_or_else(|_| "[]".to_string())
}

/// Perfil de operação (docs §7.6): restringe o que o modo `auto` pode usar.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum OperationProfile {
    /// Nunca fala com a rede: só modelo local e roteador offline.
    OfflineTotal,
    /// Nuvem quando há rede/bateria; local no resto (comportamento do `auto`).
    Hybrid,
    /// Só o servidor do próprio usuário; nenhuma nuvem de terceiros.
    HomeServer,
}

impl OperationProfile {
    /// Código canônico (o mesmo usado na UI e nas configurações).
    pub fn code(&self) -> &'static str {
        match self {
            OperationProfile::OfflineTotal => "offline-total",
            OperationProfile::Hybrid => "hybrid",
            OperationProfile::HomeServer => "home-server",
        }
    }

    /// Resolve um código (aceita também os aliases legados `offline`/`homeserver`).
    pub fn from_code(code: &str) -> Option<Self> {
        match code.trim().to_lowercase().as_str() {
            "offline-total" | "offline" => Some(OperationProfile::OfflineTotal),
            "hybrid" => Some(OperationProfile::Hybrid),
            "home-server" | "homeserver" => Some(OperationProfile::HomeServer),
            _ => None,
        }
    }

    /// Todos os perfis, na ordem da UI.
    pub fn all() -> &'static [OperationProfile] {
        &[
            OperationProfile::OfflineTotal,
            OperationProfile::Hybrid,
            OperationProfile::HomeServer,
        ]
    }
}

/// Sugestão de modo para o turno — MESMA nomenclatura do app
/// (`remote` | `local` | `offline`; o transporte remoto é único).
///
/// Regras por perfil:
/// - `offline-total`: `local` quando há modelo; senão `offline`.
/// - `home-server`: servidor próprio pronto → `remote`; senão local/offline.
///   Nuvem premium NUNCA é usada.
/// - `hybrid`: online + qualquer remoto pronto → `remote`; senão local/offline.
///
/// Bateria/economia/thermal ficam no chamador (contexto real do dispositivo),
/// como no `pickBackend` do app — este contrato é a regra de NEGÓCIO do perfil.
pub fn suggest_mode(
    profile: OperationProfile,
    local_ready: bool,
    premium_ready: bool,
    selfhosted_ready: bool,
    online: bool,
) -> &'static str {
    match profile {
        OperationProfile::OfflineTotal => {
            if local_ready {
                "local"
            } else {
                "offline"
            }
        }
        OperationProfile::HomeServer => {
            if selfhosted_ready {
                "remote"
            } else if local_ready {
                "local"
            } else {
                "offline"
            }
        }
        OperationProfile::Hybrid => {
            if online && (premium_ready || selfhosted_ready) {
                "remote"
            } else if local_ready {
                "local"
            } else {
                "offline"
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn catalogo_tem_provedores_conhecidos() {
        assert!(provider_by_id("openrouter").is_some());
        assert!(provider_by_id("groq").is_some());
        assert!(provider_by_id("ollama").is_some());
        assert!(provider_by_id("inexistente").is_none());
        // self-hosted local dispensa chave; free-tier exige.
        assert!(provider_by_id("ollama")
            .unwrap()
            .base_url
            .starts_with("http://localhost"));
        assert!(!provider_by_id("ollama").unwrap().requires_key);
        assert!(provider_by_id("groq").unwrap().requires_key);
    }

    #[test]
    fn catalogo_json_serializa() {
        let json = providers_catalog_json();
        assert!(json.contains("openrouter"));
        assert!(json.contains("free-tier"));
        assert!(json.contains("self-hosted"));
        let parsed: Vec<serde_json::Value> = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.len(), PROVIDERS.len());
        // cada entrada carrega os campos da UI
        for entry in &parsed {
            assert!(entry.get("id").and_then(|v| v.as_str()).is_some());
            assert!(entry.get("base_url").and_then(|v| v.as_str()).is_some());
            assert!(entry
                .get("requires_key")
                .and_then(|v| v.as_bool())
                .is_some());
        }
    }

    #[test]
    fn codigos_de_perfil_roundtrip() {
        for p in OperationProfile::all() {
            assert_eq!(OperationProfile::from_code(p.code()), Some(*p));
        }
        assert!(OperationProfile::from_code("quebrado").is_none());
        // aliases legados
        assert_eq!(
            OperationProfile::from_code("offline"),
            Some(OperationProfile::OfflineTotal)
        );
        assert_eq!(
            OperationProfile::from_code("Homeserver"),
            Some(OperationProfile::HomeServer)
        );
    }

    #[test]
    fn offline_total_nunca_usa_rede() {
        // mesmo com tudo pronto e online: local ou offline.
        assert_eq!(
            suggest_mode(OperationProfile::OfflineTotal, true, true, true, true),
            "local"
        );
        assert_eq!(
            suggest_mode(OperationProfile::OfflineTotal, false, true, true, true),
            "offline"
        );
    }

    #[test]
    fn servidor_de_casa_ignora_nuvem_premium() {
        // só o servidor próprio conta; premium pronto não basta.
        assert_eq!(
            suggest_mode(OperationProfile::HomeServer, true, true, false, true),
            "local"
        );
        assert_eq!(
            suggest_mode(OperationProfile::HomeServer, false, true, false, true),
            "offline"
        );
        assert_eq!(
            suggest_mode(OperationProfile::HomeServer, false, false, true, true),
            "remote"
        );
    }

    #[test]
    fn hibrido_espelha_o_auto_classico() {
        assert_eq!(
            suggest_mode(OperationProfile::Hybrid, true, true, false, true),
            "remote"
        );
        assert_eq!(
            suggest_mode(OperationProfile::Hybrid, true, true, false, false),
            "local"
        );
        assert_eq!(
            suggest_mode(OperationProfile::Hybrid, false, false, false, true),
            "offline"
        );
    }
}
