#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="my_team_workspace"
SHARED_PLAN="shared_lavish_plan.html"
ARTIFACT_LINK="lavish_artifact.html"
PROMPT_FILE=".wfw/last-prompt.txt"
LISTENING_FILE=".wfw/plan-listening"
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
  wfw start <feature-name>       Lease a treehouse worktree (enters shell when interactive)
  wfw start <feature> --path     Print leased worktree path only (for scripts)
  wfw start <feature> --no-enter Print cd hint without switching shell
  wfw plan [prompt]              Queue prompt (if given), then open + poll for feedback
  wfw plan --reply "<text>"      Post agent reply in Lavish and poll again for more feedback
  wfw plan --open-only [prompt]  Open browser only (no poll)
  wfw prompt "<prompt>"          Queue plan prompt (then run wfw plan to open + poll)
  wfw auto "<objective>"         Run gnhf with guardrails in current worktree
  wfw agent [feature] [-- args]  Lease worktree (if needed) and open your agent CLI
  wfw merge [--abort]            Merge feature branch into main (from leased worktree)
  wfw validate                   Ship current branch through no-mistakes (worktree required)
  wfw cleanup [--global]         Prune merged, idle treehouse worktrees (dry-run: treehouse prune)
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
  After a successful push, returns the leased worktree and prunes merged idle pools
  (disable: WFW_SKIP_WORKTREE_CLEANUP=1)

agent CLI (wfw agent):
  Override detection with WFW_AGENT_CLI or wfw agent --cli <name>
  Auto-detect order: claude, opencode, agy, gemini, cursor, agent, cursor-agent

Typical flow (from your app repo):
  wfw start my-feature            # interactive: lands in the worktree shell
  wfw plan "What to build"
  wfw auto "Implement the plan"
  wfw merge                       # or wfw validate for no-mistakes PR flow
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
  cat >&2 <<'EOF'

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
  git push "${push_args[@]}" no-mistakes HEAD "$@"
  local rc=$?
  if [ $rc -eq 0 ]; then
    cleanup_worktree_after_ship
  fi
  exit $rc
}

cleanup_worktree_after_ship() {
  if [ "${WFW_SKIP_WORKTREE_CLEANUP:-0}" = "1" ]; then
    return 0
  fi
  if ! command -v treehouse >/dev/null 2>&1; then
    return 0
  fi
  if ! is_feature_worktree; then
    return 0
  fi

  local worktree_path
  worktree_path="$(pwd -P)"

  if wfw_verbose; then
    echo "treehouse: returning leased worktree $worktree_path" >&2
  fi
  treehouse return "$worktree_path" --force >/dev/null 2>&1 || true

  if wfw_verbose; then
    echo "treehouse: pruning merged idle worktrees" >&2
  fi
  treehouse prune --yes >/dev/null 2>&1 || true
}

resolve_default_branch() {
  local repo_root="$1"
  local branch

  branch="$(git -C "$repo_root" symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')" || true
  if [ -n "$branch" ]; then
    printf '%s\n' "$branch"
    return 0
  fi

  for branch in main master; do
    if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"; then
      printf '%s\n' "$branch"
      return 0
    fi
  done

  git -C "$repo_root" branch --show-current
}

resolve_main_worktree() {
  local repo_root="$1"
  local default_branch="$2"
  local wt_path="" wt_branch=""

  while IFS= read -r wt_line; do
    case "$wt_line" in
      worktree\ *)
        wt_path="${wt_line#worktree }"
        ;;
      branch\ refs/heads/*)
        wt_branch="${wt_line#branch refs/heads/}"
        if [ "$wt_branch" = "$default_branch" ]; then
          printf '%s\n' "$wt_path"
          return 0
        fi
        ;;
    esac
  done < <(git -C "$repo_root" worktree list --porcelain 2>/dev/null || true)

  printf '%s\n' "$repo_root"
}

cmd_merge() {
  local abort=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --abort)
        abort=true
        shift
        ;;
      -h | --help)
        cat <<'EOF'
Usage: wfw merge [--abort]

Merge the current feature worktree branch into the repo default branch (main/master).

Run from inside a leased worktree after committing your feature work.
On conflict, resolve files in the main worktree, commit, then return here.

  wfw merge --abort   Abort an in-progress merge in the main worktree

Parallel features that touch the same files may conflict. Merge one feature at a time.
After the first merge lands, rebase or merge main into the other feature worktrees before merging them.
EOF
        return 0
        ;;
      *)
        echo "Error: unknown merge argument '$1'." >&2
        exit 1
        ;;
    esac
  done

  require_cmd git
  require_feature_worktree

  local feature_wt feature_branch repo_root default_branch main_wt
  feature_wt="$(pwd -P)"
  feature_branch="$(git branch --show-current)"
  repo_root="$(resolve_repo_root)"
  default_branch="$(resolve_default_branch "$repo_root")"
  main_wt="$(resolve_main_worktree "$repo_root" "$default_branch")"

  if [ "$abort" = true ]; then
    if git -C "$main_wt" merge --abort >/dev/null 2>&1; then
      echo "Aborted merge in $main_wt"
    else
      echo "No merge in progress in $main_wt"
    fi
    return 0
  fi

  if [ "$feature_branch" = "$default_branch" ]; then
    echo "Error: already on $default_branch. Run wfw merge from a feature worktree." >&2
    exit 1
  fi

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Error: commit or stash changes in the feature worktree first." >&2
    exit 1
  fi

  if ! git -C "$main_wt" diff --quiet || ! git -C "$main_wt" diff --cached --quiet; then
    echo "Error: main worktree has uncommitted changes ($main_wt)." >&2
    exit 1
  fi

  if git -C "$main_wt" merge --no-edit "$feature_branch"; then
    echo "Merged $feature_branch into $default_branch."
    echo "Main worktree: $main_wt"
    cleanup_worktree_after_ship
    return 0
  fi

  cat >&2 <<EOF
Merge conflict while merging $feature_branch into $default_branch.

Resolve in the main worktree:
  cd $main_wt
  git status
  # edit conflicted files, git add ..., git commit

Abort the merge:
  wfw merge --abort

Conflicted files:
EOF
  git -C "$main_wt" diff --name-only --diff-filter=U >&2 || true
  exit 1
}

resolve_agent_cli() {
  if [ -n "${WFW_AGENT_CLI:-}" ]; then
    if ! command -v "$WFW_AGENT_CLI" >/dev/null 2>&1; then
      echo "Error: WFW_AGENT_CLI='$WFW_AGENT_CLI' not found in PATH." >&2
      exit 1
    fi
    printf '%s\n' "$WFW_AGENT_CLI"
    return 0
  fi

  local candidate
  for candidate in claude opencode agy gemini cursor agent cursor-agent; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  cat >&2 <<'EOF'
Error: no agent CLI found in PATH.

Install one of: claude, opencode, agy, gemini, cursor, agent
Or set WFW_AGENT_CLI to the command name you use.
EOF
  exit 1
}

lease_feature_worktree() {
  local feature_name="$1"
  local first_start=false
  local repo_root shared_plan_abs worktree_path

  if [ -z "$feature_name" ]; then
    echo "Error: feature name is required." >&2
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

  printf '%s\n' "$worktree_path"
}

cmd_start() {
  local feature_name=""
  local print_path=false
  local enter=false
  local no_enter=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --path)
        print_path=true
        shift
        ;;
      --enter)
        enter=true
        shift
        ;;
      --no-enter)
        no_enter=true
        shift
        ;;
      -h | --help)
        cat <<'EOF'
Usage: wfw start <feature-name> [--path | --enter | --no-enter]

Leases a treehouse worktree and wires the shared Lavish plan symlink.

  --path      Print worktree path only (for scripts / MCP)
  --enter     Switch into the worktree shell (default when stdout is a TTY)
  --no-enter  Print cd hint only
EOF
        return 0
        ;;
      *)
        if [ -z "$feature_name" ]; then
          feature_name="$1"
          shift
        else
          echo "Error: unknown start argument '$1'." >&2
          exit 1
        fi
        ;;
    esac
  done

  if [ -z "$feature_name" ]; then
    echo "Error: feature name is required." >&2
    echo "Usage: wfw start <feature-name>" >&2
    exit 1
  fi

  local worktree_path
  worktree_path="$(lease_feature_worktree "$feature_name")"

  if [ "$print_path" = true ]; then
    printf '%s\n' "$worktree_path"
    return 0
  fi

  if [ "$enter" = false ] && [ "$no_enter" = false ] && [ -t 1 ]; then
    enter=true
  fi

  if [ "$enter" = true ]; then
    echo "Worktree: $worktree_path" >&2
    echo "Next: wfw plan" >&2
    cd "$worktree_path"
    exec "${SHELL:-/bin/bash}"
  fi

  echo "cd $worktree_path"
  echo "Tip: wfw start $feature_name --enter"
  echo "Then: wfw plan"
  if wfw_verbose; then
    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || dirname "$worktree_path")"
    echo "Shared plan: $ARTIFACT_LINK -> $(shared_plan_path "$repo_root")"
  fi
}

mark_plan_listening() {
  local artifact="$1"
  mkdir -p .wfw
  printf '%s\n' "$(canonical_path "$artifact")" >"$LISTENING_FILE"
}

clear_plan_listening() {
  rm -f "$LISTENING_FILE"
}

require_nonempty_artifact() {
  local artifact="$1"
  if [ ! -f "$artifact" ] || [ ! -s "$artifact" ]; then
    cat >&2 <<EOF
Error: plan artifact is empty or missing ($artifact).

wfw plan does not generate HTML. Queue a prompt, build the artifact with the lavish skill, then run:
  wfw plan

Queued prompts live in $PROMPT_FILE
EOF
    exit 1
  fi
}

poll_has_result() {
  local output="$1"
  if printf '%s\n' "$output" | grep -qE 'status: (feedback|ended)'; then
    return 0
  fi
  if printf '%s\n' "$output" | grep -q 'LAVISH_AXI_POLL=' \
    && ! printf '%s\n' "$output" | grep -q 'LAVISH_AXI_POLL_REPLY='; then
    return 0
  fi
  return 1
}

lavish_poll_resilient() {
  local artifact="$1"
  local agent_reply="${2:-}"
  local poll_output=""
  local rc=0

  mark_plan_listening "$artifact"
  echo "wfw: listening for Lavish feedback on $artifact (poll resumes if interrupted)" >&2

  while true; do
    local -a poll_cmd=(npx -y lavish-axi poll "$artifact")
    if [ -n "$agent_reply" ]; then
      poll_cmd+=(--agent-reply "$agent_reply")
      agent_reply=""
    fi

    set +e
    poll_output="$("${poll_cmd[@]}" 2>&1)"
    rc=$?
    set -e

    printf '%s\n' "$poll_output"

    if [ $rc -eq 0 ] && poll_has_result "$poll_output"; then
      clear_plan_listening
      return 0
    fi

    if [ $rc -eq 130 ] || [ $rc -eq 143 ] || printf '%s\n' "$poll_output" | grep -q 'Poll interrupted'; then
      echo "wfw: Lavish poll interrupted; resuming listen..." >&2
      sleep 1
      continue
    fi

    if [ $rc -ne 0 ]; then
      clear_plan_listening
      return $rc
    fi

    echo "wfw: no feedback yet; continuing to listen..." >&2
  done
}

lavish_open_only() {
  local artifact="$1"
  require_cmd npx
  exec npx -y lavish-axi "$artifact"
}

lavish_open_and_poll() {
  local artifact="$1"
  require_cmd npx
  require_nonempty_artifact "$artifact"
  npx -y lavish-axi "$artifact"
  lavish_poll_resilient "$artifact"
}

lavish_reply_and_poll() {
  local artifact="$1"
  local agent_reply="$2"
  require_cmd npx
  require_nonempty_artifact "$artifact"
  set +e
  npx -y lavish-axi poll "$artifact" --agent-reply "$agent_reply" >/dev/null 2>&1
  set -e
  lavish_poll_resilient "$artifact"
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

wfw plan opens lavish-axi and keeps listening (poll auto-resumes if your agent harness interrupts it).
After applying feedback, run:
  wfw plan --reply "<summary of changes>"
That posts your reply in the browser and listens again for more feedback.
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

cmd_agent() {
  local feature_name=""
  local cli_override=""
  local -a agent_args=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --cli)
        shift
        cli_override="${1:-}"
        if [ -z "$cli_override" ]; then
          echo "Error: --cli requires a command name." >&2
          exit 1
        fi
        shift
        ;;
      --)
        shift
        agent_args+=("$@")
        break
        ;;
      *)
        if [ -z "$feature_name" ] && ! is_feature_worktree; then
          feature_name="$1"
          shift
        else
          agent_args+=("$1")
          shift
        fi
        ;;
    esac
  done

  local worktree_path agent_cli
  if is_feature_worktree; then
    worktree_path="$(pwd -P)"
  else
    if [ -z "$feature_name" ]; then
      echo "Error: feature name is required outside a leased worktree." >&2
      echo "Usage: wfw agent <feature-name> [-- agent-args...]" >&2
      echo "Or: cd into a worktree from 'wfw start', then run: wfw agent" >&2
      exit 1
    fi
    worktree_path="$(lease_feature_worktree "$feature_name")"
    echo "Leased worktree: $worktree_path" >&2
  fi

  if [ -n "$cli_override" ]; then
    WFW_AGENT_CLI="$cli_override"
  fi
  agent_cli="$(resolve_agent_cli)"

  if wfw_verbose; then
    echo "Launching $agent_cli in $worktree_path" >&2
  fi

  cd "$worktree_path"
  if [ ${#agent_args[@]} -eq 0 ]; then
    exec "$agent_cli"
  else
    exec "$agent_cli" "${agent_args[@]}"
  fi
}

cmd_cleanup() {
  local global=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --global | --all)
        global=true
        shift
        ;;
      -h | --help)
        cat <<'EOF'
Usage: wfw cleanup [--global]

Prune idle treehouse worktrees whose HEAD is already merged into the default branch.
Uses 'treehouse prune --yes' in the current repo, or '--global' for every pool.

Preview without deleting: wfw treehouse prune
EOF
        return 0
        ;;
      *)
        echo "Error: unknown cleanup argument '$1'." >&2
        exit 1
        ;;
    esac
  done

  require_cmd treehouse
  if [ "$global" = true ]; then
    treehouse prune --all --yes
  else
    require_git_repo
    treehouse prune --yes
  fi
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
      cmd_start "$@"
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
    agent)
      shift
      cmd_agent "$@"
      ;;
    validate)
      cmd_validate
      ;;
    merge)
      shift
      cmd_merge "$@"
      ;;
    setup)
      cmd_setup
      ;;
    cleanup)
      shift
      cmd_cleanup "$@"
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
