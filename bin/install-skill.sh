#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

install_dir() {
  local dst="$1"
  mkdir -p "$dst"
  cp "$ROOT/skills/wfw/SKILL.md" "$dst/SKILL.md"
  echo "  skill -> $dst/SKILL.md"
}

install_gemini_commands() {
  local dst="$HOME/.gemini/commands"
  mkdir -p "$dst/wfw"
  cp "$ROOT/commands/gemini/wfw.toml" "$dst/wfw.toml"
  cp "$ROOT/commands/gemini/wfw/"*.toml "$dst/wfw/"
  echo "  gemini -> $dst/wfw.toml (/wfw)"
  echo "  gemini -> $dst/wfw/*.toml (/wfw:start, /wfw:plan, /wfw:auto, /wfw:validate)"
}

echo "Installing /wfw for multiple LLM CLIs..."
echo

# Cursor and other agents that load ~/.cursor/skills/
if [ -d "$HOME/.cursor" ] || [ "${WFW_INSTALL_CURSOR:-1}" = "1" ]; then
  install_dir "$HOME/.cursor/skills/wfw"
fi

# OpenCode / shared agent skills path
install_dir "${WFW_AGENTS_SKILL_DIR:-$HOME/.agents/skills/wfw}"

# Optional override
if [ -n "${WFW_SKILL_DIR:-}" ]; then
  install_dir "$WFW_SKILL_DIR"
fi

# Gemini CLI custom commands
if [ -d "$HOME/.gemini" ] || command -v gemini >/dev/null 2>&1 || [ "${WFW_INSTALL_GEMINI:-1}" = "1" ]; then
  install_gemini_commands
fi

echo
echo "Done. Slash command names vary by CLI:"
echo "  Cursor / agents:  /wfw <subcommand>"
echo "  Gemini CLI:       /wfw, /wfw:start, /wfw:plan, /wfw:auto, /wfw:validate"
echo
echo "Terminal (all CLIs): wfw <subcommand>"
echo
echo "Gemini users: run /commands reload after install."
echo "MCP server support is planned for deeper cross-CLI tool integration."
