#!/usr/bin/env bash
# ============================================================
# Geny Assistant — build Rust para Android (JNI .so)
# Uso: ./scripts/build-rust-android.sh [release]
# Compila core/ para arm64-v8a, armeabi-v7a e x86_64 e copia
# os binários para android/app/src/main/jniLibs/.
# Requisitos: rustup, target android instalados, cargo-ndk, NDK.
# ============================================================
set -euo pipefail

PROFILE="debug"
if [ "${1:-}" = "release" ]; then PROFILE="release"; fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JNILIBS="$ROOT/android/app/src/main/jniLibs"

command -v cargo-ndk >/dev/null || {
  echo "[erro] cargo-ndk ausente — instale com: cargo install cargo-ndk"; exit 1;
}
[ -n "${ANDROID_HOME:-}" ] || [ -n "${ANDROID_NDK_HOME:-}" ] || {
  echo "[erro] defina ANDROID_HOME/ANDROID_NDK_HOME (NDK r27)"; exit 1;
}

# Targets fixados (build determinista — docs §2.8)
TARGETS=(
  "arm64-v8a:aarch64-linux-android"
  "armeabi-v7a:armv7-linux-androideabi"
  "x86_64:x86_64-linux-android"
)

for pair in "${TARGETS[@]}"; do
  abi="${pair%%:*}"
  triple="${pair##*:}"
  rustup target list --installed | grep -q "$triple" || rustup target add "$triple"
done

echo "[build] geny-core ($PROFILE) para 3 arquiteturas..."
cd "$ROOT/core"
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -o "$JNILIBS" build "--$PROFILE"

echo "[ok] .so copiados:"
find "$JNILIBS" -name "*.so" -type f | sed 's/^/  /'
