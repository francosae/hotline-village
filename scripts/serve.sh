#!/usr/bin/env bash
# Serve the repo root on http://localhost:8060 (mic access needs localhost or https).
#   http://localhost:8060/web/test.html        voice loop alone, no Godot
#   http://localhost:8060/build/web/index.html  the game (after a Web export to build/web/)
# If .env has VAPI_API_KEY (the Vapi PUBLIC key), it is written to a gitignored
# local-config.js next to hotline.js so pages pick it up without a URL param.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8060}"
cd "$ROOT"

write_local_config() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  ( umask 077; printf 'window.HOTLINE_LOCAL = { vapiKey: %s };\n' \
      "$(python3 -c 'import json,os;print(json.dumps(os.environ["VAPI_API_KEY"]))')" > "$dir/local-config.js" )
}

if [ -f .env ]; then
  VAPI_API_KEY="$(grep -E '^VAPI_API_KEY=' .env | tail -1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')" || true
  if [ -n "${VAPI_API_KEY:-}" ]; then
    export VAPI_API_KEY
    write_local_config web
    write_local_config build/web
    echo "Vapi key from .env -> local-config.js (gitignored)"
  fi
fi

# Keep the exported game's copy of the bridge current (shell.html also falls back to ../../web/).
if [ -d build/web ]; then cp web/hotline.js build/web/hotline.js; fi

echo "Serving $ROOT"
echo "  http://localhost:$PORT/web/test.html"
echo "  http://localhost:$PORT/build/web/index.html"
exec python3 -m http.server "$PORT" --bind 127.0.0.1
