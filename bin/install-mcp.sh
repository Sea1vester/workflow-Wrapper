#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

resolve_wfw_mcp_bin() {
  if [ -n "${WFW_MCP_BIN:-}" ]; then
    printf '%s\n' "$WFW_MCP_BIN"
    return
  fi

  if command -v wfw-mcp >/dev/null 2>&1; then
    command -v wfw-mcp
    return
  fi

  local bundled="$ROOT/mcp/dist/index.js"
  if [ -f "$bundled" ]; then
    printf '%s\n' "$bundled"
    return
  fi

  echo "Error: wfw-mcp not found. Run 'npm install' in workflow-wrapper first." >&2
  exit 1
}

WFW_MCP_BIN="$(resolve_wfw_mcp_bin)"
WFW_MCP_BIN="$(cd "$(dirname "$WFW_MCP_BIN")" && pwd)/$(basename "$WFW_MCP_BIN")"

if ! command -v wfw >/dev/null 2>&1 && [ ! -x "$ROOT/bin/hack-wrap.sh" ]; then
  echo "Error: wfw not found. Run 'npm link' once from workflow-wrapper, then retry." >&2
  exit 1
fi

CURSOR_MCP="${HOME}/.cursor/mcp.json"

merge_cursor_mcp() {
  local tmp
  tmp="$(mktemp)"
  if [ -f "$CURSOR_MCP" ]; then
    node -e "
      const fs = require('fs');
      const path = process.argv[1];
      const bin = process.argv[2];
      const file = process.argv[3];
      let cfg = {};
      try { cfg = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}
      cfg.mcpServers = cfg.mcpServers || {};
      cfg.mcpServers.wfw = { command: bin, args: [] };
      fs.writeFileSync(path, JSON.stringify(cfg, null, 2) + '\n');
    " "$tmp" "$WFW_MCP_BIN" "$CURSOR_MCP"
  else
    mkdir -p "$(dirname "$CURSOR_MCP")"
    printf '{\n  "mcpServers": {\n    "wfw": {\n      "command": "%s",\n      "args": []\n    }\n  }\n}\n' "$WFW_MCP_BIN" >"$tmp"
  fi
  mv "$tmp" "$CURSOR_MCP"
  echo "  cursor -> $CURSOR_MCP"
}

echo "Installing wfw MCP server config..."
echo "  wfw-mcp: $WFW_MCP_BIN"
if command -v wfw >/dev/null 2>&1; then
  echo "  wfw:     $(command -v wfw)"
else
  echo "  wfw:     $ROOT/bin/hack-wrap.sh (run 'npm link' to put on PATH)"
fi
echo

merge_cursor_mcp

echo
echo "Gemini CLI (if installed):"
echo "  gemini mcp add -s user wfw $WFW_MCP_BIN"
echo
echo "Claude Desktop: add the same command to your MCP config manually."
