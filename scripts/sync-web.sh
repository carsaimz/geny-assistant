#!/usr/bin/env bash
# ============================================================
# Geny Assistant — sincroniza o build web para o projeto Android
# Uso: ./scripts/sync-web.sh
# Executa npm run build em app/ e copia dist/ para os assets do Capacitor.
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[web] build TypeScript + Vite..."
(cd "$ROOT/app" && npm run build)

DEST="$ROOT/android/app/src/main/assets/public"
echo "[sync] app/dist -> android/app/src/main/assets/public"
rm -rf "$DEST"/*
cp -r "$ROOT/app/dist/." "$DEST/"

echo "[ok] assets sincronizados. Agora:"
echo "     cd android && gradle :app:assembleDebug"
