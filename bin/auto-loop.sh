#!/usr/bin/env bash
# Autoresearch-style experiment loop for wfw auto.
# Sourced by bin/hack-wrap.sh (uses require_cmd, resolve_agent_cli, append_git_exclude_pattern, wfw_verbose).

WFW_AUTO_DIR=".wfw/auto"
WFW_AUTO_SNAPSHOT_REF="refs/wfw-auto/snapshot"

auto_lib_dir() {
  local src="${BASH_SOURCE[0]}"
  (cd "$(dirname "$src")" && pwd)
}

# shellcheck disable=SC1091
# shellcheck source=bin/auto-agent.sh
source "$(auto_lib_dir)/auto-agent.sh"

auto_max_iterations() {
  printf '%s\n' "${WFW_AUTO_MAX_ITERATIONS:-15}"
}

auto_write_status() {
  local phase="$1"
  local iter="$2"
  local max="$3"
  local last_tests="$4"
  local message="$5"
  local doing="$6"
  local outcome="${7:-}"
  mkdir -p "$WFW_AUTO_DIR"
  cat >"$WFW_AUTO_DIR/status" <<EOF
phase=$phase
iter=$iter
max=$max
last_tests=$last_tests
message=$message
doing=$doing
outcome=$outcome
EOF
  if [ "${WFW_AUTO_TUI:-0}" != "1" ]; then
    local display_doing="$doing"
    if [ -z "$display_doing" ] && [ "$phase" = "agent" ]; then
      if [ -f "$WFW_AUTO_DIR/doing" ]; then
        display_doing="$(cat "$WFW_AUTO_DIR/doing")"
      else
        display_doing="Agent is naming this try"
      fi
    fi
    echo "wfw auto: iter=${iter}/${max} phase=${phase} tests=${last_tests} ${message} - ${display_doing}" >&2
    if [ -n "$outcome" ]; then
      echo "wfw auto: outcome=${outcome}" >&2
    fi
  fi
}

auto_worktree_is_dirty() {
  local line path
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    path="${line:3}"
    path="${path#\"}"
    path="${path%\"}"
    case "$path" in
      .wfw | .wfw/* | "${ARTIFACT_LINK:-lavish_artifact.html}") continue ;;
    esac
    return 0
  done < <(git status --porcelain=v1 -uall)
  return 1
}

auto_require_clean_worktree() {
  if auto_worktree_is_dirty; then
    cat >&2 <<'EOF'
Error: worktree has uncommitted changes (outside .wfw/).

Commit or stash before wfw auto. The loop reverts failed iterations with git reset.
EOF
    git status --porcelain=v1 -uall >&2 || true
    return 1
  fi
}

extract_yaml_test_cmd() {
  local file="$1"
  awk '
    BEGIN { in_commands=0 }
    /^commands:[[:space:]]*$/ { in_commands=1; next }
    in_commands && /^[^[:space:]]/ { in_commands=0 }
    in_commands && /^[[:space:]]+test:[[:space:]]*/ {
      sub(/^[[:space:]]+test:[[:space:]]*/, "")
      gsub(/^["'\'']|["'\'']$/, "")
      print
      exit
    }
  ' "$file"
}

resolve_auto_test_cmd() {
  local yaml_cmd json_cmd

  if [ -n "${WFW_TEST_CMD:-}" ]; then
    printf '%s\n' "$WFW_TEST_CMD"
    return 0
  fi

  if [ -f .no-mistakes.yaml ]; then
    yaml_cmd="$(extract_yaml_test_cmd .no-mistakes.yaml)"
    if [ -n "$yaml_cmd" ]; then
      printf '%s\n' "$yaml_cmd"
      return 0
    fi
  fi

  if [ -f package.json ] && command -v node >/dev/null 2>&1; then
    json_cmd="$(node -e 'const s=(require("./package.json").scripts||{}); if(s.test) process.stdout.write(String(s.test))' 2>/dev/null || true)"
    if [ -n "$json_cmd" ]; then
      printf '%s\n' "$json_cmd"
      return 0
    fi
  fi

  if [ -f Makefile ] && grep -qE '^test:' Makefile; then
    printf '%s\n' "make test"
    return 0
  fi

  cat >&2 <<'EOF'
Error: no test command found.

wfw auto stops only when the objective is verified by tests.
Set WFW_TEST_CMD, or add commands.test in .no-mistakes.yaml, a package.json test script, or a Makefile test target.
EOF
  return 1
}

auto_write_program() {
  local objective="$1"
  local test_cmd="$2"
  cat >"$WFW_AUTO_DIR/program.md" <<EOF
# wfw auto program

You are inside an autonomous experiment loop modeled on karpathy/autoresearch.
wfw owns keep/revert and the test gate. You own one targeted change per iteration.

## Objective

${objective}

## Evaluation

wfw will run this test command after your turn:

    ${test_cmd}

Lower (fail) is discarded. Passing tests plus a DONE sentinel closes the loop.

## Rules

1. Make exactly one targeted change this iteration. Do not try to finish everything if a smaller step is safer.
2. Prefer adding or updating tests that encode the objective.
3. Do not commit, push, merge, or run git reset / git clean. wfw snapshots and reverts.
4. Read \`.wfw/auto/context.md\` for prior iterations. Do not rewrite it.
5. When you believe the objective is fully implemented and tests will pass, write \`.wfw/auto/DONE\` with a one-line summary.
6. If you are not done, do not write \`.wfw/auto/DONE\`.
7. Stay inside this worktree.
EOF
}

auto_init_context() {
  local objective="$1"
  local test_cmd="$2"
  cat >"$WFW_AUTO_DIR/context.md" <<EOF
# Auto loop context

Objective: ${objective}

Test command: ${test_cmd}

Prior iterations:

EOF
}

auto_files_touched() {
  git status --porcelain=v1 -uall | awk '{
    path=$2
    if ($1 ~ /^R/) path=$4
    if (path ~ /^\.wfw(\/|$)/) next
    if (path == "lavish_artifact.html") next
    if (path != "") print path
  }' | awk 'NR > 1 { printf ", " } { printf "%s", $0 } END { print "" }'
}

auto_excerpt() {
  local file="$1"
  if [ ! -f "$file" ]; then
    printf '%s\n' "(no output)"
    return 0
  fi
  tail -n 20 "$file" | head -c 2000
  echo
}

auto_append_context() {
  local iter="$1"
  local decision="$2"
  local tests_result="$3"
  local files="$4"
  local excerpt="$5"
  local hyp="Agent is naming this try"
  if [ -f "$WFW_AUTO_DIR/doing" ]; then
    hyp="$(cat "$WFW_AUTO_DIR/doing")"
  fi
  {
    echo "## Iteration ${iter}"
    echo ""
    echo "Hypothesis: ${hyp}"
    echo "Decision: ${decision}"
    echo "Tests: ${tests_result}"
    echo "Files: ${files:-none}"
    echo "Excerpt:"
    echo ""
    echo '```'
    printf '%s\n' "$excerpt"
    echo '```'
    echo ""
  } >>"$WFW_AUTO_DIR/context.md"
}

auto_save_snapshot() {
  git add -A
  git reset -q -- .wfw 2>/dev/null || true
  local tree commit
  tree="$(git write-tree)"
  commit="$(
    GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-wfw-auto}" \
      GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-wfw-auto@localhost}" \
      GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-wfw-auto}" \
      GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-wfw-auto@localhost}" \
      git commit-tree "$tree" -p HEAD -m "wfw auto snapshot"
  )"
  git update-ref "$WFW_AUTO_SNAPSHOT_REF" "$commit"
  git reset -q HEAD
}

auto_restore_snapshot() {
  local tree
  if git show-ref --verify --quiet "$WFW_AUTO_SNAPSHOT_REF"; then
    tree="$(git rev-parse "$WFW_AUTO_SNAPSHOT_REF^{tree}")"
    git read-tree -u --reset "$tree"
  else
    git reset --hard HEAD
  fi
  git clean -fd -e .wfw -e .wfw/ >/dev/null 2>&1 || true
  rm -f "$WFW_AUTO_DIR/DONE"
}

auto_build_prompt() {
  local iter="$1"
  local max="$2"
  local objective="$3"
  cat <<EOF
You are iteration ${iter} of ${max} in a wfw auto experiment loop.

First, write a one-sentence hypothesis of what you are about to change into .wfw/auto/doing.

Read these files first (they are the source of truth):
- .wfw/auto/program.md
- .wfw/auto/context.md

Objective:
${objective}

Make exactly one targeted change this iteration, including tests that encode the objective if they are missing.

When the objective is fully implemented and you expect tests to pass, write .wfw/auto/DONE with a one-line summary.
Otherwise do not write DONE.

Do not commit, push, or reset git. wfw will run tests and keep or revert.

--- digest ---
EOF
  awk '
    /^## Iteration / { in_iter=1; hyp=""; decision="" }
    /^Hypothesis:/ { sub(/^Hypothesis:[[:space:]]*/, ""); hyp=$0 }
    /^Decision:/ { sub(/^Decision:[[:space:]]*/, ""); decision=$0 }
    in_iter && decision == "revert" { print "- " hyp; in_iter=0 }
  ' "$WFW_AUTO_DIR/context.md" > "$WFW_AUTO_DIR/reverts.tmp"
  if [ -s "$WFW_AUTO_DIR/reverts.tmp" ]; then
    echo "Reverted hypotheses (do not retry these):"
    cat "$WFW_AUTO_DIR/reverts.tmp"
    echo ""
  fi

  awk '
    /^## Iteration / { n++; rec[n] = $0 "\n"; next }
    n > 0 { rec[n] = rec[n] $0 "\n" }
    END {
      start = n - 2; if (start < 1) start = 1
      if (n > 0) {
        print "Last " (n - start + 1) " iteration records:"
        for (i = start; i <= n; i++) printf "%s", rec[i]
      }
    }
  ' "$WFW_AUTO_DIR/context.md"
}

auto_stop_tui() {
  if [ -n "${WFW_AUTO_TUI_PID:-}" ]; then
    wait "$WFW_AUTO_TUI_PID" 2>/dev/null || true
    WFW_AUTO_TUI_PID=""
  fi
}

auto_cleanup() {
  if [ -n "${WFW_AUTO_AGENT_PID:-}" ]; then
    kill "$WFW_AUTO_AGENT_PID" 2>/dev/null || true
    wait "$WFW_AUTO_AGENT_PID" 2>/dev/null || true
    WFW_AUTO_AGENT_PID=""
  fi
  if [ -n "${WFW_AUTO_TUI_PID:-}" ]; then
    kill "$WFW_AUTO_TUI_PID" 2>/dev/null || true
    wait "$WFW_AUTO_TUI_PID" 2>/dev/null || true
    WFW_AUTO_TUI_PID=""
  fi
  if [ -t 1 ]; then
    printf '\033[?25h'
    tput cnorm 2>/dev/null || true
  fi
}

run_auto_loop() {
  local objective="$1"
  local max iter test_cmd agent_cli prompt_text files excerpt tests_result test_rc agent_rc
  local libdir

  require_cmd git
  auto_require_clean_worktree

  mkdir -p "$WFW_AUTO_DIR"
  append_git_exclude_pattern ".wfw/auto/"

  test_cmd="$(resolve_auto_test_cmd)"
  agent_cli="$(resolve_agent_cli)"
  max="$(auto_max_iterations)"
  libdir="$(auto_lib_dir)"

  auto_write_program "$objective" "$test_cmd"
  auto_init_context "$objective" "$test_cmd"
  auto_save_snapshot
  rm -f "$WFW_AUTO_DIR/DONE"

  echo "wfw auto: objective stored in $WFW_AUTO_DIR/program.md" >&2
  echo "wfw auto: test command: $test_cmd" >&2
  echo "wfw auto: agent: $agent_cli" >&2
  echo "wfw auto: max iterations: $max" >&2

  WFW_AUTO_TUI=0
  WFW_AUTO_TUI_PID=""
  WFW_AUTO_AGENT_PID=""
  trap auto_cleanup EXIT INT TERM

  if [ -t 1 ]; then
    WFW_AUTO_TUI=1
    "$libdir/auto-tui.sh" "$WFW_AUTO_DIR" &
    WFW_AUTO_TUI_PID=$!
  fi

  auto_write_status "starting" "0" "$max" "pending" "loop starting" "Starting the loop" ""

  iter=1
  while [ "$iter" -le "$max" ]; do
    rm -f "$WFW_AUTO_DIR/doing"
    auto_write_status "agent" "$iter" "$max" "${tests_result:-pending}" "agent running" "" ""
    prompt_text="$(auto_build_prompt "$iter" "$max" "$objective")"
    printf '%s\n' "$prompt_text" >"$WFW_AUTO_DIR/prompt.txt"

    set +e
    run_auto_agent_oneshot "$agent_cli" "$prompt_text" >"$WFW_AUTO_DIR/agent.log" 2>&1 &
    WFW_AUTO_AGENT_PID=$!
    wait "$WFW_AUTO_AGENT_PID"
    agent_rc=$?
    set -e
    WFW_AUTO_AGENT_PID=""

    files="$(auto_files_touched || true)"
    auto_write_status "tests" "$iter" "$max" "${tests_result:-pending}" "running tests" "Running the test command" ""

    if [ -z "$files" ] && [ ! -f "$WFW_AUTO_DIR/DONE" ]; then
      # A turn that changed nothing and did not claim DONE is not an experiment.
      # Usually the agent CLI rejected the invocation. Fail now instead of
      # burning the whole cap on silent no-ops.
      auto_write_status "aborted" "$iter" "$max" "pending" "agent made no changes; aborting" "Agent made no changes" "failed"
      auto_stop_tui
      auto_append_context "$iter" "aborted (agent no-op)" "n/a" "" "$(auto_excerpt "$WFW_AUTO_DIR/agent.log")"
      {
        echo "Error: the coding agent made no changes and did not write DONE (iteration ${iter})."
        echo "The agent CLI likely rejected the invocation or its print mode is not wired up."
        echo "Full agent output:"
      } >&2
      cat "$WFW_AUTO_DIR/agent.log" >&2 || true
      trap - EXIT INT TERM
      return 1
    fi

    set +e
    bash -c "$test_cmd" >"$WFW_AUTO_DIR/tests.log" 2>&1
    test_rc=$?
    set -e

    excerpt="$(auto_excerpt "$WFW_AUTO_DIR/tests.log")"
    if [ $test_rc -eq 0 ]; then
      tests_result="pass"
    else
      tests_result="fail"
    fi

    if [ $test_rc -ne 0 ]; then
      auto_restore_snapshot
      auto_append_context "$iter" "revert" "$tests_result" "$files" "$excerpt
agent_exit=${agent_rc}"
      auto_write_status "revert" "$iter" "$max" "$tests_result" "reverted failed iteration" "Rolling back that try" ""
      iter=$((iter + 1))
      continue
    fi

    if [ -f "$WFW_AUTO_DIR/DONE" ]; then
      auto_append_context "$iter" "keep (verified)" "$tests_result" "$files" "$excerpt"
      auto_write_status "done" "$iter" "$max" "$tests_result" "objective verified by tests" "Objective verified" "success"
      auto_stop_tui
      echo "wfw auto: objective verified after ${iter} iteration(s)." >&2
      echo "wfw auto: context: $WFW_AUTO_DIR/context.md" >&2
      trap - EXIT INT TERM
      return 0
    fi

    auto_save_snapshot
    auto_append_context "$iter" "keep" "$tests_result" "$files" "$excerpt"
    auto_write_status "keep" "$iter" "$max" "$tests_result" "kept passing change; continuing" "Checkpointing the tree" ""
    iter=$((iter + 1))
  done

  auto_write_status "failed" "$max" "$max" "${tests_result:-fail}" "max iterations reached" "Max iterations reached" "failed"
  auto_stop_tui
  echo "wfw auto: stopped after ${max} iteration(s) without a verified DONE." >&2
  echo "wfw auto: context: $WFW_AUTO_DIR/context.md" >&2
  trap - EXIT INT TERM
  return 1
}
