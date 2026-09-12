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
        let key = key.into();
        self.facts.insert(
            key.clone(),
            Fact {
                key,
                value: value.into(),
                tags,
                updated_at_ms: now_ms(),
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
}
