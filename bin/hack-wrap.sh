#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="my_team_workspace"
SHARED_PLAN="shared_lavish_plan.html"
ARTIFACT_LINK="lavish_artifact.html"
PROMPT_FILE=".wfw/last-prompt.txt"
GNHF_MAX_ITERATIONS="${WFW_GNHF_MAX_ITERATIONS:-12}"
GNHF_MAX_TOKENS="${WFW_GNHF_MAX_TOKENS:-300000}"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command '$cmd' not found in PATH." >&2
    exit 1
  fi
}

usage() {
  cat <<'EOF'
workflowWrapper (wfw) - hackathon orchestration CLI

Integration layer for treehouse + lavish + gnhf + no-mistakes.
Prefix any underlying tool command with wfw to run it through this wrapper.

Workflow commands:
  wfw start <feature-name>       Bootstrap workspace, shared Lavish plan, lease treehouse worktree
  wfw plan [prompt]              Open Lavish artifact; with prompt, queue /lavish-style build
  wfw prompt "<prompt>"          Same as wfw plan "<prompt>"
  wfw auto "<objective>"         Run gnhf with guardrails in current worktree
  wfw validate                   git push no-mistakes HEAD (worktree required)

Passthrough commands (full CLI retained):
  wfw treehouse <args>           e.g. wfw treehouse status
  wfw lavish <args>              e.g. wfw lavish poll lavish_artifact.html
  wfw gnhf <args>                gnhf with guardrails applied
  wfw no-mistakes [validate]       Safe no-mistakes push from worktree

Agent slash command (LLM agents, not the wfw terminal):
  /wfw <command>                 For any LLM CLI that supports custom skills/slash commands
                                 Install skill: npm run install-skill
                                 e.g. /wfw prompt Build the auth flow

gnhf guardrails (wfw auto and wfw gnhf):
  Defaults: --max-iterations 12, --max-tokens 300000
  Override: WFW_GNHF_MAX_ITERATIONS, WFW_GNHF_MAX_TOKENS

Examples:
  wfw start auth-refactor
  wfw plan "Map the OAuth login flow"
  wfw lavish lavish_artifact.html
  wfw auto "Implement the approved plan"
  wfw treehouse status
  wfw validate
EOF
}

is_feature_worktree() {
  [ -e "$ARTIFACT_LINK" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

require_feature_worktree() {
  if ! is_feature_worktree; then
    echo "Error: not inside a feature worktree." >&2
    echo "Run 'wfw start <feature-name>' first, then cd into the leased worktree." >&2
    exit 1
  fi
}

resolve_lavish_artifact() {
  if is_feature_worktree; then
    printf '%s\n' "$ARTIFACT_LINK"
    return
  fi

  if [ -f "$WORKSPACE_DIR/$SHARED_PLAN" ]; then
    printf '%s\n' "$WORKSPACE_DIR/$SHARED_PLAN"
    return
  fi

  mkdir -p .lavish
  local fallback=".lavish/plan.html"
  if [ ! -f "$fallback" ]; then
    : >"$fallback"
  fi
  printf '%s\n' "$fallback"
}

require_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: wfw start must run inside a git repository." >&2
    exit 1
  fi
}

resolve_repo_root() {
  git rev-parse --show-toplevel
}

append_git_exclude_pattern() {
  local pattern="$1"
  local git_dir
  git_dir="$(git rev-parse --git-dir)"
  mkdir -p "$git_dir/info"
  if ! grep -qxF "$pattern" "$git_dir/info/exclude" 2>/dev/null; then
    echo "$pattern" >>"$git_dir/info/exclude"
  fi
}

append_git_exclude() {
  append_git_exclude_pattern "$ARTIFACT_LINK"
}

append_shared_plan_git_exclude() {
  local repo_root="$1"
  local git_dir
  git_dir="$(git -C "$repo_root" rev-parse --git-dir)"
  mkdir -p "$git_dir/info"
  local pattern="$WORKSPACE_DIR/$SHARED_PLAN"
  if ! grep -qxF "$pattern" "$git_dir/info/exclude" 2>/dev/null; then
    echo "$pattern" >>"$git_dir/info/exclude"
  fi
}

ensure_lavish_symlink() {
  local worktree_path="$1"
  local shared_plan_abs="$2"
  local link_path="$worktree_path/$ARTIFACT_LINK"

  if [ -L "$link_path" ]; then
    local current
    current="$(readlink "$link_path")"
    if [ "$current" = "$shared_plan_abs" ]; then
      return
    fi
    rm -f "$link_path"
  elif [ -e "$link_path" ]; then
    rm -f "$link_path"
  fi

  ln -s "$shared_plan_abs" "$link_path"
}

print_first_start_setup() {
  cat <<'EOF'

First-time setup - install once per machine:
  wfw         npm link && npm run install-skill   (from the workflow-wrapper repo)
  treehouse   worktree pool manager (must be on PATH)
  gnhf        autonomous coding agent (must be on PATH)
  node + npm  required for wfw plan / wfw lavish (npx lavish-axi)
  no-mistakes git remote named "no-mistakes" on your target repo

EOF
}

run_gnhf_guarded() {
  require_cmd gnhf
  echo "gnhf guardrails: max-iterations=$GNHF_MAX_ITERATIONS, max-tokens=$GNHF_MAX_TOKENS" >&2
  exec gnhf \
    --max-iterations "$GNHF_MAX_ITERATIONS" \
    --max-tokens "$GNHF_MAX_TOKENS" \
    "$@"
}

cmd_start() {
  local feature_name="${1:-}"
  local first_start=false
  local repo_root

  if [ -z "$feature_name" ]; then
    echo "Error: feature name is required." >&2
    echo "Usage: wfw start <feature-name>" >&2
    exit 1
  fi

  require_cmd treehouse
  require_git_repo

  repo_root="$(resolve_repo_root)"
  cd "$repo_root"

  # treehouse.toml lives at the git repo root, not inside my_team_workspace.
  if [ ! -f "treehouse.toml" ]; then
    treehouse init
  fi

  if [ ! -d "$WORKSPACE_DIR" ]; then
    mkdir -p "$WORKSPACE_DIR"
    first_start=true
  fi

  if [ "$first_start" = true ]; then
    print_first_start_setup
  fi

  if [ ! -f "$WORKSPACE_DIR/$SHARED_PLAN" ]; then
    : >"$WORKSPACE_DIR/$SHARED_PLAN"
  fi

  local shared_plan_abs worktree_path
  shared_plan_abs="$(cd "$repo_root/$WORKSPACE_DIR" && pwd -P)/$SHARED_PLAN"

  append_shared_plan_git_exclude "$repo_root"

  worktree_path="$(treehouse get --lease --lease-holder "$feature_name")"
  if [ -z "$worktree_path" ] || [ ! -d "$worktree_path" ]; then
    echo "Error: treehouse did not return a valid worktree path." >&2
    exit 1
  fi

  (
    cd "$worktree_path"
    ensure_lavish_symlink "$worktree_path" "$shared_plan_abs"
    append_git_exclude
  )

  echo "Ready in worktree: $worktree_path"
  echo "Shared plan symlink: $ARTIFACT_LINK -> $shared_plan_abs"
  echo "Next: wfw plan or wfw plan \"<what to build>\""
}

cmd_prompt() {
  local prompt_text="${1:-}"
  local artifact

  if [ -z "$prompt_text" ]; then
    echo "Error: prompt is required." >&2
    echo 'Usage: wfw prompt "<prompt>"' >&2
    exit 1
  fi

  artifact="$(resolve_lavish_artifact)"
  mkdir -p .wfw
  printf '%s\n' "$prompt_text" >"$PROMPT_FILE"

  cat <<EOF
Lavish prompt queued in $PROMPT_FILE
Artifact target: $artifact

Agent workflow (same as /lavish):
  1. Read $PROMPT_FILE and build or update the HTML artifact
  2. Run: wfw lavish "$artifact"
  3. Run: wfw lavish poll "$artifact" (leave running for review)

Or invoke in your LLM: /wfw prompt $prompt_text

EOF

  require_cmd npx
  exec npx -y lavish-axi "$artifact"
}

cmd_plan() {
  if [ $# -gt 0 ]; then
    cmd_prompt "$*"
    return
  fi

  local artifact
  artifact="$(resolve_lavish_artifact)"
  require_cmd npx
  exec npx -y lavish-axi "$artifact"
}

cmd_auto() {
  local objective="${1:-}"

  if [ -z "$objective" ]; then
    echo "Error: objective is required." >&2
    echo 'Usage: wfw auto "<objective>"' >&2
    exit 1
  fi

  require_feature_worktree
  run_gnhf_guarded "$objective"
}

cmd_validate() {
  require_feature_worktree
  require_cmd git
  exec git push no-mistakes HEAD
}

cmd_passthrough_treehouse() {
  require_cmd treehouse
  exec treehouse "$@"
}

cmd_passthrough_lavish() {
  require_cmd npx
  exec npx -y lavish-axi "$@"
}

cmd_passthrough_gnhf() {
  if [ $# -eq 0 ]; then
    echo "Error: gnhf requires arguments." >&2
    exit 1
  fi
  run_gnhf_guarded "$@"
}

cmd_passthrough_no_mistakes() {
  case "${1:-validate}" in
    validate | push | "")
      if [ "${1:-}" != "" ]; then
        shift
      fi
      require_feature_worktree
      require_cmd git
      exec git push no-mistakes HEAD "$@"
      ;;
    *)
      echo "Error: unknown no-mistakes subcommand '${1:-}'." >&2
      echo "Usage: wfw no-mistakes [validate|push]" >&2
      exit 1
      ;;
  esac
}

main() {
  local command="${1:-}"

  case "$command" in
    start)
      shift
      cmd_start "${1:-}"
      ;;
    plan)
      shift
      cmd_plan "$@"
      ;;
    prompt)
      shift
      cmd_prompt "${*:-}"
      ;;
    auto)
      shift
      cmd_auto "${*:-}"
      ;;
    validate)
      cmd_validate
      ;;
    treehouse)
      shift
      cmd_passthrough_treehouse "$@"
      ;;
    lavish | lavish-axi)
      shift
      cmd_passthrough_lavish "$@"
      ;;
    gnhf)
      shift
      cmd_passthrough_gnhf "$@"
      ;;
    no-mistakes)
      shift
      cmd_passthrough_no_mistakes "$@"
      ;;
    -h | --help | help)
      usage
      ;;
    "")
      usage
      ;;
    *)
      echo "Error: unknown command '$command'." >&2
      echo >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
