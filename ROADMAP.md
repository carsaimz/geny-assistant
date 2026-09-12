# ROADMAP — Geny Assistant

> **PT** Mapa de desenvolvimento em 10 fases + seção de novas ideias. Convenção:
> uma fase só é "em andamento" quando a anterior está ✅; novas ideias entram na
> seção [Novas ideias](#-novas-ideias--new-ideas) e são convertidas em issues.
> **EN** Development map in 10 phases + new-ideas section. New ideas go straight
> to the ideas section and become issues. Live checklist: [`TODO.md`](TODO.md).

- [x] **Fase 1 — Fundação / Foundation** *(concluída em v0.1.0-alpha.1)*
- [ ] **Fase 2 — Voz / Voice** ← em andamento
- [ ] Fase 3 — LLM local
- [ ] Fase 4 — Ferramentas avançadas / Advanced tools
- [ ] Fase 5 — Memória / Memory
- [ ] Fase 6 — APIs remotas / Remote APIs
- [ ] Fase 7 — Root
- [ ] Fase 8 — Dispositivos externos / External devices
- [ ] Fase 9 — Multilíngue completo / Full multilingual
- [ ] Fase 10 — Refinamento / Polish

---

## ✅ Fase 1 — Fundação / Foundation (v0.1.0-alpha.1)

- [x] Monorepo (`app/`, `android/`, `core/`, `tools/`, `native/`, `scripts/`, `docs/`)
- [x] CI/CD: lint, test, build-native, build-apk, release (5 workflows) + dependabot
- [x] App Capacitor com chat, histórico em sessão, roteador de intenções offline
- [x] Suporte multilíngue por design: 11 locales + RTL (árabe)
- [x] Ponte nativa `GenyBridge`: catálogo de 18 ferramentas, execução validada
- [x] Confirmação humana em 4 níveis (none/simple/explicit/authenticated), fail-safe
- [x] Segurança: Keystore AES-256-GCM, auditoria rotativa local, exclusão de backup
- [x] Serviço em primeiro plano + overlay HUD arrastável + notification listener
- [x] Núcleo Rust: sessão, registro/validação de ferramentas, memória, i18n, seleção de backend
- [x] Licença Apache-2.0 + documentação técnica completa (docs/TECHNICAL_SPEC.md)

## 🚧 Fase 2 — Voz / Voice

- [ ] Captura de áudio (RECORD_AUDIO em contexto) com VAD Silero (ONNX)
- [ ] STT local via whisper.cpp (tiny/base/small/medium, download sob demanda)
- [ ] TTS local via Piper (vozes pt-BR, pt-PT, en primeiro)
- [ ] Modo conversa por voz no chat (apertar-para-falar → ditado)
- [ ] Wake word opcional (ONNX / openWakeWord), desligado por padrão
- [ ] Métricas de latência voz→texto e texto→voz no log local

## Fase 3 — LLM local

- [ ] Submodules llama.cpp + whisper.cpp pinados (scripts/setup-submodules.sh)
- [ ] Bindings UniFFI Rust ↔ Kotlin do geny-core
- [ ] Inferência GGUF on-device (arm64-v8a primeiro, depois armeabi-v7a/x86_64)
- [ ] Gerenciador de modelos na UI: download, hash SHA-256, remoção, espaço
- [ ] Prompt de sistema por idioma/cultura (do core i18n) + janela de contexto
- [ ] Seleção automática local/remoto conforme bateria, rede e tarefa

## Fase 4 — Ferramentas avançadas / Advanced tools

- [ ] Tool calling completo com follow-up de 2ª passagem no núcleo Rust → Kotlin
- [ ] Ferramentas essenciais concluídas: SMS, contatos, notificações (responder)
- [ ] SAF: pastas autorizadas pelo usuário (criar/ler/editar/excluir)
- [ ] Câmera e galeria (captura de foto/vídeo via Intents)
- [ ] OCR local em imagens (ML Kit ou Tesseract on-device)
- [ ] Sandbox Lua (mlua) executando `tools/` com API `geny.*`
- [ ] Catálogo de ferramentas consultável na UI com níveis de confirmação visíveis

## Fase 5 — Memória / Memory

- [ ] Banco vetorial local (sqlite-vec ou equivalente)
- [ ] Embeddings locais via ONNX (MiniLM multilíngue)
- [ ] Memória de longo prazo na UI: fatos aprendidos, editáveis e apagáveis
- [ ] Política de retenção configurável (exclusão automática, exportação/importação)
- [ ] Memória semântica conectada ao prompt de sistema (recall antes de responder)

## Fase 6 — APIs remotas / Remote APIs

- [ ] Abstração de provedor com interface comum (gratuitas / free-tier / premium)
- [ ] Gerenciamento de chaves na UI (Keystore), por provedor
- [ ] Streaming de respostas (SSE) no modo remoto
- [ ] Seleção dinâmica refinada (complexidade da tarefa, custo estimado)
- [ ] Perfis de operação (ex.: "offline total", "híbrido", "servidor de casa")

## Fase 7 — Root

- [ ] Módulo de root opcional, desligado por padrão, com consentimento explícito
- [ ] Integração Magisk / KernelSU / APatch (detecção e shell com escopo)
- [ ] Ferramentas privilegiadas: processos, firewall, hardware, backup completo
- [ ] Nível `authenticated` com BiometricPrompt/credencial do dispositivo
- [ ] Auditoria dedicada de ações root (arquivo separado, exportável)

## Fase 8 — Dispositivos externos / External devices

- [ ] MQTT client para IoT
- [ ] Conector Home Assistant (REST/WebSocket)
- [ ] Bluetooth LE + wearables (notificações e comandos rápidos)
- [ ] Android Auto (mensagens e comandos de voz)
- [ ] Matter/Zigbee via hubs (opcional)

## Fase 9 — Multilíngue completo / Full multilingual

- [ ] Traduções 100% dos 10 idiomas principais (revisão nativa)
- [ ] Idiomas adicionais (hindi, coreano, turco, holandês, polonês…)
- [ ] Vozes Piper por idioma + detecção automática de idioma de entrada
- [ ] Prompts por cultura (formalidade, formatos de data/hora)

## Fase 10 — Refinamento / Polish

- [ ] Performance: benchmarks de inferência por dispositivo, modo econômico
- [ ] Acessibilidade: TalkTalk/TalkBack completo, alto contraste, navegação por teclado
- [ ] Testes instrumentados em matriz de dispositivos (com e sem root)
- [ ] Cobertura mínima por camada publicada no CI
- [ ] Documentação de usuário completa (docs/user/) + site simples

---

## 💡 Novas ideias / New ideas

> Ideias capturadas durante o desenvolvimento entram aqui primeiro; as aprovadas
> viram issues e migram para uma fase (ou criam a Fase 11).

- [ ] **Motor de automações sem código** (Fase 4/11): gatilhos (hora, bateria, rede, local) → ações; UI visual de "se isto então aquilo".
- [ ] **Loja comunitária de ferramentas Lua** (Fase 11): repositório indexado de ferramentas com revisão de código e permissões declaradas.
- [ ] **Modo kiosk/off-grid** (Fase 11): perfil ultra-econômico para aparelhos antigos como hub doméstico offline.
- [ ] **Backup/restauração de configuração** via arquivo cifrado (Fase 5) — trocar de celular sem nuvem.
- [ ] **Modo multilíngue por conversa** (Fase 9): trocar idioma no meio do chat e a Geny seguir.
- [ ] **Integração Termux:API** (Fase 4): automação avançada sem root para usuários avançados.
- [ ] **Webhook/HTTP local** (Fase 8): a Geny expõe API local para integrações (localhost apenas por padrão).
- [ ] **PT-POM (português de Moçambique/Angola)** (Fase 9): variante pt-PT com léxico local + voz.

---

*Histórico de fases concluídas fica registrado no [CHANGELOG.md](CHANGELOG.md).
Decisões de arquitetura: [docs/TECHNICAL_SPEC.md](docs/TECHNICAL_SPEC.md).*
