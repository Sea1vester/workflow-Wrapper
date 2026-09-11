#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Refuse ephemeral npm staging paths (git-clone caches). Writing those into
# ~/.cursor/mcp.json makes Cursor spawn a deleted tree after install finishes.
is_ephemeral_path() {
  case "$1" in
    */.npm/_cacache/*|*/git-clone*|*/npm-*/*) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_wfw_mcp_bin() {
  if [ -n "${WFW_MCP_BIN:-}" ]; then
    printf '%s\n' "$WFW_MCP_BIN"
    return
  fi

  # Prefer the PATH command name so Cursor always follows the current global bin
  # after upgrades, instead of a frozen absolute path from install time.
  if command -v wfw-mcp >/dev/null 2>&1; then
    printf '%s\n' "wfw-mcp"
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
case "$WFW_MCP_BIN" in
  /*)
    WFW_MCP_BIN="$(cd "$(dirname "$WFW_MCP_BIN")" && pwd)/$(basename "$WFW_MCP_BIN")"
    if is_ephemeral_path "$WFW_MCP_BIN"; then
      echo "Error: refusing to write ephemeral npm path into MCP config:" >&2
      echo "  $WFW_MCP_BIN" >&2
      echo "Finish the global install, then re-run: wfw setup" >&2
      exit 1
    fi
    ;;
esac

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
