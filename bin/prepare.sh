#!/usr/bin/env bash
# Skip MCP rebuild when dist is already shipped (git installs, published tarball).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# #region agent log
# shellcheck source=bin/debug-log.sh
source "$ROOT/bin/debug-log.sh" 2>/dev/null || true
_global_target="${npm_config_prefix:-}/lib/node_modules/workflow-wrapper"
_global_type="missing"
[ -e "$_global_target" ] && _global_type="$(file -b "$_global_target" 2>/dev/null || echo unknown)"
[ -L "$_global_target" ] && _global_type="symlink"
_debug_log "A" "bin/prepare.sh:entry" "prepare lifecycle invoked" \
  "{\"root\":\"$ROOT\",\"npm_config_global\":\"${npm_config_global:-}\",\"global_target\":\"$_global_target\",\"global_target_type\":\"$_global_type\",\"has_dist\":$([ -f "$ROOT/mcp/dist/index.js" ] && echo true || echo false)}"
# #endregion

if [ -f "$ROOT/mcp/dist/index.js" ]; then
  # #region agent log
  _debug_log "E" "bin/prepare.sh:skip" "skipping MCP rebuild, dist present" "{\"root\":\"$ROOT\"}"
  # #endregion
  exit 0
fi

# #region agent log
_debug_log "E" "bin/prepare.sh:build" "running nested mcp install+build" "{\"root\":\"$ROOT\"}"
# #endregion
npm --prefix "$ROOT/mcp" install
npm --prefix "$ROOT/mcp" run build
