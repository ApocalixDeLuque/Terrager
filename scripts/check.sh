#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/build.sh" >/dev/null
codesign --verify --deep --strict --verbose=2 "$ROOT_DIR/dist/Terrager.app"
hdiutil imageinfo "$ROOT_DIR/dist/Terrager.dmg" >/dev/null

echo "Terrager build checks passed."
