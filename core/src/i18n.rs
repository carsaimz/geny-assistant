//! Suporte multilíngue por design (docs/TECHNICAL_SPEC.md §8).
//!
//! O prompt de sistema é construído por idioma e cultura, e o catálogo de
//! ferramentas é injetado como JSON para que o modelo só selecione entre as
//! ferramentas registradas — nunca invente comandos.

use serde::{Deserialize, Serialize};

/// Idiomas principais obrigatórios (§8.1) com fallback desconhecido.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Language {
    PtBr,
    PtPt,
    En,
    Es,
    Fr,
    De,
    It,
    Ru,
    Zh,
    Ja,
    Ar,
}

impl Language {
    /// Resolve a partir de códigos tipo `pt-BR`, `pt-PT`, `en`, `zh-CN`…
    pub fn from_code(code: &str) -> Language {
        let c = code.to_lowercase().replace('_', "-");
        let base = c.split('-').next().unwrap_or("en");
        match base {
            "pt" => {
                // "pt" genérico e "pt-BR" → Brasil (padrão); "pt-PT" → Portugal.
                if c.ends_with("-pt") {
                    Language::PtPt
                } else {
                    Language::PtBr
                }
            }
            "es" => Language::Es,
            "fr" => Language::Fr,
            "de" => Language::De,
            "it" => Language::It,
            "ru" => Language::Ru,
            "zh" => Language::Zh,
            "ja" => Language::Ja,
            "ar" => Language::Ar,
            _ => Language::En,
        }
    }

    /// Código BCP-47 canônico.
    pub fn code(&self) -> &'static str {
        match self {
            Language::PtBr => "pt-BR",
            Language::PtPt => "pt-PT",
            Language::En => "en",
            Language::Es => "es",
            Language::Fr => "fr",
            Language::De => "de",
            Language::It => "it",
            Language::Ru => "ru",
            Language::Zh => "zh-CN",
            Language::Ja => "ja",
            Language::Ar => "ar",
        }
    }

    /// Idiomas com direção direita→esquerda (§8.4).
    pub fn is_rtl(&self) -> bool {
        matches!(self, Language::Ar)
    }

    /// Notas de cultura/formalidade usadas no prompt de sistema.
    pub fn culture_notes(&self) -> &'static str {
        match self {
            Language::PtBr => "Use portugues do Brasil, tom acolhedor e direto.",
            Language::PtPt => {
                "Use portugues de Portugal, pronomes na 2a pessoa do plural quando formal."
            }
            Language::En => "Use clear, neutral international English.",
            Language::Es => "Use espanol neutro comprensible en toda Hispanoamérica.",
            Language::Fr => "Utilisez un francais neutre et poli.",
            Language::De => "Verwenden Sie ein neutrales, hofliches Deutsch.",
            Language::It => "Usa un italiano neutro e cortese.",
            Language::Ru => "Используйте нейтральный вежливый русский язык.",
            Language::Zh => "使用简体中文，语气礼貌自然。",
            Language::Ja => "丁寧で自然な日本語を使用してください。",
            Language::Ar => "استخدم اللغة العربية الفصحى المبسطة بأسلوب مهذب.",
        }
    }
}

/// Constrói o prompt de sistema do assistente.
///
/// `tool_catalog_json` é a serialização do catálogo de ferramentas registradas.
/// `privacy_statement` embute a regra de privacidade local-first no modelo.
pub fn system_prompt(lang: Language, tool_catalog_json: &str, privacy_statement: bool) -> String {
    let mut prompt = String::new();
    prompt.push_str(&format!(
        "Voce e o {name}, um assistente virtual que roda localmente no dispositivo do usuario.\n\
         Regras fundamentais:\n\
         1. Voce NAO executa acoes diretamente. Para agir, selecione UMA ferramenta do catalogo \n\
            abaixo e devolva um JSON: {{\"tool\": \"<id>\", \"params\": {{...}}}}.\n\
         2. NUNCA invente ferramentas, IDs ou parametros fora do catalogo.\n\
         3. Acoes sensiveis serao confirmadas por um humano; informe isso quando relevante.\n\
         4. Responda SEMPRE no idioma do usuario (idioma padrao: {code}). {culture}\n\
         5. Se faltar informacao, pergunte antes de agir.\n",
        name = crate::PRODUCT_NAME,
        code = lang.code(),
        culture = lang.culture_notes(),
    ));
    if privacy_statement {
        prompt.push_str(
            "6. Privacidade: nada sai do dispositivo sem acao explicita do usuario. \
             Nao incentive envio de dados a servicos externos.\n",
        );
    }
    prompt.push_str(&format!(
        "\nCatalogo de ferramentas registradas (JSON):\n{tool_catalog_json}\n"
    ));
    prompt
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resolucao_de_codigos() {
        assert_eq!(Language::from_code("pt-BR"), Language::PtBr);
        assert_eq!(Language::from_code("pt-PT"), Language::PtPt);
        assert_eq!(Language::from_code("pt"), Language::PtBr);
        assert_eq!(Language::from_code("zh_CN"), Language::Zh);
        assert_eq!(Language::from_code("xyz"), Language::En);
    }

    #[test]
    fn apenas_arabe_e_rtl() {
        assert!(Language::Ar.is_rtl());
        // Hebraico e outros idiomas RTL entram na Fase 9 (idiomas adicionais).
        assert!(!Language::En.is_rtl());
        assert!(!Language::Ja.is_rtl());
    }

    #[test]
    fn prompt_inclui_catalogo_e_regras() {
        let p = system_prompt(Language::PtBr, r#"[{"id":"time.now"}]"#, true);
        assert!(p.contains("Geny Assistant"));
        assert!(p.contains("time.now"));
        assert!(p.contains("pt-BR"));
        assert!(p.contains("Privacidade"));
    }
}
