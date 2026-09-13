# Geny Assistant

**PT** — Assistente virtual on-device para Android. Local-first, código aberto, com controle do dispositivo (com e sem root). Nenhum dado sai do seu telefone sem ação explícita sua. Sem telemetria, sem anúncios, sem nuvem obrigatória.

**EN** — On-device virtual assistant for Android. Local-first, open source, with device control (root and non-root). No data leaves your phone without your explicit action. No telemetry, no ads, no mandatory cloud.

[![CI](https://github.com/carsaimz/geny-assistant/actions/workflows/lint.yml/badge.svg)](./.github/workflows/lint.yml)
[![Tests](https://github.com/carsaimz/geny-assistant/actions/workflows/test.yml/badge.svg)](./.github/workflows/test.yml)
[![APK](https://github.com/carsaimz/geny-assistant/actions/workflows/build-apk.yml/badge.svg)](./.github/workflows/build-apk.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
![Platform](https://img.shields.io/badge/platform-Android%2026%2B-green)
![Status](https://img.shields.io/badge/status-alpha--Fase%201-orange)

---

## Por quê o Geny? / Why Geny?

| | Geny Assistant | Assistentes típicos |
|---|---|---|
| **Inferência de IA** | No dispositivo (GGUF/llama.cpp) ou seu próprio servidor | Nuvem obrigatória |
| **Controle do dispositivo** | Ferramentas auditáveis com confirmação humana | Limitado/fechado |
| **Root** | Opcional, desligado por padrão, confirmado ação por ação | Não suportado |
| **Privacidade** | Local-first, zero telemetria | Telemetria constante |
| **Idiomas** | Multilíngue por design (10 idiomas na Fase 1) | Tradução posterior |
| **Extensibilidade** | Ferramentas Lua em sandbox + tool calling controlado | Plugins fechados |

## Arquitetura / Architecture

```
┌───────────────────────────────────────────────────────────┐
│  Apresentação: app/ (TypeScript + Capacitor + HUD)        │
├───────────────────────────────────────────────────────────┤
│  Ponte nativa: android/ (Kotlin)  ← GenyBridge plugin →   │
│   · 18 ferramentas · confirmação · Keystore · auditoria   │
├───────────────────────────────────────────────────────────┤
│  Núcleo: core/ (Rust)                                     │
│   · orquestração · tool calling · memória · i18n          │
├───────────────────────────────────────────────────────────┤
│  Inferência: llama.cpp · whisper.cpp · Piper · ONNX (F2-3)│
│  Usuário: tools/ (Lua sandbox) · APIs remotas · root opt  │
└───────────────────────────────────────────────────────────┘
```

Detalhes completos: [`docs/TECHNICAL_SPEC.md`](docs/TECHNICAL_SPEC.md) · [`docs/architecture.md`](docs/architecture.md)

## Estrutura do repositório / Repository layout

```
geny-assistant/
├── app/        → app web TypeScript (Vite + Capacitor) — chat, i18n, bridge
├── android/    → projeto Android Kotlin (Gradle) — ferramentas, segurança, serviços
├── core/       → núcleo Rust — orquestração, tool calling, confirmação, memória
├── native/     → submodules C/C++ (llama.cpp, whisper.cpp) — scripts/setup-submodules.sh
├── tools/      → ferramentas do usuário em Lua (sandbox)
├── models/     → modelos baixados (NUNCA versionados)
├── scripts/    → bootstrap, build nativo, sync web, download de modelos
├── docs/       → especificação técnica + guias
└── .github/    → CI/CD (lint, test, native, apk, release)
```

## Começando / Getting started (dev)

**Requisitos:** Node ≥ 20 · Rust ≥ 1.75 · JDK ≥ 17 · Android SDK + NDK r27

```bash
git clone https://github.com/carsaimz/geny-assistant.git
cd geny-assistant
./scripts/bootstrap.sh            # valida tudo e roda os primeiros testes

# 1) App web no navegador (mock nativo — sem dispositivo)
cd app && npm run dev             # http://localhost:5173

# 2) Testes por camada
cd core && cargo test
cd app  && npm test
cd android && gradle :app:testDebugUnitTest

# 3) APK debug
./scripts/sync-web.sh
cd android && gradle :app:assembleDebug
```

Guia completo: [`docs/build.md`](docs/build.md) · Modelos: [`scripts/download-model.sh`](scripts/download-model.sh)

## Status — Fase 3 (LLM local) 🚧 / Phase 3 (Local LLM) 🚧

- ✅ Fase 1: monorepo + CI/CD (5 workflows) + núcleo Rust (**43 testes**) + app web
  (**22 testes**) + Android (ponte com 18 ferramentas, confirmação fail-safe,
  Keystore, auditoria, serviços) — **15 testes JVM**
- 🎙️ **Fase 2 (v0.2.0-alpha.1)**: conversa por voz com captura em
  contexto, STT dupla on-device (sistema + whisper.cpp via NDK com modelos
  GGML sob demanda SHA-256), VAD (energia + Silero ONNX) e TTS em serviço
  foreground — guia em [`docs/user/voice.md`](docs/user/voice.md)
- 🦙 **Fase 3 em andamento (v0.3.0-alpha.1)**: **LLM 100% local** — llama.cpp
  v0.4.0 compilado no app (`:llama-native`, arm64-v8a/x86_64), catálogo GGUF
  (Qwen2.5 0.5B/1.5B, Llama 3.2 1B, Gemma 2 2B — Q4_K_M) com SHA-256 pinado e
  download sob demanda, guarda de RAM, seção Modelo local nas configurações e
  chat com backend local — guia em [`docs/user/models.md`](docs/user/models.md)
- ⏳ Próxima: tela nativa de modelos + Piper + wake word + UniFFI → ver [`ROADMAP.md`](ROADMAP.md)

> **Nota de build**: o APK compila whisper.cpp **e** llama.cpp — o CI faz
> checkout de submodules e instala NDK r27.2 + CMake 3.22.1. Local:
> `git submodule update --init` + SDK com os mesmos componentes
> (docs/build.md).
>
> *Build note: the APK compiles both whisper.cpp **and** llama.cpp — CI
> checks out submodules and installs NDK + CMake. Locally run
> `git submodule update --init` + the SDK with the same components.*

## Segurança e privacidade / Security & privacy

- 🔒 Nenhum dado sai do dispositivo sem ação explícita (local-first).
- 🔒 Sem telemetria, analytics ou anúncios — auditável no código.
- 🔒 Chaves de API no Android Keystore (AES-256-GCM), excluídas de backup.
- 🔒 Ações sensíveis exigem confirmação humana (none → simple → explicit → authenticated).
- 🔒 Ferramentas executam apenas o que está registrado e validado — o modelo não inventa comandos.
- 🐛 Reporte vulnerabilidades em privado: [`SECURITY.md`](SECURITY.md).

## Contribuir / Contributing

Leia [`CONTRIBUTING.md`](CONTRIBUTING.md) e [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
Commits seguem **conventional commits bilingues**: `feat(core): descrição em pt / en description`.
Toda nova ideia vai direto para [`ROADMAP.md`](ROADMAP.md) → [`TODO.md`](TODO.md) → issues.

## Licença / License

[Apache-2.0](./LICENSE) — compatível com llama.cpp, whisper.cpp, Piper e ONNX Runtime (todos MIT).
