#!/usr/bin/env bash
# Print-mode map for wfw auto one-shot agent calls.
# Sourced by bin/auto-loop.sh.

auto_agent_skip_permissions() {
  [ "${WFW_AUTO_ASK_PERMISSIONS:-0}" != "1" ]
}

# Resolve the binary used for non-interactive runs.
# The Cursor IDE (`cursor`) has no print mode; prefer `agent` / `cursor-agent`.
auto_agent_print_cli() {
  local cli="$1"

  if [ "$cli" = "cursor" ]; then
    if command -v agent >/dev/null 2>&1; then
      printf '%s\n' "agent"
      return 0
    fi
    if command -v cursor-agent >/dev/null 2>&1; then
      printf '%s\n' "cursor-agent"
      return 0
    fi
    echo "Error: Cursor IDE has no non-interactive print mode." >&2
    echo "Install the Cursor agent CLI (agent) or set WFW_AGENT_CLI to claude, opencode, gemini, or agy." >&2
    return 1
  fi

  printf '%s\n' "$cli"
}

# Run one non-interactive agent turn. Prompt is the last argument.
# stdout/stderr are left to the caller to redirect.
run_auto_agent_oneshot() {
  local cli="$1"
  local prompt="$2"
  local print_cli
  local -a cmd=()

  print_cli="$(auto_agent_print_cli "$cli")"

  case "$print_cli" in
    claude)
      cmd=(claude -p --output-format text)
      if auto_agent_skip_permissions; then
        cmd+=(--dangerously-skip-permissions)
      fi
      cmd+=("$prompt")
      ;;
    agent | cursor-agent)
      cmd=("$print_cli" -p --output-format text)
      if auto_agent_skip_permissions; then
        cmd+=(--force --trust)
      fi
      cmd+=("$prompt")
      ;;
    opencode)
      cmd=(opencode run)
      if auto_agent_skip_permissions; then
        cmd+=(--dangerously-skip-permissions)
      fi
      cmd+=("$prompt")
      ;;
    gemini)
      cmd=(gemini -p "$prompt")
      if auto_agent_skip_permissions; then
        cmd+=(--yolo --skip-trust)
      fi
      ;;
    agy)
      cmd=(agy -p)
      if auto_agent_skip_permissions; then
        cmd+=(--dangerously-skip-permissions)
      fi
      cmd+=("$prompt")
      ;;
    *)
      # Unknown CLIs (including test mocks): prompt as last arg, optional -p.
      cmd=("$print_cli" -p "$prompt")
      ;;
  esac

  if wfw_verbose; then
    echo "auto agent: ${cmd[*]}" >&2
  fi

  "${cmd[@]}"
}
