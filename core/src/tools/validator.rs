//! Validação estrita de parâmetros antes de qualquer execução (§12.5).

use serde_json::{Map, Value};

use crate::error::{CoreError, Result};

use super::registry::{ParamType, ToolDefinition};

/// Valida os parâmetros de uma chamada contra o esquema da ferramenta.
///
/// Regras:
/// - Os parâmetros devem ser um objeto JSON (ou `null`/ausente se nada for exigido).
/// - Parâmetros desconhecidos são rejeitados.
/// - Parâmetros obrigatórios ausentes são rejeitados.
/// - Tipos devem corresponder (`integer` aceita número inteiro; `number` aceita qualquer numérico).
/// - Valores fora de `allowed_values` são rejeitados.
pub fn validate_params(def: &ToolDefinition, params: &Value) -> Result<()> {
    let map: Option<&Map<String, Value>> = match params {
        Value::Null => None,
        Value::Object(m) => Some(m),
        _ => return Err(validation_error(def, "parametros devem ser um objeto JSON")),
    };

    // Parâmetros desconhecidos — o modelo não inventa campos.
    if let Some(m) = map {
        for key in m.keys() {
            if !def.params.iter().any(|p| &p.name == key) {
                return Err(validation_error(
                    def,
                    &format!("parametro desconhecido: {key}"),
                ));
            }
        }
    }

    for spec in &def.params {
        let value = map.and_then(|m| m.get(&spec.name));

        match value {
            None | Some(Value::Null) => {
                if spec.required {
                    return Err(validation_error(
                        def,
                        &format!("parametro obrigatorio ausente: {}", spec.name),
                    ));
                }
            }
            Some(v) => {
                if !type_matches(&spec.r#type, v) {
                    return Err(validation_error(
                        def,
                        &format!(
                            "tipo invalido para '{}': esperado {}, obtido {}",
                            spec.name,
                            type_name(&spec.r#type),
                            json_type_name(v)
                        ),
                    ));
                }
                if let (Some(allowed), Value::String(s)) = (&spec.allowed_values, v) {
                    if !allowed.iter().any(|a| a == s) {
                        return Err(validation_error(
                            def,
                            &format!(
                                "valor '{}' nao permitido para '{}'; permitidos: {}",
                                s,
                                spec.name,
                                allowed.join(", ")
                            ),
                        ));
                    }
                }
            }
        }
    }
    Ok(())
}

fn validation_error(def: &ToolDefinition, reason: &str) -> CoreError {
    CoreError::Validation {
        tool: def.id.clone(),
        reason: reason.to_string(),
    }
}

fn type_matches(t: &ParamType, v: &Value) -> bool {
    match (t, v) {
        (ParamType::String, Value::String(_)) => true,
        (ParamType::Number, Value::Number(_)) => true,
        (ParamType::Integer, Value::Number(n)) => n.is_i64() || n.is_u64(),
        (ParamType::Boolean, Value::Bool(_)) => true,
        (ParamType::Array, Value::Array(_)) => true,
        (ParamType::Object, Value::Object(_)) => true,
        _ => false,
    }
}

fn type_name(t: &ParamType) -> &'static str {
    match t {
        ParamType::String => "string",
        ParamType::Number => "number",
        ParamType::Integer => "integer",
        ParamType::Boolean => "boolean",
        ParamType::Array => "array",
        ParamType::Object => "object",
    }
}

fn json_type_name(v: &Value) -> &'static str {
    match v {
        Value::Null => "null",
        Value::Bool(_) => "boolean",
        Value::Number(_) => "number",
        Value::String(_) => "string",
        Value::Array(_) => "array",
        Value::Object(_) => "object",
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::confirmation::ConfirmationLevel;
    use crate::tools::registry::{ParamSpec, ToolContext};

    fn sample_def() -> ToolDefinition {
        ToolDefinition {
            id: "sms.send".into(),
            name: "Enviar SMS".into(),
            description: "Envia um SMS".into(),
            params: vec![
                ParamSpec {
                    name: "to".into(),
                    r#type: ParamType::String,
                    required: true,
                    description: "numero de destino".into(),
                    allowed_values: None,
                },
                ParamSpec {
                    name: "body".into(),
                    r#type: ParamType::String,
                    required: true,
                    description: "texto da mensagem".into(),
                    allowed_values: None,
                },
                ParamSpec {
                    name: "priority".into(),
                    r#type: ParamType::String,
                    required: false,
                    description: "prioridade".into(),
                    allowed_values: Some(vec!["normal".into(), "alta".into()]),
                },
            ],
            permissions: vec!["android.permission.SEND_SMS".into()],
            confirmation: ConfirmationLevel::Explicit,
            context: ToolContext::App,
            timeout_ms: 10_000,
        }
    }

    #[test]
    fn aceita_parametros_validos() {
        let def = sample_def();
        let p = serde_json::json!({"to": "+258840000000", "body": "ola", "priority": "alta"});
        assert!(validate_params(&def, &p).is_ok());
    }

    #[test]
    fn aceita_nulo_quando_nada_obrigatorio() {
        let def = ToolDefinition::simple(
            "time.now",
            "Hora",
            "hora atual",
            ConfirmationLevel::None,
            ToolContext::App,
        );
        assert!(validate_params(&def, &Value::Null).is_ok());
    }

    #[test]
    fn rejeita_obrigatorio_ausente() {
        let def = sample_def();
        let p = serde_json::json!({"to": "+258840000000"});
        let err = validate_params(&def, &p).unwrap_err();
        assert!(
            matches!(err, CoreError::Validation { ref reason, .. } if reason.contains("obrigatorio"))
        );
    }

    #[test]
    fn rejeita_parametro_desconhecido() {
        let def = sample_def();
        let p = serde_json::json!({"to": "1", "body": "x", "hack": true});
        let err = validate_params(&def, &p).unwrap_err();
        assert!(
            matches!(err, CoreError::Validation { ref reason, .. } if reason.contains("desconhecido"))
        );
    }

    #[test]
    fn rejeita_tipo_incorreto() {
        let def = sample_def();
        let p = serde_json::json!({"to": 123, "body": "x"});
        let err = validate_params(&def, &p).unwrap_err();
        assert!(
            matches!(err, CoreError::Validation { ref reason, .. } if reason.contains("tipo invalido"))
        );
    }

    #[test]
    fn rejeita_valor_fora_do_enum() {
        let def = sample_def();
        let p = serde_json::json!({"to": "1", "body": "x", "priority": "urgente"});
        let err = validate_params(&def, &p).unwrap_err();
        assert!(
            matches!(err, CoreError::Validation { ref reason, .. } if reason.contains("nao permitido"))
        );
    }
}
