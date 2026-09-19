//! Geny Assistant — núcleo de orquestração (Rust).
//!
//! Este crate implementa o núcleo lógico do assistente de forma independente de
//! plataforma: sessão e contexto, registro e validação de ferramentas (tool
//! calling), política de confirmação humana, memória de curto/longo prazo,
//! suporte multilíngue e seleção dinâmica de backends de IA.
//!
//! A camada Android (Kotlin) e a camada web (TypeScript) consomem este núcleo
//! via FFI (UniFFI) e via ponte Capacitor, respectivamente.

pub mod backend;
pub mod confirmation;
pub mod error;
pub mod i18n;
pub mod memory;
pub mod orchestrator;
pub mod providers;
pub mod retention;
pub mod session;
pub mod tools;

#[cfg(feature = "lua")]
pub mod lua_sandbox;

#[cfg(feature = "semantic")]
pub mod embed;
#[cfg(feature = "semantic")]
pub mod semantic;

#[cfg(feature = "uniffi")]
pub mod uniffi_api;

#[cfg(feature = "vad")]
pub mod vad;

pub use error::{CoreError, Result};
pub use orchestrator::{Orchestrator, Outcome, ToolExecutor, ToolOutcome};
pub use retention::RetentionPolicy;

#[cfg(feature = "semantic")]
pub use embed::{cosine, Embedder, HashingEmbedder, EMBED_DIM};
#[cfg(feature = "semantic")]
pub use semantic::{SemanticHit, SemanticIndex};

#[cfg(feature = "vad")]
pub use vad::{EnergyVad, SegmentBuffer, VadConfig, VadDecision};

/// Versão do núcleo, sincronizada com o `Cargo.toml`.
pub const CORE_VERSION: &str = env!("CARGO_PKG_VERSION");

/// Identificador do produto, usado em prompts e logs locais.
pub const PRODUCT_NAME: &str = "Geny Assistant";

// Scaffolding UniFFI (TODO core-04): gera os exports FFI para o bindgen.
#[cfg(feature = "uniffi")]
uniffi::setup_scaffolding!("geny_core");

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn versao_semver_valida() {
        let parts: Vec<&str> = CORE_VERSION.split('.').collect();
        assert!(parts.len() >= 2, "versão deve ser ao menos MAJOR.MINOR");
        assert!(parts[0].chars().all(|c| c.is_ascii_digit()));
    }
}
