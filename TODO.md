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
- [x] `ci-01` Cache de build nativo no CI + NDK/CMake/submodules nos 4 workflows (#5)
- [x] `docs-01` docs/user/voice.md (vozes, STT, VAD, TTS) (#31)
- [ ] `core-03` TTS neural via Piper — movido para a Fase 3 (lote nativo junto com llama.cpp) (#3)

## 🚧 Fase 3 — LLM local (núcleo entregue em v0.3.0-alpha.1)

- [x] `core-05` llama.cpp no app: submodule pinado @ v0.4.0, módulo `:llama-native` (CMake isolado), JNI geny_llama_jni, catálogo GGUF com SHA-256 pinado, guarda de RAM (#32)
- [x] `app-02` Seção Modelo local nas configurações web: download com progresso, carregar/descarregar, remoção, disco; chat com backend local + fallback (#33)
- [x] `ci-02` Matriz de build C++ por ABI (arm64-v8a/x86_64) com artefatos dos JNI (#34)
- [ ] `android-03` Tela nativa de Modelos com progresso, hash, remoção, espaço (#35)
- [ ] `core-03` TTS neural via Piper (vozes pt-BR, pt-PT, en) (#3, herdado da Fase 2)
- [ ] `android-03b` Wake word opcional desligado por padrão (openWakeWord/ONNX)
- [ ] `core-04` UniFFI: bindings geny-core ↔ Kotlin (`feature = "uniffi"`)
- [ ] `android-04` Migração do GenyDb para Room + KSP
- [ ] `core-05b` Streaming de tokens na ponte + temperatura/seed na UI

## Fase 4 — Ferramentas avançadas

- [ ] `core-06` Follow-up de 2ª passagem: resultado da ferramenta volta ao modelo
- [ ] `android-05` SAF: pastas autorizadas, criar/ler/editar/excluir
- [ ] `android-06` OCR local (ML Kit) em imagens e screenshots
- [ ] `core-07` Sandbox mlua executando ferramentas `tools/` com API `geny.*`
- [ ] `android-07` Responder notificações (RemoteInput) via listener
- [ ] `app-03` Catálogo de ferramentas na UI com níveis de confirmação visíveis

## Fase 5 — Memória

- [ ] `core-08` sqlite-vec + embeddings ONNX no core (feature `semantic`)
- [ ] `android-08` UI de fatos aprendidos (ver/editar/apagar)
- [ ] `core-09` Política de retenção (exclusão automática + export/import)
- [ ] `app-04` Backup cifrado de configuração (sem nuvem)

## Fase 6 — APIs remotas

- [ ] `app-05` Streaming SSE no modo remoto
- [ ] `core-10` Interface de provedor comum + perfis de operação
- [ ] `android-09` Gerenciador de chaves por provedor (Keystore)

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
