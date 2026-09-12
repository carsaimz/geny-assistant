//! Catálogo de ferramentas internas (sem root) espelhando as implementações
//! Kotlin em `android/app/src/main/kotlin/.../tools/`.
//!
//! Root e dispositivos externos entram nas Fases 7 e 8 (ver ROADMAP.md).

use crate::confirmation::ConfirmationLevel;
use crate::tools::registry::{ParamSpec, ParamType, ToolContext, ToolDefinition};

/// Catálogo padrão da Fase 1/4 (ferramentas essenciais sem root).
pub fn builtin_catalog() -> Vec<ToolDefinition> {
    vec![
        // ---------- Hora e dispositivo ----------
        ToolDefinition::simple(
            "time.now",
            "Hora atual",
            "Consulta a data e a hora atuais do dispositivo, com fuso local.",
            ConfirmationLevel::None,
            ToolContext::App,
        ),
        ToolDefinition {
            id: "device.battery".into(),
            name: "Estado da bateria".into(),
            description:
                "Consulta nivel de bateria, se esta carregando e modo economia de energia.".into(),
            params: Vec::new(),
            permissions: Vec::new(),
            confirmation: ConfirmationLevel::None,
            context: ToolContext::App,
            timeout_ms: 10_000,
        },
        // ---------- Aplicativos ----------
        ToolDefinition {
            id: "apps.list".into(),
            name: "Listar aplicativos".into(),
            description:
                "Lista aplicativos instalados no dispositivo, opcionalmente filtrando por nome."
                    .into(),
            params: vec![opt_str("query", "filtro opcional pelo nome do app")],
            permissions: Vec::new(),
            confirmation: ConfirmationLevel::None,
            context: ToolContext::App,
            timeout_ms: 15_000,
        },
        ToolDefinition {
            id: "apps.open".into(),
            name: "Abrir aplicativo".into(),
            description: "Abre um aplicativo pelo nome ou pelo nome do pacote.".into(),
            params: vec![req_str(
                "app",
                "nome do aplicativo ou pacote, ex.: 'whatsapp' ou 'com.whatsapp'",
            )],
            permissions: Vec::new(),
            confirmation: ConfirmationLevel::None,
            context: ToolContext::App,
            timeout_ms: 10_000,
        },
        // ---------- Comunicação (acao sensivel = confirmacao) ----------
        ToolDefinition {
            id: "call.dial".into(),
            name: "Discar telefone".into(),
            description: "Abre o discador com o numero preenchido. Nao liga automaticamente."
                .into(),
            params: vec![req_str("number", "numero de telefone a discar")],
            permissions: vec!["android.permission.CALL_PHONE".into()],
            confirmation: ConfirmationLevel::Explicit,
            context: ToolContext::App,
            timeout_ms: 10_000,
        },
        ToolDefinition {
            id: "sms.send".into(),
            name: "Enviar SMS".into(),
            description:
                "Envia uma mensagem SMS para um numero. Acao com impacto: exige confirmacao.".into(),
            params: vec![
                req_str("to", "numero de destino"),
                req_str("body", "texto da mensagem"),
            ],
            permissions: vec!["android.permission.SEND_SMS".into()],
            confirmation: ConfirmationLevel::Explicit,
            context: ToolContext::App,
            timeout_ms: 15_000,
        },
        // ---------- Produtividade ----------
        ToolDefinition {
            id: "notes.create".into(),
            name: "Criar nota".into(),
            description: "Cria uma nota de texto simples no dispositivo (reversivel).".into(),
            params: vec![
                req_str("title", "titulo da nota"),
                req_str("body", "conteudo da nota"),
            ],
            permissions: Vec::new(),
            confirmation: ConfirmationLevel::Simple,
            context: ToolContext::App,
            timeout_ms: 10_000,
        },
        ToolDefinition {
            id: "reminders.set".into(),
            name: "Definir lembrete".into(),
            description: "Define um alarme/lembrete para um horario especifico (reversivel)."
                .into(),
            params: vec![
                req_str("when", "horario ISO-8601 local, ex.: 2025-12-25T08:00"),
                req_str("label", "descricao do lembrete"),
            ],
            permissions: vec![
                "com.android.alarm.permission.SET_ALARM".into(),
                "android.permission.POST_NOTIFICATIONS".into(),
            ],
            confirmation: ConfirmationLevel::Simple,
            context: ToolContext::App,
            timeout_ms: 10_000,
        },
        // ---------- Notificacoes ----------
        ToolDefinition {
            id: "notifications.read".into(),
            name: "Ler notificacoes".into(),
            description: "Le as notificacoes ativas de outros aplicativos, com filtro opcional."
                .into(),
            params: vec![opt_str("query", "filtro opcional por texto ou aplicativo")],
            permissions: vec!["android.permission.BIND_NOTIFICATION_LISTENER_SERVICE".into()],
            confirmation: ConfirmationLevel::None,
            context: ToolContext::Service,
            timeout_ms: 10_000,
        },
        // ---------- Web ----------
        ToolDefinition {
            id: "web.search".into(),
            name: "Pesquisar na web".into(),
            description: "Abre o navegador padrao com uma pesquisa web.".into(),
            params: vec![req_str("query", "termos da pesquisa")],
            permissions: Vec::new(),
            confirmation: ConfirmationLevel::None,
            context: ToolContext::App,
            timeout_ms: 10_000,
        },
        // ---------- Localizacao ----------
        ToolDefinition {
            id: "location.get".into(),
            name: "Obter localizacao".into(),
            description: "Obtem a localizacao aproximada atual do dispositivo. Dados sensíveis."
                .into(),
            params: Vec::new(),
            permissions: vec![
                "android.permission.ACCESS_FINE_LOCATION".into(),
                "android.permission.ACCESS_COARSE_LOCATION".into(),
            ],
            confirmation: ConfirmationLevel::Simple,
            context: ToolContext::App,
            timeout_ms: 20_000,
        },
    ]
}

fn req_str(name: &str, description: &str) -> ParamSpec {
    ParamSpec {
        name: name.to_string(),
        r#type: ParamType::String,
        required: true,
        description: description.to_string(),
        allowed_values: None,
    }
}

fn opt_str(name: &str, description: &str) -> ParamSpec {
    ParamSpec {
        name: name.to_string(),
        r#type: ParamType::String,
        required: false,
        description: description.to_string(),
        allowed_values: None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tools::validator::validate_params;

    #[test]
    fn catalogo_tem_ids_unicos_e_organizados() {
        let cat = builtin_catalog();
        let mut ids: Vec<&str> = cat.iter().map(|d| d.id.as_str()).collect();
        ids.sort();
        let initial_len = ids.len();
        ids.dedup();
        assert_eq!(ids.len(), initial_len, "ids duplicados no catalogo");
        assert!(
            cat.len() >= 10,
            "catalogo essencial deve ter >= 10 ferramentas"
        );
    }

    #[test]
    fn ferramentas_sensiveis_tem_confirmacao_adequada() {
        let cat = builtin_catalog();
        let sms = cat.iter().find(|d| d.id == "sms.send").unwrap();
        assert!(sms.confirmation >= ConfirmationLevel::Explicit);
        assert!(!sms.permissions.is_empty());
        let time = cat.iter().find(|d| d.id == "time.now").unwrap();
        assert_eq!(time.confirmation, ConfirmationLevel::None);
    }

    #[test]
    fn esquemas_do_catalogo_sao_validos_para_exemplos() {
        let cat = builtin_catalog();
        let open = cat.iter().find(|d| d.id == "apps.open").unwrap();
        assert!(validate_params(open, &serde_json::json!({"app": "camera"})).is_ok());
        let battery = cat.iter().find(|d| d.id == "device.battery").unwrap();
        assert!(validate_params(battery, &serde_json::Value::Null).is_ok());
    }
}
