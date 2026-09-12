#!/usr/bin/env bash
# ============================================================
# Geny Assistant — bootstrap do ambiente de desenvolvimento
# Uso: ./scripts/bootstrap.sh
# Verifica e orienta a instalação de TODAS as toolchains do monorepo.
# ============================================================
set -euo pipefail

BOLD="\033[1m"; GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; RESET="\033[0m"
ok()   { echo -e "${GREEN}[ok]${RESET} $1"; }
warn() { echo -e "${YELLOW}[faltando]${RESET} $1"; }
fail() { echo -e "${RED}[erro]${RESET} $1"; exit 1; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BOLD}Geny Assistant — bootstrap${RESET}"

# --- Node.js >= 20 (app web) -------------------------------------------
if command -v node >/dev/null && [ "$(node -e 'console.log(parseInt(process.versions.node))')" -ge 20 ]; then
  ok "node $(node --version)"
else
  warn "node >= 20 (https://nodejs.org) — necessário para app/"
fi

# --- Rust >= 1.75 (core) ------------------------------------------------
if command -v cargo >/dev/null; then
  ok "cargo $(cargo --version | awk '{print $2}')"
else
  warn "rustup (https://rustup.rs) — necessário para core/"
fi

# --- Java >= 17 (android) ----------------------------------------------
if command -v java >/dev/null && [ "$(java -version 2>&1 | head -1 | sed -E 's/.*"([0-9]+).*/\1/')" -ge 17 ]; then
  ok "java $(java -version 2>&1 | head -1)"
else
  warn "JDK >= 17 (temurin) — necessário para android/"
fi

# --- Android SDK --------------------------------------------------------
if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME" ]; then
  ok "ANDROID_HOME=$ANDROID_HOME"
else
  warn "ANDROID_HOME não definido — instale o Android SDK + NDK r27"
fi

# --- Dependências e builds ----------------------------------------------
cd "$ROOT"

if command -v npm >/dev/null; then
  echo -e "${BOLD}app/: npm install${RESET}"
  (cd app && npm install --no-fund --no-audit) && ok "app dependências"
fi

if command -v cargo >/dev/null; then
  echo -e "${BOLD}core/: cargo test${RESET}"
  (cd core && cargo test --quiet) && ok "core testado"
fi

echo -e "${BOLD}Próximos passos${RESET}
  1. app:      npm run dev          (web em http://localhost:5173)
  2. web→apk:  ./scripts/sync-web.sh && cd android && gradle :app:assembleDebug
  3. rust→so:  ./scripts/build-rust-android.sh
  4. modelos:  ./scripts/download-model.sh --help
"
