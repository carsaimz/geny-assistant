# Build — guia de desenvolvimento / development guide

## Pré-requisitos / Prerequisites

| Ferramenta | Versão | Usado em |
|---|---|---|
| Node.js | ≥ 20 | `app/` |
| Rust (rustup) | ≥ 1.75 stable | `core/` |
| JDK | 17 (Temurin) | `android/` |
| Android SDK | API 35 | `android/` |
| Android NDK | r27 (r27c) | `core/` → `.so` |
| Gradle | 8.9 | `android/` |
| cargo-ndk | mais recente com `--locked` | `core/` → `.so` |

Atalho: `./scripts/bootstrap.sh` valida tudo e roda os primeiros testes.

## 1. App web (rápido, sem dispositivo)

```bash
cd app
npm install
npm run dev        # http://localhost:5173 — bridge em modo mock
npm test           # vitest (12 testes)
npm run build      # tsc --noEmit + vite build → dist/
```

No navegador a ponte nativa é substituída por um mock (`app/src/core/bridge.ts`)
com ferramentas simuladas — bom para desenvolver UI e fluxo de confirmação.

## 2. Núcleo Rust

```bash
cd core
cargo test                          # 37 testes
cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
```

## 3. Rust → bibliotecas Android (.so)

```bash
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
cargo install cargo-ndk --locked
export ANDROID_HOME=...            # e NDK r27 dentro dele
./scripts/build-rust-android.sh release
# → android/app/src/main/jniLibs/{arm64-v8a,armeabi-v7a,x86_64}/libgeny_core.so
```

## 4. APK Android

```bash
./scripts/sync-web.sh              # build web → assets do Capacitor
cd android
gradle :app:assembleDebug          # APK em app/build/outputs/apk/debug/
gradle :app:testDebugUnitTest      # 14 testes JVM
gradle :app:lintDebug
```

Requisito: `gradle.properties` já configura cache; o CI usa Gradle 8.9 fixado
(`gradle/actions/setup-gradle`). Sem wrapper no repositório nesta fase —
instale Gradle 8.9 ou use o CI como referência.

## 5. Submodules nativos (Fase 3)

```bash
./scripts/setup-submodules.sh      # clona llama.cpp e whisper.cpp pinados
```

## 6. Modelos de IA (nada vai para o git)

```bash
./scripts/download-model.sh <url> <destino> [sha256]
# exemplo STT whisper tiny (~75 MB):
./scripts/download-model.sh \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin \
  models/ggml-tiny.bin
```

## 7. Instalar no dispositivo

```bash
adb install android/app/build/outputs/apk/debug/app-debug.apk
```

O build `debug` usa o sufixo `.debug` no applicationId
(`com.carsaimz.genyassistant.debug`) e pode coexistir com o release.

## Problemas comuns / Troubleshooting

| Sintoma | Causa provável | Solução |
|---|---|---|
| `SDK location not found` | sem `local.properties` | crie com `sdk.dir=/caminho` |
| NDK ausente no cargo-ndk | `ANDROID_HOME` errado | exporte e confirme `ndk/27c` |
| WebView branca | assets não sincronizados | rode `scripts/sync-web.sh` |
| `lintDebug` falha no CI | recursos ausentes | rode local com `--stacktrace` |
