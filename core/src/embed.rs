//! Embeddings locais (TODO core-08, Fase 5) — feature `semantic`.
//!
//! **PT** Embedder determinístico multilíngue sem dependências externas:
//! n-gramas de caracteres (1–3) com hash estável (FNV-1a 64-bit) projetados
//! em um vetor fixo e normalizado (L2). Funciona para qualquer escrita —
//! latino, cirílico, han, kana, árabe — sem tokenizer, sem modelo, sem I/O,
//! ideal para um núcleo local-first e auditável. A rota de upgrade para
//! MiniLM via ONNX permanece no roadmap (a trait [`Embedder`] é o ponto de
//! extensão; o Android pode injetar um provider próprio no futuro).
//! **EN** Deterministic multilingual embedder with zero external deps:
//! character n-grams (1–3) hashed with a stable FNV-1a 64-bit and projected
//! into a fixed, L2-normalized vector. Works for any script — Latin, Cyrillic,
//! Han, kana, Arabic — with no tokenizer, no model, no I/O, fitting a
//! local-first auditable core. The MiniLM-via-ONNX upgrade path stays on the
//! roadmap (the [`Embedder`] trait is the extension point; Android may inject
//! its own provider later).

use std::collections::BTreeMap;

/// Dimensão padrão do vetor de embedding.
pub const EMBED_DIM: usize = 256;

/// Provedor de embeddings locais.
pub trait Embedder: Send + Sync {
    /// Embedding normalizado (norma L2 ≈ 1) do texto.
    fn embed(&self, text: &str) -> Vec<f32>;
    /// Dimensão do vetor produzido.
    fn dims(&self) -> usize;
}

/// Embedder determinístico por n-gramas de caracteres com hashing FNV-1a.
///
/// Substitui stopwords/idioma: n-gramas de 1 a 3 caracteres capturam
/// similaridade lexical multilíngue o suficiente para recall de memória
/// ("wifi de casa" ↔ "senha do wifi residencial").
#[derive(Debug, Clone, Copy, Default)]
pub struct HashingEmbedder;

impl HashingEmbedder {
    /// Peso por tipo de n-grama: unigrama 1.0, bigrama 2.0, trigrama 3.0 —
    /// bigramas/trigramas carregam mais contexto lexical.
    fn push_ngrams(map: &mut BTreeMap<u64, f32>, text: &str) {
        let lower = text.to_lowercase();
        let chars: Vec<char> = lower.chars().filter(|c| !c.is_whitespace()).collect();
        for (n, weight) in [(1usize, 1.0f32), (2, 2.0), (3, 3.0)] {
            if chars.len() < n {
                continue;
            }
            for win in chars.windows(n) {
                let mut s = String::with_capacity(n * 4);
                for c in win {
                    s.push(*c);
                }
                let h = fnv1a(s.as_bytes());
                *map.entry(h).or_insert(0.0) += weight;
            }
        }
    }
}

impl Embedder for HashingEmbedder {
    fn embed(&self, text: &str) -> Vec<f32> {
        let mut weights: BTreeMap<u64, f32> = BTreeMap::new();
        Self::push_ngrams(&mut weights, text);

        // Projeção estável hash→dimensão: dois hashes independentes
        // (h e h*0x9E3779B97F4A7C15) espalham colisões e suavizam o sinal.
        let mut vec = vec![0.0f32; EMBED_DIM];
        for (h, w) in &weights {
            let d1 = (h % EMBED_DIM as u64) as usize;
            let d2 = ((h.wrapping_mul(0x9E37_79B9_7F4A_7C15)) % EMBED_DIM as u64) as usize;
            let sign = if h & 1 == 0 { 1.0 } else { -1.0 };
            vec[d1] += sign * w;
            vec[d2] += 0.5 * w;
        }
        let norm = vec.iter().map(|v| v * v).sum::<f32>().sqrt();
        if norm > f32::EPSILON {
            for v in &mut vec {
                *v /= norm;
            }
        }
        vec
    }

    fn dims(&self) -> usize {
        EMBED_DIM
    }
}

/// FNV-1a 64-bit — estável entre execuções e plataformas (sem random seed).
fn fnv1a(bytes: &[u8]) -> u64 {
    let mut hash: u64 = 0xcbf2_9ce4_8422_2325;
    for b in bytes {
        hash ^= *b as u64;
        hash = hash.wrapping_mul(0x0000_0100_0000_01B3);
    }
    hash
}

/// Similaridade de cosseno entre dois vetores; 0.0 se norma zero.
pub fn cosine(a: &[f32], b: &[f32]) -> f32 {
    let n = a.len().min(b.len());
    let mut dot = 0.0f32;
    let mut na = 0.0f32;
    let mut nb = 0.0f32;
    for i in 0..n {
        dot += a[i] * b[i];
        na += a[i] * a[i];
        nb += b[i] * b[i];
    }
    if na <= f32::EPSILON || nb <= f32::EPSILON {
        return 0.0;
    }
    (dot / (na.sqrt() * nb.sqrt())).clamp(-1.0, 1.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dimensao_e_normalizacao() {
        let e = HashingEmbedder;
        let v = e.embed("Ola mundo");
        assert_eq!(v.len(), EMBED_DIM);
        let norm: f32 = v.iter().map(|x| x * x).sum::<f32>().sqrt();
        assert!((norm - 1.0).abs() < 1e-3, "norma {norm} deve ser ~1");
        assert_eq!(e.dims(), EMBED_DIM);
    }

    #[test]
    fn deterministico_e_diferente_por_texto() {
        let e = HashingEmbedder;
        assert_eq!(e.embed("abc"), e.embed("abc"));
        assert_ne!(e.embed("abc"), e.embed("xyz"));
    }

    #[test]
    fn textos_relacionados_tem_similaridade_maior() {
        let e = HashingEmbedder;
        let q = e.embed("qual e a senha do wifi de casa?");
        let near = e.embed("wifi: MinhaRede5G senha 12345678");
        let far = e.embed("agendar dentista quinta feira");
        let s_near = cosine(&q, &near);
        let s_far = cosine(&q, &far);
        assert!(
            s_near > s_far,
            "relacionado ({s_near}) deve superar não relacionado ({s_far})"
        );
    }

    #[test]
    fn multilingue_reconhece_mesmo_assunto() {
        let e = HashingEmbedder;
        // Lexical hashing é mono-escrita: textos relacionados em idiomas
        // distintos via modelo multilíngue (MiniLM) são upgrade futuro; aqui
        // garantimos que textos com termos em comum (mesmo escrita) superem
        // textos fora de contexto.
        let q = e.embed("wifi password");
        let zh = e.embed("家里的wifi密码"); // contém "wifi" literal
        let off = e.embed("receita de bolo de chocolate");
        assert!(
            cosine(&q, &zh) > cosine(&q, &off),
            "tema relacionado deve superar tema fora de contexto"
        );
    }

    #[test]
    fn cosseno_limitado_e_seguro() {
        assert!((cosine(&[1.0, 0.0], &[1.0, 0.0]) - 1.0).abs() < 1e-6);
        assert!(cosine(&[1.0, 0.0], &[0.0, 1.0]).abs() < 1e-6);
        assert!((cosine(&[1.0, 0.0], &[-1.0, 0.0]) + 1.0).abs() < 1e-6);
        // Vetores zero não podem produzir NaN.
        assert_eq!(cosine(&[0.0, 0.0], &[1.0, 2.0]), 0.0);
        assert_eq!(cosine(&[], &[]), 0.0);
    }

    #[test]
    fn texto_vazio_produz_vetor_zero() {
        let e = HashingEmbedder;
        assert!(e.embed("").iter().all(|v| *v == 0.0));
    }
}
