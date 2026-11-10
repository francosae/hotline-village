#!/usr/bin/env bash
# Deploy the web build to Vercel: static files + api/exa.js (Exa key stays server-side as an env var).
# The Vapi PUBLIC key is written into the deployed local-config.js (never committed).
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a
bash scripts/export_web.sh
rm -rf deploy/public && mkdir -p deploy/public
cp -R build/web/. deploy/public/
cp web/hotline.js deploy/public/hotline.js
printf 'window.HOTLINE_LOCAL = {vapiKey: "%s"};\n' "$VAPI_API_KEY" > deploy/public/local-config.js
cd deploy
[ -d .vercel ] || vercel link --yes --project hotline-village >/dev/null
vercel env ls production 2>/dev/null | grep -q EXA_API_KEY || printf "%s" "$EXA_API_KEY" | vercel env add EXA_API_KEY production >/dev/null
vercel deploy --prod --yes 2>&1 | tail -3
