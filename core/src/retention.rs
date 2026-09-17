//! Política de retenção da memória (TODO core-09, Fase 5).
//!
//! **PT** Exclusão automática configurável de fatos: limite de quantidade
//! (descarta os mais antigos primeiro), de idade e de tamanho por valor.
//! Padrão é NENHUM limite — a memória só é apagada quando o usuário pede ou
//! define uma política. A política é serializável para entrar no backup e no
//! envelope de exportação.
//! **EN** Configurable automatic retention of facts: quantity cap (oldest
//! first), age cap and per-value size cap. Default is NO limits — memory is
//! only erased when the user asks or sets a policy. The policy serializes
//! into backups and the export envelope.

use serde::{Deserialize, Serialize};

use crate::memory::LongTermMemory;

/// Política de retenção; `None` = sem limite naquela dimensão.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct RetentionPolicy {
    /// Número máximo de fatos (excedente: apaga os mais antigos).
    #[serde(default)]
    pub max_facts: Option<u32>,
    /// Idade máxima em dias desde `updated_at_ms`.
    #[serde(default)]
    pub max_age_days: Option<u64>,
    /// Tamanho máximo do valor em bytes (UTF-8).
    #[serde(default)]
    pub max_value_bytes: Option<u64>,
}

// Default manual mantido para deixar explícito que TODOS os limites começam
// desligados (política nenhuma) — derive() esconderia essa decisão.
#[allow(clippy::derivable_impls)]
impl Default for RetentionPolicy {
    fn default() -> Self {
        Self {
            max_facts: None,
            max_age_days: None,
            max_value_bytes: None,
        }
    }
}

impl RetentionPolicy {
    /// Política "ativa" de referência (usada como default na UI): 500 fatos,
    /// 365 dias, 4 KiB por valor — limites generosos que evitam crescimento
    /// descontrolado sem apagar nada que o usuário use de verdade.
    pub fn default_enabled() -> Self {
        Self {
            max_facts: Some(500),
            max_age_days: Some(365),
            max_value_bytes: Some(4096),
        }
    }

    /// Indica se a política tem alguma regra ativa.
    pub fn is_active(&self) -> bool {
        self.max_facts.is_some() || self.max_age_days.is_some() || self.max_value_bytes.is_some()
    }

    /// Aplica a política na memória, removendo fatos e retornando as chaves
    /// esquecidas (em ordem determinística: idade → tamanho → chave).
    pub fn apply(&self, memory: &mut LongTermMemory, now_ms: u64) -> Vec<String> {
        let mut forgotten = Vec::new();
        if !self.is_active() {
            return forgotten;
        }

        // 1) Idade máxima.
        if let Some(days) = self.max_age_days {
            let cutoff = now_ms.saturating_sub(days.saturating_mul(86_400_000));
            let keys: Vec<String> = memory
                .all()
                .iter()
                .filter(|f| f.updated_at_ms < cutoff)
                .map(|f| f.key.clone())
                .collect();
            for key in keys {
                if memory.forget(&key) {
                    forgotten.push(key);
                }
            }
        }

        // 2) Tamanho por valor.
        if let Some(max_bytes) = self.max_value_bytes {
            let keys: Vec<String> = memory
                .all()
                .iter()
                .filter(|f| f.value.len() as u64 > max_bytes)
                .map(|f| f.key.clone())
                .collect();
            for key in keys {
                if memory.forget(&key) {
                    forgotten.push(key);
                }
            }
        }

        // 3) Quantidade máxima (os mais antigos saem primeiro).
        if let Some(max) = self.max_facts.map(|m| m as usize) {
            let len = memory.len();
            if len > max {
                let mut by_age: Vec<(u64, String)> = memory
                    .all()
                    .iter()
                    .map(|f| (f.updated_at_ms, f.key.clone()))
                    .collect();
                // Ordem determinística: mais antigo primeiro, chave como desempate.
                by_age.sort_by(|a, b| a.0.cmp(&b.0).then_with(|| a.1.cmp(&b.1)));
                for (_, key) in by_age.into_iter().take(len - max) {
                    if memory.forget(&key) {
                        forgotten.push(key);
                    }
                }
            }
        }

        forgotten.sort();
        forgotten.dedup();
        forgotten
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mem_with(key: &str, value: &str, at_ms: u64) -> LongTermMemory {
        let mut mem = LongTermMemory::new();
        mem.remember_at(key.to_string(), value.to_string(), vec![], at_ms);
        mem
    }

    #[test]
    fn default_nao_apaga_nada() {
        let mut mem = mem_with("a", "1", 1_000);
        let forgotten = RetentionPolicy::default().apply(&mut mem, 100_000_000);
        assert!(forgotten.is_empty());
        assert_eq!(mem.len(), 1);
        assert!(!RetentionPolicy::default().is_active());
        assert!(RetentionPolicy::default_enabled().is_active());
    }

    #[test]
    fn idade_maxima_remove_fatos_antigos() {
        // 90 dias em ms.
        let day: u64 = 86_400_000;
        let mut mem = LongTermMemory::new();
        mem.remember_at("velho", "v", vec![], 10 * day);
        mem.remember_at("novo", "v", vec![], 90 * day);
        let policy = RetentionPolicy {
            max_age_days: Some(60),
            ..Default::default()
        };
        let forgotten = policy.apply(&mut mem, 95 * day);
        assert_eq!(forgotten, vec!["velho".to_string()]);
        assert!(mem.recall("novo").is_some());
        assert!(mem.recall("velho").is_none());
    }

    #[test]
    fn tamanho_maximo_remove_valores_grandes() {
        let mut mem = LongTermMemory::new();
        mem.remember_at("ok", "curto", vec![], 1);
        mem.remember_at("grande", "x".repeat(100), vec![], 1);
        let policy = RetentionPolicy {
            max_value_bytes: Some(50),
            ..Default::default()
        };
        let forgotten = policy.apply(&mut mem, 2);
        assert_eq!(forgotten, vec!["grande".to_string()]);
    }

    #[test]
    fn limite_de_quantidade_apaga_mais_antigos_primeiro() {
        let mut mem = LongTermMemory::new();
        for (i, (k, at)) in [("a", 3), ("b", 1), ("c", 2)].iter().enumerate() {
            mem.remember_at(*k, i.to_string(), vec![], *at as u64 * 1000);
        }
        let policy = RetentionPolicy {
            max_facts: Some(2),
            ..Default::default()
        };
        let forgotten = policy.apply(&mut mem, 10_000);
        // "b" é o mais antigo (at=1s) e deve sair.
        assert_eq!(forgotten, vec!["b".to_string()]);
        assert_eq!(mem.len(), 2);
        assert!(mem.recall("b").is_none());
    }

    #[test]
    fn regras_combinadas_sao_dedup_em_ordem_estavel() {
        let now: u64 = 10 * 86_400_000;
        let mut mem = LongTermMemory::new();
        mem.remember_at("antigo_grande", "x".repeat(80), vec![], 5);
        mem.remember_at("recente", "ok", vec![], now - 1_000);
        let policy = RetentionPolicy {
            max_age_days: Some(1),
            max_value_bytes: Some(50),
            ..Default::default()
        };
        let forgotten = policy.apply(&mut mem, now);
        // O mesmo fato bate duas regras; só pode sair UMA vez. "recente"
        // (atualizado 1s antes de agora) fica.
        assert_eq!(forgotten, vec!["antigo_grande".to_string()]);
        assert_eq!(mem.len(), 1);
    }

    #[test]
    fn politica_serializa_roundtrip() {
        let policy = RetentionPolicy::default_enabled();
        let json = serde_json::to_string(&policy).unwrap();
        let back: RetentionPolicy = serde_json::from_str(&json).unwrap();
        assert_eq!(back, policy);
        // Campos ausentes viram None (sem limite).
        let empty: RetentionPolicy = serde_json::from_str("{}").unwrap();
        assert_eq!(empty, RetentionPolicy::default());
    }
}
