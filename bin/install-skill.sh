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
  local src="$ROOT/mcp/prompts/gemini"
  local dst="$HOME/.gemini/commands"
  mkdir -p "$dst/wfw"
  cp "$src/wfw.toml" "$dst/wfw.toml"
  cp "$src/wfw/"*.toml "$dst/wfw/"
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

# Antigravity CLI (agy) global skills
if [ -d "$HOME/.gemini" ] || command -v agy >/dev/null 2>&1 || [ "${WFW_INSTALL_AGY:-1}" = "1" ]; then
  install_dir "$HOME/.gemini/config/skills/wfw"
  if [ -d "$HOME/.gemini/antigravity-cli" ] || command -v agy >/dev/null 2>&1; then
    install_dir "$HOME/.gemini/antigravity-cli/skills/wfw"
  fi
fi

# Gemini CLI custom commands
if [ -d "$HOME/.gemini" ] || command -v gemini >/dev/null 2>&1 || [ "${WFW_INSTALL_GEMINI:-1}" = "1" ]; then
  install_gemini_commands
fi

echo
echo "Done. Slash command names vary by CLI:"
echo "  Cursor / agents:  /wfw <subcommand>"
echo "  Antigravity CLI:  /wfw <subcommand> (via skills)"
echo "  Gemini CLI:       /wfw, /wfw:start, /wfw:plan, /wfw:auto, /wfw:validate"
echo
echo "Terminal (all CLIs): wfw <subcommand>"
echo
echo "Gemini users: run /commands reload after install."
