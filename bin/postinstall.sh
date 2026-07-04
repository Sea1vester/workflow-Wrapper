#!/usr/bin/env bash
# Refresh agent skills and MCP config after npm install (global, linked clone, or local dev).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ "${WFW_SKIP_POSTINSTALL:-0}" = "1" ]; then
  exit 0
fi

# Skip when workflow-wrapper is a dependency of another npm project (not a direct install).
if [[ "$ROOT" == *"/node_modules/workflow-wrapper" ]] && [ "${npm_config_global:-}" != "true" ]; then
  parent="$(dirname "$(dirname "$ROOT")")"
  if [ -f "$parent/package.json" ]; then
    parent_name="$(node -p "require('$parent/package.json').name" 2>/dev/null || true)"
    if [ -n "$parent_name" ] && [ "$parent_name" != "workflow-wrapper" ]; then
      exit 0
    fi
  fi
fi

# Skip in CI unless explicitly enabled.
if [ "${CI:-}" = "true" ] || [ "${CI:-}" = "1" ]; then
  if [ "${WFW_POSTINSTALL_IN_CI:-0}" != "1" ]; then
    exit 0
  fi
fi

echo "wfw postinstall: refreshing skills and MCP config..."

bash "$ROOT/bin/install-skill.sh"
bash "$ROOT/bin/install-mcp.sh"

echo "wfw postinstall: done."
echo "  Restart your LLM client if MCP tools changed."
echo "  Gemini users: run /commands reload after skill updates."
