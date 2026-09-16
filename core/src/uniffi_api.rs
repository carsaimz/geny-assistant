//! Superfície UniFFI (TODO core-04): bindings geny-core ↔ Kotlin.
//!
//! **PT** A camada Android (Kotlin) consome o núcleo real via `libgeny_core.so`
//! em vez de espelhar a lógica em outra linguagem. A superfície exposta aqui
//! é deliberadamente pequena e estável: versão, resolução de idioma e o
//! prompt de sistema por idioma/cultura — a MESMA lógica que a web usa via
//! `system-prompt.ts` (espelho TS) e que o Rust usa nativamente.
//! **EN** The Android layer consumes the real core through `libgeny_core.so`
//! instead of mirroring logic in another language. The surface here is
//! deliberately small and stable: version, language resolution and the
//! language/culture-aware system prompt — the SAME logic the web uses via
//! `system-prompt.ts` and Rust uses natively.

use crate::i18n::Language;

/// Versão do núcleo (sincronizada com o `Cargo.toml`), para diagnóstico.
///
/// Exposed as `geny_core.lib.uniffi.coreVersion()` no Kotlin gerado.
#[uniffi::export]
pub fn core_version() -> String {
    crate::CORE_VERSION.to_string()
}

/// Resolve um código de idioma (BCP-47, ex.: `pt-BR`, `zh_CN`, `xyz`) no
/// código canônico do núcleo (`pt-BR`, `zh-CN`, `en`…).
#[uniffi::export]
pub fn resolve_language(code: String) -> String {
    Language::from_code(&code).code().to_string()
}

/// Indica se o idioma resolvedo é escrito da direita para a esquerda.
#[uniffi::export]
pub fn is_rtl(code: String) -> bool {
    Language::from_code(&code).is_rtl()
}

/// Constrói o prompt de sistema por idioma/cultura — ponte direta para
/// [`crate::i18n::system_prompt`]. `tool_catalog_json` é o catálogo das
/// ferramentas registradas; `privacy_statement` embute a regra local-first.
#[uniffi::export]
pub fn build_system_prompt(
    language_code: String,
    tool_catalog_json: String,
    privacy_statement: bool,
) -> String {
    crate::i18n::system_prompt(
        Language::from_code(&language_code),
        &tool_catalog_json,
        privacy_statement,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn versao_e_semver() {
        assert!(core_version().contains('.'));
    }

    #[test]
    fn resolucao_canonica() {
        assert_eq!(resolve_language("pt".into()), "pt-BR");
        assert_eq!(resolve_language("zh_CN".into()), "zh-CN");
        assert_eq!(resolve_language("xyz".into()), "en");
        assert!(!is_rtl("en".into()));
        assert!(is_rtl("ar".into()));
    }

    #[test]
    fn prompt_espelha_i18n() {
        let p = build_system_prompt("pt-BR".into(), "[{\"id\":\"time.now\"}]".into(), true);
        assert!(p.contains("Geny Assistant"));
        assert!(p.contains("pt-BR"));
        assert!(p.contains("time.now"));
        assert!(p.contains("Privacidade"));
        let sem_privacidade = build_system_prompt("en".into(), "[]".into(), false);
        assert!(!sem_privacidade.contains("Privacidade"));
    }
}
