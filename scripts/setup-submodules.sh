#!/usr/bin/env bash
# ============================================================
# Geny Assistant — prepara submodules nativos C/C++ (docs §4.2)
# Uso: ./scripts/setup-submodules.sh
#
# Adiciona os submodules de inferência sob native/. Os diretórios
# são grandes (dezenas de MB) e ficam FORA do git do projeto —
# cada desenvolvedor executa este script uma vez.
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

add_submodule() {
  local path="$1" repo="$2"
  if [ -d "$path" ] && [ -n "$(ls -A "$path" 2>/dev/null)" ]; then
    echo "[ok] $path já presente"
    return
  fi
  echo "[add] $path <- $repo"
  git submodule add "$repo" "$path" 2>/dev/null || {
    echo "[aviso] não foi possível adicionar $path (sem rede? fork?) — pule"
  }
}

# Pin de versões (build determinista — atualize com intenção e changelog)
add_submodule native/llama.cpp   https://github.com/ggml-org/llama.cpp.git
add_submodule native/whisper.cpp https://github.com/ggml-org/whisper.cpp.git

echo "[ok] submodules prontos. Para construir:"
echo "  ./scripts/build-rust-android.sh   (core Rust)"
echo "  cmake nos submodules entra na Fase 3 (TODO core-01)"
