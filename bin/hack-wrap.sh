#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="my_team_workspace"
SHARED_PLAN="shared_lavish_plan.html"
ARTIFACT_LINK="lavish_artifact.html"
PROMPT_FILE=".wfw/last-prompt.txt"
GNHF_MAX_ITERATIONS="${WFW_GNHF_MAX_ITERATIONS:-12}"
GNHF_MAX_TOKENS="${WFW_GNHF_MAX_TOKENS:-300000}"
NO_MISTAKES_SKIP="${WFW_NO_MISTAKES_SKIP:-}"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command '$cmd' not found in PATH." >&2
    exit 1
  fi
}

wfw_verbose() {
  [ "${WFW_VERBOSE:-0}" = "1" ]
}

usage() {
  cat <<'EOF'
workflowWrapper (wfw) - hackathon orchestration CLI

Integration layer for treehouse + lavish + gnhf + no-mistakes.
All shared Lavish plan wiring is handled automatically by wfw start.

Workflow commands:
  wfw start <feature-name>       Lease a treehouse worktree (shared team plan wired in)
  wfw plan [prompt]              Queue prompt (if given), then open + poll for feedback
  wfw plan --reply "<text>"      Post agent reply in Lavish and poll again for more feedback
  wfw plan --open-only [prompt]  Open browser only (no poll)
  wfw prompt "<prompt>"          Queue plan prompt (then run wfw plan to open + poll)
  wfw auto "<objective>"         Run gnhf with guardrails in current worktree
  wfw validate                   Ship current branch through no-mistakes (worktree required)
  wfw setup                      Refresh skills and MCP config (run once after install)

Passthrough commands (full CLI retained):
  wfw treehouse <args>           e.g. wfw treehouse status
  wfw lavish <args>              e.g. wfw lavish poll lavish_artifact.html
  wfw gnhf <args>                gnhf with guardrails applied
  wfw no-mistakes [validate]       Safe no-mistakes push from worktree

gnhf guardrails (wfw auto and wfw gnhf):
  Defaults: --max-iterations 12, --max-tokens 300000
  Override: WFW_GNHF_MAX_ITERATIONS, WFW_GNHF_MAX_TOKENS

no-mistakes validate (wfw validate):
  Optional skip steps via WFW_NO_MISTAKES_SKIP (e.g. document)

Typical flow (from your app repo):
  wfw start my-feature
  cd <printed-worktree-path>
  wfw plan "What to build"
  wfw auto "Implement the plan"
  wfw validate
EOF
}

is_feature_worktree() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  [ -L "$ARTIFACT_LINK" ]
}

require_feature_worktree() {
  if ! is_feature_worktree; then
    echo "Error: not inside a leased feature worktree." >&2
    echo "Run 'wfw start <feature-name>' from your app repo, then cd into the worktree it prints." >&2
    exit 1
  fi
}

require_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: wfw start must run inside a git repository." >&2
    exit 1
  fi
}

canonical_path() {
  local path="$1"
  local dir base
  dir="$(dirname "$path")"
  base="$(basename "$path")"
  printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
}

resolve_repo_root() {
  local toplevel wt_path

  toplevel="$(git rev-parse --show-toplevel)"

  while IFS= read -r wt_line; do
    case "$wt_line" in
      worktree\ *)
        wt_path="${wt_line#worktree }"
        if [ -d "$wt_path/$WORKSPACE_DIR" ]; then
          printf '%s\n' "$wt_path"
          return
        fi
        ;;
    esac
  done < <(git worktree list --porcelain 2>/dev/null || true)

  if [ -d "$toplevel/$WORKSPACE_DIR" ]; then
    printf '%s\n' "$toplevel"
    return
  fi

  printf '%s\n' "$toplevel"
}

shared_plan_path() {
  local repo_root="$1"
  printf '%s\n' "$(canonical_path "$repo_root/$WORKSPACE_DIR/$SHARED_PLAN")"
}

resolve_lavish_artifact() {
  if is_feature_worktree; then
    printf '%s\n' "$ARTIFACT_LINK"
    return
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local repo_root plan
    repo_root="$(resolve_repo_root)"
    plan="$repo_root/$WORKSPACE_DIR/$SHARED_PLAN"
    if [ -f "$plan" ]; then
      printf '%s\n' "$plan"
      return
    fi
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
  local expected_canonical current current_canonical

  expected_canonical="$(canonical_path "$shared_plan_abs")"

  if [ -L "$link_path" ]; then
    current="$(readlink "$link_path")"
    if [ "${current#/}" != "$current" ]; then
      current_canonical="$(canonical_path "$current")"
    else
      current_canonical="$(canonical_path "$worktree_path/$current")"
    fi
    if [ "$current_canonical" = "$expected_canonical" ]; then
      return
    fi
    rm -f "$link_path"
  elif [ -d "$link_path" ]; then
    rm -rf "$link_path"
  elif [ -e "$link_path" ]; then
    rm -f "$link_path"
  fi

  ln -s "$shared_plan_abs" "$link_path"
}

ensure_treehouse_config() {
  if [ -f "treehouse.toml" ]; then
    return
  fi
  if [ -f "$WORKSPACE_DIR/treehouse.toml" ]; then
    mv "$WORKSPACE_DIR/treehouse.toml" "treehouse.toml"
    return
  fi
  treehouse init
}

print_first_start_setup() {
  cat <<'EOF'

First-time setup - install once per machine:
  wfw         npm install -g github:Sea1vester/workflow-Wrapper
  treehouse   worktree pool manager (must be on PATH)
  gnhf        autonomous coding agent (must be on PATH)
  node + npm  required for wfw plan / wfw lavish (npx lavish-axi)
  no-mistakes git remote named "no-mistakes" on your target repo

EOF
}

run_gnhf_guarded() {
  require_cmd gnhf
  if wfw_verbose; then
    echo "gnhf guardrails: max-iterations=$GNHF_MAX_ITERATIONS, max-tokens=$GNHF_MAX_TOKENS" >&2
  fi
  exec gnhf \
    --max-iterations "$GNHF_MAX_ITERATIONS" \
    --max-tokens "$GNHF_MAX_TOKENS" \
    "$@"
}

run_no_mistakes_push() {
  require_cmd git
  local -a push_args=()
  if [ -n "$NO_MISTAKES_SKIP" ]; then
    push_args+=(--push-option "no-mistakes.skip=$NO_MISTAKES_SKIP")
  fi
  exec git push "${push_args[@]}" no-mistakes HEAD "$@"
}

cmd_start() {
  local feature_name="${1:-}"
  local first_start=false
  local repo_root shared_plan_abs worktree_path

  if [ -z "$feature_name" ]; then
    echo "Error: feature name is required." >&2
    echo "Usage: wfw start <feature-name>" >&2
    exit 1
  fi

  require_cmd treehouse
  require_git_repo

  repo_root="$(resolve_repo_root)"
  cd "$repo_root"

  ensure_treehouse_config

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

  shared_plan_abs="$(shared_plan_path "$repo_root")"
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

  echo "cd $worktree_path"
  echo "Then: wfw plan"
  if wfw_verbose; then
    echo "Shared plan: $ARTIFACT_LINK -> $shared_plan_abs"
  fi
}

lavish_open_only() {
  local artifact="$1"
  require_cmd npx
  exec npx -y lavish-axi "$artifact"
}

lavish_open_and_poll() {
  local artifact="$1"
  require_cmd npx
  npx -y lavish-axi "$artifact"
  exec npx -y lavish-axi poll "$artifact"
}

lavish_reply_and_poll() {
  local artifact="$1"
  local agent_reply="$2"
  require_cmd npx
  npx -y lavish-axi poll "$artifact" --agent-reply "$agent_reply"
  exec npx -y lavish-axi poll "$artifact"
}

queue_plan_prompt() {
  local prompt_text="$1"
  mkdir -p .wfw
  printf '%s\n' "$prompt_text" >"$PROMPT_FILE"
  if wfw_verbose; then
    cat <<EOF
Lavish prompt queued in $PROMPT_FILE
EOF
  fi
}

print_plan_queued_next_step() {
  local artifact="$1"
  cat <<EOF
Prompt queued in $PROMPT_FILE

Next: build or update the Lavish HTML artifact ($artifact) using the lavish skill, then run:
  wfw plan

wfw plan opens lavish-axi and long-polls until the user sends feedback.
After applying feedback, run:
  wfw plan --reply "<summary of changes>"
That posts your reply in the browser and polls again for more feedback.
EOF
}

cmd_prompt() {
  local prompt_text="${1:-}"

  if [ -z "$prompt_text" ]; then
    echo "Error: prompt is required." >&2
    echo 'Usage: wfw prompt "<prompt>"' >&2
    exit 1
  fi

  local artifact
  artifact="$(resolve_lavish_artifact)"
  queue_plan_prompt "$prompt_text"
  print_plan_queued_next_step "$artifact"
}

cmd_plan() {
  local open_only=false
  local reply=""
  local -a prompt_parts=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --open-only)
        open_only=true
        shift
        ;;
      --reply)
        shift
        reply="${1:-}"
        if [ -z "$reply" ]; then
          echo "Error: --reply requires a message." >&2
          exit 1
        fi
        shift
        ;;
      *)
        prompt_parts+=("$1")
        shift
        ;;
    esac
  done

  if [ ${#prompt_parts[@]} -gt 0 ] && [ -n "$reply" ]; then
    echo "Error: cannot combine a plan prompt with --reply." >&2
    exit 1
  fi

  if [ "$open_only" = true ] && [ -n "$reply" ]; then
    echo "Error: cannot combine --open-only with --reply." >&2
    exit 1
  fi

  local artifact
  artifact="$(resolve_lavish_artifact)"

  if [ ${#prompt_parts[@]} -gt 0 ]; then
    queue_plan_prompt "${prompt_parts[*]}"
    if [ "$open_only" = true ]; then
      lavish_open_only "$artifact"
    fi
    print_plan_queued_next_step "$artifact"
    return 0
  fi

  if [ -n "$reply" ]; then
    lavish_reply_and_poll "$artifact" "$reply"
  elif [ "$open_only" = true ]; then
    lavish_open_only "$artifact"
  else
    lavish_open_and_poll "$artifact"
  fi
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
  run_no_mistakes_push
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
      run_no_mistakes_push "$@"
      ;;
    *)
      echo "Error: unknown no-mistakes subcommand '${1:-}'." >&2
      echo "Usage: wfw no-mistakes [validate|push]" >&2
      exit 1
      ;;
  esac
}

wfw_root() {
  local src="${BASH_SOURCE[0]}"
  while [ -L "$src" ]; do
    local dir
    dir="$(cd "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    case "$src" in /*) ;; *) src="$dir/$src" ;; esac
  done
  cd "$(dirname "$src")/.." && pwd
}

cmd_setup() {
  local root
  root="$(wfw_root)"
  bash "$root/bin/postinstall.sh"
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
    setup)
      cmd_setup
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
