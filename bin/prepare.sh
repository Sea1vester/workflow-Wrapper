#!/usr/bin/env bash
# Skip MCP rebuild when dist is already shipped (git installs, published tarball).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -f "$ROOT/mcp/dist/index.js" ]; then
  exit 0
fi

npm --prefix "$ROOT/mcp" install
npm --prefix "$ROOT/mcp" run build
