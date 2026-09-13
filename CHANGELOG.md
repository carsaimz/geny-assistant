# Changelog

Todas as mudanças notáveis deste projeto são documentadas aqui.
Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
versionamento [Semântico](https://semver.org/lang/pt-BR/).

## [0.1.0-alpha.2] — Correção do ecrã preto / Black-screen fix

### Corrigido / Fixed

- **Ecra preto ao abrir (crítico)**: o `#settings-drawer` tinha o atributo
  `hidden` no HTML, mas `display: flex` no CSS sobrepunha o `display: none`
  da folha de estilos do navegador — a gaveta vazia (380px, fundo escuro,
  `position: fixed`) cobria 92% do ecrã desde o arranque. Correção: regra
  global `[hidden] { display: none !important; }` + guarda de regressão.
  *Black screen on launch (critical): the settings drawer's `hidden`
  attribute was overridden by the author `display: flex` rule — an empty
  dark fixed panel covered the screen on startup. Fixed with a global
  `[hidden] { display: none !important; }` rule + regression guard.*
- **Chave i18n ausente**: `chat.placeholder` era usada no código mas não
  existia em nenhum locale — o campo de mensagem mostrava a chave crua.
  Adicionada nos 11 idiomas + testes de integridade (todos os locales com
  conjuntos de chaves idênticos; toda chave usada em código existe).
  *Missing i18n key `chat.placeholder` added to all 11 locales with
  integrity tests.*
- **`captureInput: true` removido** do config Capacitor: instala uma
  `BaseInputConnection` falsa que degrada a digitação do teclado na WebView.
  *Removed `captureInput: true` (fake input connection breaks IME typing).*
- **`webContentsDebuggingEnabled` omitido**: o default do Capacitor
  (`ligado em builds debug, desligado em release`) é o correto — antes o
  `false` explícito impedia inspecionar o APK debug via `chrome://inspect`.
  *Omitted explicit flag; Capacitor default (debug-builds-only) restored.*
- **CI reparado após majors do dependabot**: bumps major meseados
  (TypeScript 7, AGP 9, Kotlin 2.4, material/appcompat 1.14/1.8) quebravam
  `npm ci` (typescript-eslint 8 sem suporte a TS 7) e exigiriam Gradle 9.
  Revertidos para a combinação comprovada (TS 5.9.3, AGP 8.7.3, Kotlin
  2.0.21, material 1.12, appcompat 1.7); minors seguros mantidos (Vite 8,
  globals 17, thiserror 2, coroutines 1.9). Dependabot passa a ignorar
  majors até a migração deliberada (ver ROADMAP). *CI repaired after merged
  dependabot majors; risky majors reverted, safe minors kept, dependabot
  now ignores majors until the planned migration.*

### Adicionado / Added

- **APK release assinado em CI**: segredos `KEYSTORE_BASE64`,
  `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` + `signingConfig`
  condicional no Gradle e verificação com `apksigner` no workflow Release.
  Com fallback declarado: sem segredos, publica-se o APK debug como
  instalável da alpha. *Signed release APK via CI secrets with apksigner
  verification and declared debug fallback.*
- **Testes de regressão de UI/i18n**: 3 novos testes (guarda `[hidden]`,
  paridade de chaves entre locales, existência de chaves usadas no código).
  15 testes no app (antes 12).

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
