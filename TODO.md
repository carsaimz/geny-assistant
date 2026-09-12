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

## 🚧 Fase 2 — Voz / Voice (em andamento)

- [ ] `android-01` Captura de áudio com gravação em contexto e permissão RECORD_AUDIO
- [ ] `core-01` VAD Silero via ONNX Runtime no core (feature `vad`)
- [ ] `core-02` Bindings whisper.cpp (STT) — modelos tiny/base/small/medium
- [ ] `core-03` Bindings Piper (TTS) — vozes pt-BR, pt-PT e en primeiro
- [ ] `app-01` UI apertar-para-falar no chat + exibição de transcrição
- [ ] `android-02` Reprodução de áudio TTS em segundo plano via serviço
- [ ] `ci-01` Cache de build whisper/piper no CI
- [ ] `docs-01` docs/user/voice.md (configurar vozes e wake word)

## Fase 3 — LLM local (próximas)

- [ ] `core-04` UniFFI: bindings geny-core ↔ Kotlin (`feature = "uniffi"`)
- [ ] `core-05` Integração llama.cpp no core (sessão de inferência GGUF)
- [ ] `android-03` Tela Modelos: download com progresso, hash, remoção, espaço
- [ ] `android-04` Migração do GenyDb para Room + KSP
- [ ] `app-02` Tela Modelos no web (espelha a nativa)
- [ ] `ci-02` Job de matriz de build nativo com artefatos por ABI

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
