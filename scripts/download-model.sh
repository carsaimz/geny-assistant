#!/usr/bin/env bash
# ============================================================
# Geny Assistant — download de modelos de IA (docs §7.5)
# Uso:
#   ./scripts/download-model.sh <url> <arquivo-destino> [sha256-esperado]
#
# Baixa para models/ (fora do git) e verifica integridade por SHA-256.
# Nenhum modelo é versionado no repositório (docs §5.2).
# ============================================================
set -euo pipefail

URL="${1:-}"
DEST="${2:-}"
EXPECTED_SHA="${3:-}"

if [ -z "$URL" ] || [ -z "$DEST" ]; then
  echo "uso: $0 <url> <arquivo-destino> [sha256-esperado]"
  echo ""
  echo "exemplos:"
  echo "  # LLM pequeno (GGUF, ~940 MB):"
  echo "  $0 https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf models/qwen2.5-1.5b-instruct-q4_k_m.gguf"
  echo ""
  echo "  # STT whisper (tiny, multilíngue, ~75 MB):"
  echo "  $0 https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin models/ggml-tiny.bin"
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
TMP="$DEST.part"

echo "[download] $URL"
curl -fL --retry 3 --progress-bar -o "$TMP" "$URL"

ACTUAL="$(sha256sum "$TMP" | awk '{print $1}')"
if [ -n "$EXPECTED_SHA" ]; then
  if [ "$ACTUAL" != "$EXPECTED_SHA" ]; then
    echo "[erro] sha256 nao confere!"
    echo "  esperado: $EXPECTED_SHA"
    echo "  obtido:   $ACTUAL"
    rm -f "$TMP"
    exit 1
  fi
fi

mv "$TMP" "$DEST"
echo "[ok] $DEST"
echo "     sha256: $ACTUAL"
echo "     tamanho: $(du -h "$DEST" | awk '{print $1}')"
