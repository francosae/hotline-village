#!/usr/bin/env bash
# Export the Web build to build/web/index.html (no threads: runs without COOP/COEP headers).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/web
godot --headless --export-release "Web" build/web/index.html
# hotline.js and friends are loaded by the shell; copy them next to index.html
cp web/hotline.js build/web/ 2>/dev/null || true
echo "Exported to build/web/index.html"
