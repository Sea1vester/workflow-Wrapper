#!/usr/bin/env bash
set -euo pipefail

WFW_MCP_BIN="${WFW_MCP_BIN:-$(command -v wfw-mcp || true)}"

if [ -z "$WFW_MCP_BIN" ]; then
  echo "Error: wfw-mcp not found on PATH. Run 'npm link' from workflow-wrapper first." >&2
  exit 1
fi

if ! command -v wfw >/dev/null 2>&1; then
  echo "Error: wfw not found on PATH. Run 'npm link' from workflow-wrapper first." >&2
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
echo "  wfw:     $(command -v wfw)"
echo

merge_cursor_mcp

echo
echo "Gemini CLI (if installed):"
echo "  gemini mcp add -s user wfw $WFW_MCP_BIN"
echo
echo "Claude Desktop: add the same command to your MCP config manually."
echo
echo "Restart your LLM client, then use wfw_start / wfw_plan / wfw_auto / wfw_validate tools."
