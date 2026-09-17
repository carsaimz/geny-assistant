//! Memória do assistente.
//!
//! v0 (Fase 1): memória de longo prazo baseada em fatos chave→valor em memória,
//! com exportação/importação JSON para persistência pela plataforma.
//! Fase 5 do roadmap adicionará memória semântica com embeddings locais.

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

use crate::session::now_ms;

/// Fato persistente aprendido sobre o usuário ou o ambiente.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Fact {
    pub key: String,
    pub value: String,
    #[serde(default)]
    pub tags: Vec<String>,
    pub updated_at_ms: u64,
}

/// Memória de longo prazo: fatos, preferências e rotinas recorrentes.
#[derive(Debug, Clone, Default)]
pub struct LongTermMemory {
    facts: BTreeMap<String, Fact>,
}

/// Envelope versionado de exportação/importação (core-09).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub(crate) struct MemoryEnvelope {
    pub version: u32,
    #[serde(default)]
    pub exported_at_ms: u64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub retention: Option<crate::retention::RetentionPolicy>,
    #[serde(default = "Vec::new")]
    pub facts: Vec<Fact>,
}

impl LongTermMemory {
    pub fn new() -> Self {
        Self::default()
    }

    /// Registra (ou atualiza) um fato.
    pub fn remember(
        &mut self,
        key: impl Into<String>,
        value: impl Into<String>,
        tags: Vec<String>,
    ) {
        self.remember_at(key, value, tags, now_ms());
    }

    /// Registra (ou atualiza) um fato com carimbo de tempo explícito —
    /// usado na importação (preservar a idade do fato) e em testes.
    pub fn remember_at(
        &mut self,
        key: impl Into<String>,
        value: impl Into<String>,
        tags: Vec<String>,
        updated_at_ms: u64,
    ) {
        let key = key.into();
        self.facts.insert(
            key.clone(),
            Fact {
                key,
                value: value.into(),
                tags,
                updated_at_ms,
            },
        );
    }

    /// Recupera um fato pela chave.
    pub fn recall(&self, key: &str) -> Option<&Fact> {
        self.facts.get(key)
    }

    /// Busca simples por substring em chave, valor e tags (v0).
    /// A busca semântica por embeddings será adicionada na Fase 5.
    pub fn search(&self, query: &str) -> Vec<&Fact> {
        let q = query.to_lowercase();
        self.facts
            .values()
            .filter(|f| {
                f.key.to_lowercase().contains(&q)
                    || f.value.to_lowercase().contains(&q)
                    || f.tags.iter().any(|t| t.to_lowercase().contains(&q))
            })
            .collect()
    }

    /// Esquece um fato. Retorna `true` se existia.
    pub fn forget(&mut self, key: &str) -> bool {
        self.facts.remove(key).is_some()
    }

    /// Todos os fatos ordenados pela chave.
    pub fn all(&self) -> Vec<&Fact> {
        self.facts.values().collect()
    }

    /// Número de fatos armazenados.
    pub fn len(&self) -> usize {
        self.facts.len()
    }

    pub fn is_empty(&self) -> bool {
        self.facts.is_empty()
    }

    /// Exporta a memória para JSON (backup/importação do usuário).
    pub fn to_json(&self) -> String {
        serde_json::to_string_pretty(&self.facts.values().collect::<Vec<_>>())
            .unwrap_or_else(|_| "[]".to_string())
    }

    /// Importa fatos de um snapshot JSON produzido por [`LongTermMemory::to_json`].
    pub fn from_json(json: &str) -> crate::error::Result<Self> {
        let facts: Vec<Fact> = serde_json::from_str(json)
            .map_err(|e| crate::error::CoreError::Internal(e.to_string()))?;
        let mut mem = LongTermMemory::new();
        for f in facts {
            mem.facts.insert(f.key.clone(), f);
        }
        Ok(mem)
    }

    /// Envelope versionado de exportação (TODO core-09): versão, carimbo,
    /// política de retenção e fatos — o mesmo formato usado pelo backup
    /// cifrado do Android (app-04) e pelos métodos `memory*` da ponte.
    pub fn to_envelope_json(
        &self,
        retention: &crate::retention::RetentionPolicy,
        exported_at_ms: u64,
    ) -> String {
        let envelope = MemoryEnvelope {
            version: 1,
            exported_at_ms,
            retention: Some(*retention),
            facts: self.facts.values().cloned().collect(),
        };
        serde_json::to_string(&envelope)
            .unwrap_or_else(|_| "{\"version\":1,\"facts\":[]}".to_string())
    }

    /// Importa um envelope versionado OU o formato legado (array puro).
    /// Fatos preservam o carimbo original (`updated_at_ms`).
    pub fn from_envelope_json(json: &str) -> crate::error::Result<Self> {
        // Formato legado (array): aceito para compatibilidade com v0.1+.
        let trimmed = json.trim_start();
        if trimmed.starts_with('[') {
            return Self::from_json(json);
        }
        let envelope: MemoryEnvelope = serde_json::from_str(json)
            .map_err(|e| crate::error::CoreError::Internal(e.to_string()))?;
        let mut mem = LongTermMemory::new();
        for f in envelope.facts {
            mem.facts.insert(f.key.clone(), f);
        }
        Ok(mem)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lembrar_recuperar_esquecer() {
        let mut mem = LongTermMemory::new();
        mem.remember("idioma.preferido", "pt-BR", vec!["preferencia".into()]);
        assert!(mem.recall("idioma.preferido").is_some());
        assert_eq!(mem.len(), 1);
        assert!(mem.forget("idioma.preferido"));
        assert!(!mem.forget("idioma.preferido"));
        assert!(mem.is_empty());
    }

    #[test]
    fn busca_por_tag_e_valor() {
        let mut mem = LongTermMemory::new();
        mem.remember("casa.wifi", "MinhaRede5G", vec!["rede".into()]);
        mem.remember("trabalho.horario", "08:00", vec!["rotina".into()]);
        assert_eq!(mem.search("wifi").len(), 1);
        assert_eq!(mem.search("rotina").len(), 1);
        assert_eq!(mem.search("minharede").len(), 1);
        assert_eq!(mem.search("inexistente").len(), 0);
    }

    #[test]
    fn exportacao_importacao_roundtrip() {
        let mut mem = LongTermMemory::new();
        mem.remember("a", "1", vec![]);
        mem.remember("b", "2", vec!["x".into()]);
        let json = mem.to_json();
        let restored = LongTermMemory::from_json(&json).unwrap();
        assert_eq!(restored.len(), 2);
        assert_eq!(restored.recall("b").unwrap().value, "2");
    }

    #[test]
    fn envelope_versionado_roundtrip_e_legado() {
        use crate::retention::RetentionPolicy;
        let mut mem = LongTermMemory::new();
        mem.remember_at("wifi", "MinhaRede5G", vec!["rede".into()], 123);
        mem.remember_at("niver", "10/03", vec![], 456);

        let json = mem.to_envelope_json(&RetentionPolicy::default_enabled(), 999);
        let restored = LongTermMemory::from_envelope_json(&json).unwrap();
        assert_eq!(restored.len(), 2);
        // Carimbo original preservado.
        assert_eq!(restored.recall("wifi").unwrap().updated_at_ms, 123);
        assert_eq!(restored.recall("niver").unwrap().updated_at_ms, 456);

        // JSON contém metadados do envelope.
        assert!(json.contains("\"version\":1"));
        assert!(json.contains("\"exported_at_ms\":999"));
        assert!(json.contains("\"retention\""));

        // Formato legado (array puro) continua aceito.
        let legacy = mem.to_json();
        let from_legacy = LongTermMemory::from_envelope_json(&legacy).unwrap();
        assert_eq!(from_legacy.len(), 2);

        // Envelope inválido é rejeitado com erro tipado.
        assert!(LongTermMemory::from_envelope_json("{").is_err());
    }

    #[test]
    fn remember_at_preserva_carimbo() {
        let mut mem = LongTermMemory::new();
        mem.remember_at("k", "v", vec![], 42);
        assert_eq!(mem.recall("k").unwrap().updated_at_ms, 42);
        // remember normal atualiza o carimbo (>= anterior).
        mem.remember("k", "v2", vec![]);
        assert!(mem.recall("k").unwrap().updated_at_ms >= 42);
    }
}
