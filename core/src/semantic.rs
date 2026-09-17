//! Índice vetorial em memória (TODO core-08, Fase 5) — feature `semantic`.
//!
//! **PT** "sqlite-vec ou equivalente" (ROADMAP): o equivalente escolhido é um
//! índice vetorial in-process — chave → vetor — com busca top-k por cosseno.
//! Fatos do assistente ficam na casa de centenas, então a varredura linear
//! (custo O(n·d), d=256) é imperceptível e dispensa extensões SQL externas —
//! mais um passo para o core zero-dep, auditável e fácil de portar. A
//! persistência é feita pela plataforma (Room no Android; JSON de
//! exportação/importação), e o índice é reconstruído deterministicamente a
//! partir dos fatos.
//! **EN** "sqlite-vec or equivalent" (ROADMAP): the chosen equivalent is an
//! in-process vector index — key → vector — with top-k cosine search. Assistant
//! facts sit in the hundreds, so linear scan (O(n·d), d=256) is imperceptible
//! and avoids external SQL extensions — one more step towards a zero-dep,
//! auditable, easy-to-port core. Persistence is the platform's job (Room on
//! Android; export/import JSON); the index rebuilds deterministically from
//! facts.

use std::collections::BTreeMap;

use crate::embed::{cosine, Embedder};

/// Um hit da busca semântica: chave do documento e score [−1..1].
#[derive(Debug, Clone, PartialEq)]
pub struct SemanticHit {
    pub key: String,
    pub score: f32,
}

/// Índice chave→vetor com busca top-k por cosseno.
#[derive(Debug, Clone, Default)]
pub struct SemanticIndex {
    vectors: BTreeMap<String, Vec<f32>>,
}

impl SemanticIndex {
    pub fn new() -> Self {
        Self::default()
    }

    /// Insere/atualiza o vetor de uma chave a partir do texto.
    pub fn add(&mut self, embedder: &dyn Embedder, key: impl Into<String>, text: &str) {
        let vec = embedder.embed(text);
        self.vectors.insert(key.into(), vec);
    }

    /// Remove uma chave; retorna `true` se existia.
    pub fn remove(&mut self, key: &str) -> bool {
        self.vectors.remove(key).is_some()
    }

    /// Remove todas as entradas.
    pub fn clear(&mut self) {
        self.vectors.clear();
    }

    /// Número de documentos indexados.
    pub fn len(&self) -> usize {
        self.vectors.len()
    }

    pub fn is_empty(&self) -> bool {
        self.vectors.is_empty()
    }

    /// Verifica se uma chave está indexada.
    pub fn contains(&self, key: &str) -> bool {
        self.vectors.contains_key(key)
    }

    /// Reconstrói todo o índice a partir de pares (chave, texto).
    pub fn rebuild(
        &mut self,
        embedder: &dyn Embedder,
        documents: impl Iterator<Item = (String, String)>,
    ) {
        self.vectors.clear();
        for (key, text) in documents {
            self.add(embedder, key, &text);
        }
    }

    /// Busca top-k por cosseno, ordenada por score decrescente.
    ///
    /// Resultados com score abaixo de `min_score` são descartados
    /// (0.0 = qualquer sobreposição lexical).
    pub fn search(
        &self,
        embedder: &dyn Embedder,
        query: &str,
        k: usize,
        min_score: f32,
    ) -> Vec<SemanticHit> {
        let q = embedder.embed(query);
        let mut hits: Vec<SemanticHit> = self
            .vectors
            .iter()
            .map(|(key, vec)| SemanticHit {
                key: key.clone(),
                score: cosine(&q, vec),
            })
            .filter(|h| h.score >= min_score)
            .collect();
        hits.sort_by(|a, b| {
            b.score
                .partial_cmp(&a.score)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| a.key.cmp(&b.key))
        });
        hits.truncate(k);
        hits
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::embed::HashingEmbedder;

    fn e() -> HashingEmbedder {
        HashingEmbedder
    }

    #[test]
    fn add_remove_contains_e_tamanhos() {
        let mut idx = SemanticIndex::new();
        assert!(idx.is_empty());
        idx.add(&e(), "wifi", "senha do wifi de casa");
        idx.add(&e(), "aniversario", "aniversario da Maria dia 10");
        assert_eq!(idx.len(), 2);
        assert!(idx.contains("wifi"));
        assert!(idx.remove("wifi"));
        assert!(!idx.remove("wifi"));
        assert_eq!(idx.len(), 1);
        idx.clear();
        assert!(idx.is_empty());
    }

    #[test]
    fn top_k_ordenado_por_relevancia() {
        let mut idx = SemanticIndex::new();
        idx.add(&e(), "wifi", "wifi: MinhaRede5G senha 12345678");
        idx.add(&e(), "dentista", "consulta no dentista quinta as 15h");
        idx.add(&e(), "gas", "botijao de gas acaba em junho");

        let hits = idx.search(&e(), "qual a senha do wifi?", 2, 0.0);
        assert_eq!(hits.len(), 2);
        assert_eq!(hits[0].key, "wifi", "mais relevante deve vir primeiro");
        assert!(hits[0].score > hits[1].score);

        // k limita o resultado.
        let one = idx.search(&e(), "qual a senha do wifi?", 1, 0.0);
        assert_eq!(one.len(), 1);
        assert_eq!(one[0].key, "wifi");
    }

    #[test]
    fn min_score_filtra_resultados_fracos() {
        let mut idx = SemanticIndex::new();
        idx.add(&e(), "gas", "botijao de gas acaba em junho");
        // Assunto totalmente distinto não deve passar de um teto alto.
        let hits = idx.search(&e(), "receita de bolo de chocolate", 5, 0.35);
        assert!(hits.is_empty(), "esperado vazio, veio: {hits:?}");
    }

    #[test]
    fn rebuild_substitui_conteudo() {
        let mut idx = SemanticIndex::new();
        idx.add(&e(), "antigo", "fato antigo");
        idx.rebuild(
            &e(),
            [
                ("novo1".to_string(), "fato novo um".to_string()),
                ("novo2".to_string(), "fato novo dois".to_string()),
            ]
            .into_iter(),
        );
        assert_eq!(idx.len(), 2);
        assert!(!idx.contains("antigo"));
        assert!(idx.contains("novo1") && idx.contains("novo2"));
    }

    #[test]
    fn atualizacao_por_chave_substitui_vetor() {
        let mut idx = SemanticIndex::new();
        idx.add(&e(), "x", "texto sobre jardinagem e plantas");
        idx.add(&e(), "x", "texto sobre futebol e campeonato");
        assert_eq!(idx.len(), 1);
        let hits = idx.search(&e(), "futebol campeonato", 5, 0.2);
        assert_eq!(hits.len(), 1, "deve bater o texto novo");
    }
}
