#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="my_team_workspace"
SHARED_PLAN="shared_lavish_plan.html"
ARTIFACT_LINK="lavish_artifact.html"

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

Usage:
  wfw start <feature-name>   Bootstrap team workspace and lease a feature worktree
  wfw plan                   Open the shared Lavish planning artifact
  wfw auto "<objective>"     Run gnhf with the given objective in the current worktree
  wfw validate               Push current HEAD through the no-mistakes pipeline
  wfw --help                 Show this help message

Prerequisites (must already be on PATH):
  treehouse, lavish-axi (via npx), gnhf, git with no-mistakes remote configured

Examples:
  wfw start auth-refactor
  wfw plan
  wfw auto "Add OAuth login with Google"
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

append_git_exclude() {
  local git_dir
  git_dir="$(git rev-parse --git-dir)"
  mkdir -p "$git_dir/info"
  if ! grep -qxF "$ARTIFACT_LINK" "$git_dir/info/exclude" 2>/dev/null; then
    echo "$ARTIFACT_LINK" >>"$git_dir/info/exclude"
  fi
}

print_first_start_setup() {
  cat <<'EOF'

First-time setup - install once per machine:
  wfw         npm link   (from the workflow-wrapper repo)
  treehouse   worktree pool manager (must be on PATH)
  gnhf        autonomous coding agent (must be on PATH)
  node + npm  required for wfw plan (npx lavish-axi)
  no-mistakes git remote named "no-mistakes" on your target repo

EOF
}

cmd_start() {
  local feature_name="${1:-}"
  local first_start=false

  if [ -z "$feature_name" ]; then
    echo "Error: feature name is required." >&2
    echo "Usage: wfw start <feature-name>" >&2
    exit 1
  fi

  require_cmd treehouse

  if [ ! -d "$WORKSPACE_DIR" ]; then
    mkdir -p "$WORKSPACE_DIR"
    first_start=true
  fi
  cd "$WORKSPACE_DIR"

  if [ "$first_start" = true ]; then
    print_first_start_setup
  fi

  if [ ! -f "$SHARED_PLAN" ]; then
    : >"$SHARED_PLAN"
  fi

  if [ ! -f "treehouse.toml" ]; then
    treehouse init
  fi

  local workspace_root shared_plan_abs worktree_path
  workspace_root="$(pwd)"
  shared_plan_abs="$workspace_root/$SHARED_PLAN"

  worktree_path="$(treehouse get --lease --lease-holder "$feature_name")"
  if [ -z "$worktree_path" ] || [ ! -d "$worktree_path" ]; then
    echo "Error: treehouse did not return a valid worktree path." >&2
    exit 1
  fi

  cd "$worktree_path"

  if [ ! -e "$ARTIFACT_LINK" ]; then
    ln -s "$shared_plan_abs" "$ARTIFACT_LINK"
  fi

  append_git_exclude

  echo "Ready in worktree: $worktree_path"
  echo "Shared plan symlink: $ARTIFACT_LINK -> $shared_plan_abs"
  echo "Next: wfw plan"
}

cmd_plan() {
  require_feature_worktree
  require_cmd npx
  exec npx -y lavish-axi "$ARTIFACT_LINK"
}

cmd_auto() {
  local objective="${1:-}"

  if [ -z "$objective" ]; then
    echo "Error: objective is required." >&2
    echo 'Usage: wfw auto "<objective>"' >&2
    exit 1
  fi

  require_feature_worktree
  require_cmd gnhf
  exec gnhf "$objective"
}

cmd_validate() {
  require_feature_worktree
  require_cmd git
  exec git push no-mistakes HEAD
}

main() {
  local command="${1:-}"

  case "$command" in
    start)
      shift
      cmd_start "${1:-}"
      ;;
    plan)
      cmd_plan
      ;;
    auto)
      shift
      cmd_auto "${*:-}"
      ;;
    validate)
      cmd_validate
      ;;
    -h | --help | help | "")
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
