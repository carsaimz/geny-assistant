# Changelog

Todas as mudanças notáveis deste projeto são documentadas aqui.
Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
versionamento [Semântico](https://semver.org/lang/pt-BR/).

## [0.1.0-alpha.1] — Fase 1: Fundação

### Adicionado / Added

- **Monorepo** com camadas separadas: `app/` (TypeScript), `android/` (Kotlin),
  `core/` (Rust), `tools/` (Lua), `scripts/`, `docs/`, `.github/`.
- **Núcleo Rust (`geny-core`)**: orquestrador com tool calling, registro e
  validação estrita de ferramentas, política de confirmação humana em 4 níveis
  (none/simple/explicit/authenticated), memória de longo prazo com
  exportação/importação JSON, i18n com 10 idiomas e suporte RTL, seleção
  dinâmica de backend (local/remoto/self-hosted). 37 testes unitários.
- **App web (TypeScript + Vite + Capacitor)**: chat com roteador de intenções
  offline (local-first), backend remoto compatível com OpenAI com injeção de
  catálogo de ferramentas, ponte `GenyBridge` com mock web, confirmação
  humana para ações sensíveis, i18n em 11 locales (pt-BR, pt-PT, en, es, fr,
  de, it, ru, zh-CN, ja, ar) com direção RTL, tema escuro/claro e
  acessibilidade. 12 testes.
- **Android (Kotlin)**: plugin Capacitor `GenyBridge` com 18 ferramentas
  (apps, dispositivo, comunicação, notificações, notas, localização,
  lembretes), confirmação nativa fail-safe com aprovação de uso único,
  `KeystoreManager` AES-256-GCM, `AuditLog` rotativo local, serviço em
  primeiro plano, overlay HUD arrastável, `NotificationListenerService`,
  `ModelManager` (download com SHA-256), `RemoteBackend` OpenAI-compat e
  `BackendSelector`. Persistência SQLite v0. 14 testes JVM.
- **Ferramentas Lua do usuário**: formato de manifesto com esquema de
  parâmetros e 3 exemplos (incluindo ferramenta root `authenticated`).
- **Scripts**: `bootstrap.sh`, `build-rust-android.sh`, `sync-web.sh`,
  `download-model.sh` (SHA-256), `setup-submodules.sh`.
- **CI/CD (GitHub Actions)**: `lint` (tsc/eslint/clippy/rustfmt/gradle
  lint/luacheck), `test` (vitest/cargo/gradle), `build-native` (Rust para
  arm64-v8a, armeabi-v7a, x86_64 via NDK r27), `build-apk` (web → assets →
  APK debug com artefato), `release` (tags v*, fallback alpha) e dependabot.
- **Documentação**: especificação técnica completa v1.0, guias de arquitetura,
  build, segurança e tool calling, docs de usuário (início e privacidade),
  templates de issue/PR, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY.

### Decisões / Decisions

- Licença **Apache-2.0** (permissiva com concessão de patentes; compatível
  com as dependências MIT do ecossistema llama.cpp/whisper.cpp/Piper/ONNX).
- Persistência v0 com `SQLiteOpenHelper` — migração para Room + KSP fica
  para a Fase 3 (`android-04`) para manter o build alpha simples.
- Sem submodules clonados por padrão — `scripts/setup-submodules.sh` baixa
  sob demanda com versões pinadas (build determinista).
