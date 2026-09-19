# TODO — Geny Assistant

> **PT** Checklist operacional derivado do [ROADMAP.md](ROADMAP.md). IDs tipo
> `core-03` referenciam issues no GitHub. Marque com `x` ao concluir; novas
> tarefas entram com o próximo ID livre da camada.
> **EN** Operational checklist derived from ROADMAP.md; IDs map to GitHub issues.

## ✅ Concluído / Done (Fase 1)

- [x] Monorepo + licença Apache-2.0 + gitignore + editorconfig
- [x] `docs/TECHNICAL_SPEC.md` v1.0 completa
- [x] `core/`: sessão, ferramentas, validação, confirmação, memória, i18n, backends (37 testes)
- [x] `app/`: chat, intenções offline, remoto OpenAI-compat, 11 locales, RTL (12 testes)
- [x] `android/`: GenyBridge com 18 ferramentas, confirmação, Keystore, auditoria, serviços (14 testes)
- [x] `tools/`: formato Lua + 3 exemplos (incl. root autenticado)
- [x] `scripts/`: bootstrap, build-rust-android, sync-web, download-model, setup-submodules
- [x] CI/CD: lint + test + build-native + build-apk + release + dependabot

## 🚧 Fase 2 — Voz / Voice (núcleo entregue em v0.2.0-alpha.1)

- [x] `android-01` Captura de áudio com gravação em contexto e permissão RECORD_AUDIO (#1)
- [x] `core-01` VAD: energia RMS no core (feature `vad`, 6 testes) + Silero v5 ONNX no Android com fallback (#29)
- [x] `core-02` Bindings whisper.cpp (JNI + CMake + submodule v1.7.4) — modelos tiny/base/small/medium sob demanda (#2)
- [x] `android-02` TTS em segundo plano via serviço foreground (TextToSpeech on-device) (#30)
- [x] `app-01` UI apertar-para-falar no chat + transcrição ao vivo + responder por voz (#4)
- [x] `app-03` Tela de conversa por voz em tela cheia (orb animado, modo mãos-livres via `genyTts`) + correção do crash ao tocar no microfone (SpeechRecognizer protegido) (v0.3.0-alpha.3)
- [x] `ci-01` Cache de build nativo no CI + NDK/CMake/submodules nos 4 workflows (#5)
- [x] `docs-01` docs/user/voice.md (vozes, STT, VAD, TTS) (#31)

## 🚧 Fase 3 — LLM local (núcleo entregue em v0.3.0-alpha.1)

- [x] `core-05` llama.cpp no app: submodule pinado @ v0.4.0, módulo `:llama-native` (CMake isolado), JNI geny_llama_jni, catálogo GGUF com SHA-256 pinado, guarda de RAM (#32)
- [x] `app-02` Seção Modelo local nas configurações web: download com progresso, carregar/descarregar, remoção, disco; chat com backend local + fallback (#33)
- [x] `ci-02` Matriz de build C++ por ABI (arm64-v8a/x86_64) com artefatos dos JNI (#34)
- [x] `core-03` TTS neural via Piper (pt-BR Faber, pt-PT Tugão, en-US Amy): espeak-ng submodule pinado + VITS via ONNX Runtime existente, download sob demanda com SHA-256, fallback para TTS do sistema (#3, v0.3.0-alpha.4)
- [x] `core-05b` Streaming de tokens na ponte (`llmToken` + botão Parar) + temperatura/seed na UI (v0.3.0-alpha.4)
- [x] `android-03` Tela nativa de Modelos com progresso, hash e espaço (#35, v0.3.0-alpha.6)
- [x] `android-03b` Wake word opcional desligado por padrão — openWakeWord/ONNX (modelos v0.5.1 com SHA-256 pinado, serviço de primeiro plano, canal `genyWake`) (#37)
- [x] `core-04` UniFFI: bindings geny-core ↔ Kotlin — `libgeny_core.so` (3 ABIs no CI) + Kotlin gerado versionado, `CoreBridge` com fallback gracioso, prompt de sistema do Rust no nativo (#38)
- [x] `android-04` Migração do GenyDb para Room + KSP (#36)
- [x] Prompt de sistema por idioma/cultura (do core i18n) — `buildSystemPrompt` no app espelha `i18n.rs` e serve os backends remoto e local (v0.3.0-alpha.4)
- [x] Seleção automática local/remoto conforme bateria, rede e tarefa — modo `auto` com `pickBackend` puro (bateria >15%, rede, poupança); padrão novo (v0.3.0-alpha.5)

## Fase 4 — Ferramentas avançadas

- [x] `core-06` Follow-up de 2ª passagem: resultado da ferramenta volta ao modelo (remoto e local, sem loops; v0.3.0-alpha.5)
- [x] `android-05` SAF: pastas autorizadas com permissão persistida — criar/ler/editar/append/excluir/mkdir dentro do escopo, métodos `saf*` na ponte, guard de pasta autorizada e auditoria (#40, v0.3.0-alpha.9)
- [x] `android-06` OCR local (ML Kit v2 bundle Latin, 100% on-device, sem Play Services) — tool `ocr.read` (nível simple) com envelope de códigos estáveis e `ocrRead` na ponte (#41, v0.3.0-alpha.10)
- [x] `core-07` Sandbox mlua executando ferramentas `tools/` com API `geny.*` — Lua 5.4 segura (sem io/require/os.execute), teto de memória, orçamento de instruções, host injetável (toast/storage/device/root opt-in) e 25 testes (#42, v0.3.0-alpha.8)
- [x] `android-07` Responder notificações (RemoteInput) via listener — tool `notifications.reply` (nível explicit), `NotificationReplier` com remoteInputs + androidx addResultsToIntent, testes Robolectric (#43, v0.3.0-alpha.9)
- [x] `app-03` Catálogo de ferramentas na UI com níveis de confirmação visíveis — seção nas configurações com selo por nível (4 cores) e contagem, 6 chaves × 11 locales (#44, v0.3.0-alpha.9)

## Fase 5 — Memória

- [x] `core-08` Memória semântica: índice vetorial + embeddings locais no core (feature `semantic`) — `HashingEmbedder` multilíngue determinístico (n-gramas 1–3, 256d), `SemanticIndex` top-k cosseno, `GenyMemory` (UniFFI) e recall no prompt de sistema em 11 idiomas (#45, v0.3.0-alpha.11)
- [x] `android-08` UI de fatos aprendidos (ver/editar/apagar) — `MemoryActivity` nativa com busca semântica (fallback substring) e 9 métodos `memory*` na ponte (#46, v0.3.0-alpha.11)
- [x] `core-09` Política de retenção (exclusão automática + export/import) — `RetentionPolicy` aplicada a cada escrita + envelope v1 compartilhado com o backup; espelho Kotlin JVM-testável (#47, v0.3.0-alpha.11)
- [x] `app-04` Backup cifrado de configuração (sem nuvem) — arquivo `GENYBAK1` (PBKDF2 210k + AES-256-GCM) via SAF, seção Backup nas configurações web (#48, v0.3.0-alpha.11)

## Fase 6 — APIs remotas

- [x] `app-05` Streaming SSE no modo remoto — `remoteStream`/`consumeSseStream` com `stream:true`, abort pelo botão Parar, timeout de inatividade 60 s e a mesma bolha progressiva do LLM local (#49, v0.3.0-alpha.12)
- [x] `core-10` Interface de provedor comum + perfis de operação — `providers.rs` com catálogo `ProviderSpec` (gratuito/free-tier/premium/self-hosted), `OperationProfile` (`offline-total`/`hybrid`/`home-server`) com regras puras, exports UniFFI, espelho TS e seção Provedor/Perfil nas configurações (#50, v0.3.0-alpha.12)
- [x] `android-09` Gerenciador de chaves por provedor (Keystore) — `providerKeySet/Get/Clear/List` na ponte, AES-256-GCM via KeystoreManager, `ProviderKeys` JVM-testável, presets na UI e migração da chave legada (#51, v0.3.0-alpha.12)

## Fase 7 — Root

- [ ] `android-10` Módulo root opt-in (Magisk/KernelSU/APatch) com escopo
- [ ] `android-11` Ferramentas privilegiadas + BiometricPrompt no nível authenticated
- [ ] `android-12` Auditoria root separada e exportável

## Fase 8 — Dispositivos externos

- [ ] `core-11` Cliente MQTT
- [ ] `core-12` Conector Home Assistant
- [ ] `android-13` Bluetooth LE e wearables

## Fase 9 e 10

- [ ] `i18n-01` Revisão nativa dos 10 idiomas principais
- [ ] `i18n-02` Idiomas adicionais + PT de Moçambique/Angola
- [ ] `qa-01` Matriz de testes instrumentados (com/sem root)
- [ ] `qa-02` Cobertura mínima por camada no CI
- [ ] `docs-02` docs/user/ completa + site simples

## 💡 Backlog de ideias

- [ ] Motor de automações "se-isto-então-aquilo" sem código
- [ ] Loja comunitária de ferramentas Lua com revisão
- [ ] Modo kiosk/off-grid para aparelhos antigos
- [ ] Modo multilíngue por conversa
- [ ] Integração Termux:API (sem root)
- [ ] API local (webhook localhost) para integrações

---

**Regras de evolução / evolution rules**
1. Nova ideia? adicione no backlog acima **e** no ROADMAP (seção 💡) no mesmo commit.
2. Ao começar uma tarefa, abra issue com o ID e referencie no commit: `feat(core): ... (#core-02)`.
3. Só inicie a fase seguinte quando a atual estiver 100% marcada.
