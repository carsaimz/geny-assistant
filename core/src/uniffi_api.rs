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

use std::sync::Arc;

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

/// Prompt de sistema com fatos de memória relevantes (Fase 5, core-08):
/// o recall acontece ANTES de responder e os fatos entram no prompt —
/// válidos para os backends remoto e local.
#[uniffi::export]
pub fn build_system_prompt_with_memory(
    language_code: String,
    tool_catalog_json: String,
    privacy_statement: bool,
    memory_lines: Vec<String>,
) -> String {
    crate::i18n::system_prompt_with_memory(
        Language::from_code(&language_code),
        &tool_catalog_json,
        privacy_statement,
        &memory_lines,
    )
}

// --------------------------------------------------------------- memória --
// TODO core-08/core-09 (Fase 5): objeto stateful exposto ao Kotlin.
// A política de persistência continua sendo da plataforma (Room); o core
// guarda fatos em memória + índice vetorial + retenção — o Android sincroniza
// na inicialização e a cada escrita (MemoryManager).

/// Registro de fato para a superfície UniFFI.
#[derive(Debug, Clone, uniffi::Record)]
pub struct MemoryRecord {
    pub key: String,
    pub value: String,
    pub tags: Vec<String>,
    pub updated_at_ms: u64,
}

/// Hit da busca semântica (com score de cosseno).
#[derive(Debug, Clone, uniffi::Record)]
pub struct MemoryHit {
    pub key: String,
    pub value: String,
    pub tags: Vec<String>,
    pub updated_at_ms: u64,
    pub score: f64,
}

/// Erros da superfície de memória expostos ao Kotlin.
#[derive(Debug, Clone, uniffi::Error)]
pub enum MemoryError {
    /// Envelope JSON inválido (export/import de memória).
    InvalidEnvelope { msg: String },
}

impl std::fmt::Display for MemoryError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            MemoryError::InvalidEnvelope { msg } => write!(f, "envelope inválido: {msg}"),
        }
    }
}

impl std::error::Error for MemoryError {}

/// Estado interno protegido por mutex (UniFFI chama de threads distintas).
struct MemoryState {
    memory: crate::memory::LongTermMemory,
    #[cfg(feature = "semantic")]
    index: crate::semantic::SemanticIndex,
    retention: crate::retention::RetentionPolicy,
}

/// Memória de longo prazo com índice semântico e política de retenção.
///
/// Criado via `GenyMemory()` no Kotlin gerado. Todas as operações são
/// síncronas e thread-safe. Persistência: exportar/importar o envelope
/// JSON — a fonte de verdade no Android é o Room (fatos) + este objeto
/// (índice em memória).
#[derive(uniffi::Object)]
pub struct GenyMemory {
    state: std::sync::Mutex<MemoryState>,
}

#[uniffi::export]
impl GenyMemory {
    #[uniffi::constructor]
    pub fn new() -> Arc<Self> {
        Arc::new(Self {
            state: std::sync::Mutex::new(MemoryState {
                memory: crate::memory::LongTermMemory::new(),
                #[cfg(feature = "semantic")]
                index: crate::semantic::SemanticIndex::new(),
                retention: crate::retention::RetentionPolicy::default(),
            }),
        })
    }

    /// Registra (ou atualiza) um fato, aplicando a retenção em seguida.
    /// Retorna as chaves esquecidas pela retenção, se houver.
    pub fn remember(&self, key: String, value: String, tags: Vec<String>) -> Vec<String> {
        let mut st = self.state.lock().expect("geny-memory poison");
        st.memory.remember(key.clone(), value.clone(), tags);
        #[cfg(feature = "semantic")]
        st.index.add(
            &crate::embed::HashingEmbedder,
            &key,
            &format!("{key} {value}"),
        );
        let forgotten = {
            let MemoryState {
                memory, retention, ..
            } = &mut *st;
            retention.apply(memory, crate::session::now_ms())
        };
        #[cfg(feature = "semantic")]
        for k in &forgotten {
            st.index.remove(k);
        }
        forgotten
    }

    /// Esquece um fato; retorna `true` se existia.
    pub fn forget(&self, key: String) -> bool {
        let mut st = self.state.lock().expect("geny-memory poison");
        let removed = st.memory.forget(&key);
        #[cfg(feature = "semantic")]
        {
            st.index.remove(&key);
        }
        removed
    }

    /// Apaga TODOS os fatos; retorna quantos foram removidos.
    pub fn clear(&self) -> u32 {
        let mut st = self.state.lock().expect("geny-memory poison");
        let n = st.memory.len();
        st.memory = crate::memory::LongTermMemory::new();
        #[cfg(feature = "semantic")]
        st.index.clear();
        n as u32
    }

    /// Número de fatos armazenados.
    pub fn count(&self) -> u32 {
        self.state.lock().expect("geny-memory poison").memory.len() as u32
    }

    /// Recupera um fato pela chave (null quando ausente).
    pub fn recall(&self, key: String) -> Option<MemoryRecord> {
        let st = self.state.lock().expect("geny-memory poison");
        st.memory.recall(&key).map(|f| MemoryRecord {
            key: f.key.clone(),
            value: f.value.clone(),
            tags: f.tags.clone(),
            updated_at_ms: f.updated_at_ms,
        })
    }

    /// Todos os fatos, ordenados pela chave.
    pub fn list(&self) -> Vec<MemoryRecord> {
        let st = self.state.lock().expect("geny-memory poison");
        st.memory
            .all()
            .iter()
            .map(|f| MemoryRecord {
                key: f.key.clone(),
                value: f.value.clone(),
                tags: f.tags.clone(),
                updated_at_ms: f.updated_at_ms,
            })
            .collect()
    }

    /// Busca por substring (fallback determinístico, sempre disponível).
    pub fn search_substring(&self, query: String) -> Vec<MemoryRecord> {
        let st = self.state.lock().expect("geny-memory poison");
        st.memory
            .search(&query)
            .into_iter()
            .map(|f| MemoryRecord {
                key: f.key.clone(),
                value: f.value.clone(),
                tags: f.tags.clone(),
                updated_at_ms: f.updated_at_ms,
            })
            .collect()
    }

    /// Busca semântica top-k (cosseno); sem a feature `semantic` cai para
    /// substring com score 0 — o chamador nunca quebra.
    pub fn search_semantic(&self, query: String, k: u32) -> Vec<MemoryHit> {
        #[cfg(feature = "semantic")]
        {
            let st = self.state.lock().expect("geny-memory poison");
            let embedder = crate::embed::HashingEmbedder;
            st.index
                .search(&embedder, &query, k.max(1) as usize, 0.0)
                .into_iter()
                .filter_map(|hit| {
                    st.memory.recall(&hit.key).map(|f| MemoryHit {
                        key: f.key.clone(),
                        value: f.value.clone(),
                        tags: f.tags.clone(),
                        updated_at_ms: f.updated_at_ms,
                        score: hit.score as f64,
                    })
                })
                .collect()
        }
        #[cfg(not(feature = "semantic"))]
        {
            self.search_substring(query)
                .into_iter()
                .take(k.max(1) as usize)
                .map(|r| MemoryHit {
                    key: r.key,
                    value: r.value,
                    tags: r.tags,
                    updated_at_ms: r.updated_at_ms,
                    score: 0.0,
                })
                .collect()
        }
    }

    /// Exporta a memória como envelope JSON versionado (v1).
    pub fn export_json(&self) -> String {
        let st = self.state.lock().expect("geny-memory poison");
        st.memory
            .to_envelope_json(&st.retention, crate::session::now_ms())
    }

    /// Importa um envelope JSON v1 (ou o array legado v0). Substitui o
    /// estado atual e reconstrói o índice semântico.
    pub fn import_json(&self, json: String) -> Result<(), MemoryError> {
        let memory = crate::memory::LongTermMemory::from_envelope_json(&json)
            .map_err(|e| MemoryError::InvalidEnvelope { msg: e.to_string() })?;
        let mut st = self.state.lock().expect("geny-memory poison");
        st.memory = memory;
        #[cfg(feature = "semantic")]
        {
            let MemoryState { memory, index, .. } = &mut *st;
            index.rebuild(
                &crate::embed::HashingEmbedder,
                memory
                    .all()
                    .iter()
                    .map(|f| (f.key.clone(), format!("{} {}", f.key, f.value))),
            );
        }
        Ok(())
    }

    /// Define a política de retenção (0 = sem limite naquela dimensão).
    pub fn set_retention(&self, max_facts: u32, max_age_days: u64, max_value_bytes: u64) {
        let opt = |v: u64| if v == 0 { None } else { Some(v) };
        let mut st = self.state.lock().expect("geny-memory poison");
        st.retention = crate::retention::RetentionPolicy {
            max_facts: opt(max_facts as u64).map(|v| v as u32),
            max_age_days: opt(max_age_days),
            max_value_bytes: opt(max_value_bytes),
        };
    }

    /// Política atual como JSON (para a UI de configuração).
    pub fn retention_json(&self) -> String {
        let st = self.state.lock().expect("geny-memory poison");
        serde_json::to_string(&st.retention).unwrap_or_else(|_| {
            "{\"max_facts\":null,\"max_age_days\":null,\"max_value_bytes\":null}".to_string()
        })
    }

    /// Aplica a retenção agora; retorna as chaves esquecidas.
    pub fn apply_retention(&self) -> Vec<String> {
        let mut st = self.state.lock().expect("geny-memory poison");
        let forgotten = {
            let MemoryState {
                memory, retention, ..
            } = &mut *st;
            retention.apply(memory, crate::session::now_ms())
        };
        #[cfg(feature = "semantic")]
        for k in &forgotten {
            st.index.remove(k);
        }
        forgotten
    }
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

    #[test]
    fn prompt_com_memoria_via_uniffi() {
        let p = build_system_prompt_with_memory(
            "pt-BR".into(),
            "[]".into(),
            true,
            vec!["wifi = Rede5G".into()],
        );
        assert!(p.contains("Fatos relevantes"));
        assert!(p.contains("- wifi = Rede5G"));
    }

    #[test]
    fn memoria_lifecycle_completo() {
        let mem = GenyMemory::new();
        assert_eq!(mem.count(), 0);

        // remember + count + recall.
        let esquecidas = mem.remember("wifi".into(), "Rede5G senha 123".into(), vec![]);
        assert!(esquecidas.is_empty());
        mem.remember("niver".into(), "10/03".into(), vec!["datas".into()]);
        assert_eq!(mem.count(), 2);
        let rec = mem.recall("wifi".into()).unwrap();
        assert_eq!(rec.value, "Rede5G senha 123");

        // Busca semântica acha o tema certo primeiro.
        let hits = mem.search_semantic("qual a senha do wifi?".into(), 2);
        assert!(!hits.is_empty());
        assert_eq!(hits[0].key, "wifi");
        assert!(hits[0].score > 0.0);

        // Busca substring como fallback.
        assert_eq!(mem.search_substring("niver".into()).len(), 1);

        // Retenção: limite 1 apaga o mais antigo.
        mem.set_retention(1, 0, 0);
        let esquecidas = mem.apply_retention();
        assert_eq!(esquecidas.len(), 1);
        assert_eq!(mem.count(), 1);

        // Export/import roundtrip.
        let json = mem.export_json();
        let outro = GenyMemory::new();
        outro.import_json(json.clone()).unwrap();
        assert_eq!(outro.count(), 1);
        assert!(outro.retention_json().contains("max_facts"));

        // Import inválido → erro tipado.
        assert!(outro.import_json("{quebrado".into()).is_err());

        // Forget e clear.
        assert!(outro.forget("wifi".into()));
        assert!(!outro.forget("wifi".into()));
        let outro2 = GenyMemory::new();
        outro2.import_json(json).unwrap();
        assert_eq!(outro2.clear(), 1);
        assert_eq!(outro2.count(), 0);
    }
}
