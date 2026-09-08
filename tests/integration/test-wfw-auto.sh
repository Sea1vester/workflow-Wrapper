#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WFW_BIN="$ROOT/bin/hack-wrap.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

setup_worktree() {
  local workdir="$1"
  mkdir -p "$workdir"
  git -C "$workdir" init -q
  git -C "$workdir" config user.email test@wfw.local
  git -C "$workdir" config user.name wfw-test
  git -C "$workdir" commit --allow-empty -m init -q
  ln -sf /tmp/shared-plan.html "$workdir/lavish_artifact.html"
}

# --- wfw gnhf is a hard error ---
set +e
GNHF_OUT="$("$WFW_BIN" gnhf "fix the tests" 2>&1)"
GNHF_RC=$?
set -e
[ "$GNHF_RC" -ne 0 ] || fail "wfw gnhf should fail: $GNHF_OUT"
printf '%s\n' "$GNHF_OUT" | grep -q 'gnhf is removed' || fail "wfw gnhf should mention removal: $GNHF_OUT"
pass "wfw gnhf errors with replacement message"

# --- dirty worktree aborts ---
DIRTY="$TEST_DIR/dirty"
setup_worktree "$DIRTY"
echo dirty >"$DIRTY/extra.txt"
set +e
DIRTY_OUT="$(cd "$DIRTY" && WFW_TEST_CMD="true" WFW_AGENT_CLI="true" "$WFW_BIN" auto "should not start" 2>&1)"
DIRTY_RC=$?
set -e
[ "$DIRTY_RC" -ne 0 ] || fail "dirty worktree should fail: $DIRTY_OUT"
printf '%s\n' "$DIRTY_OUT" | grep -qi 'uncommitted' || fail "dirty worktree should mention uncommitted: $DIRTY_OUT"
pass "wfw auto rejects a dirty worktree"

# --- missing test command ---
NOTEST="$TEST_DIR/notest"
setup_worktree "$NOTEST"
MOCK_BIN="$TEST_DIR/mock-bin"
mkdir -p "$MOCK_BIN"
cat >"$MOCK_BIN/fake-agent" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$MOCK_BIN/fake-agent"
set +e
NOTEST_OUT="$(cd "$NOTEST" && PATH="$MOCK_BIN:$PATH" WFW_AGENT_CLI=fake-agent "$WFW_BIN" auto "no tests" 2>&1)"
NOTEST_RC=$?
set -e
[ "$NOTEST_RC" -ne 0 ] || fail "missing test command should fail: $NOTEST_OUT"
printf '%s\n' "$NOTEST_OUT" | grep -q 'WFW_TEST_CMD' || fail "missing tests should mention WFW_TEST_CMD: $NOTEST_OUT"
pass "wfw auto errors when no test command is configured"

# --- two-iteration keep/revert then DONE+tests ---
WORK="$TEST_DIR/loop"
setup_worktree "$WORK"
CALLS="$TEST_DIR/agent-calls"
REVERT_CHECK="$TEST_DIR/revert-check"
: >"$CALLS"

cat >"$MOCK_BIN/fake-agent" <<EOF
#!/usr/bin/env bash
n=\$(( \$(cat "$CALLS" 2>/dev/null || echo 0) + 1 ))
echo "\$n" >"$CALLS"
if [ "\$n" -eq 1 ]; then
  echo bad >feature.txt
  exit 0
fi
if [ -f feature.txt ] && grep -q bad feature.txt; then
  echo REVERT_FAILED >"$REVERT_CHECK"
  exit 1
fi
echo good >feature.txt
mkdir -p .wfw/auto
echo implemented >.wfw/auto/DONE
exit 0
EOF
chmod +x "$MOCK_BIN/fake-agent"

cat >"$TEST_DIR/run-tests.sh" <<'EOF'
#!/usr/bin/env bash
if grep -q good feature.txt 2>/dev/null; then
  exit 0
fi
exit 1
EOF
chmod +x "$TEST_DIR/run-tests.sh"

set +e
LOOP_OUT="$(
  cd "$WORK" && PATH="$MOCK_BIN:$PATH" \
    WFW_AGENT_CLI=fake-agent \
    WFW_TEST_CMD="$TEST_DIR/run-tests.sh" \
    WFW_AUTO_MAX_ITERATIONS=4 \
    "$WFW_BIN" auto "make feature.txt say good" 2>&1
)"
LOOP_RC=$?
set -e

[ "$LOOP_RC" -eq 0 ] || fail "auto loop should succeed: $LOOP_OUT"
[ ! -f "$REVERT_CHECK" ] || fail "iteration 1 was not reverted"
[ "$(cat "$CALLS")" = "2" ] || fail "expected 2 agent calls, got $(cat "$CALLS"): $LOOP_OUT"
grep -q good "$WORK/feature.txt" || fail "kept change missing: $LOOP_OUT"
grep -q "Iteration 1" "$WORK/.wfw/auto/context.md" || fail "context missing iteration 1"
grep -q "revert" "$WORK/.wfw/auto/context.md" || fail "context missing revert"
grep -q "Iteration 2" "$WORK/.wfw/auto/context.md" || fail "context missing iteration 2"
grep -q "keep (verified)" "$WORK/.wfw/auto/context.md" || fail "context missing verified keep"
grep -q "objective verified" <<<"$LOOP_OUT" || fail "success message missing: $LOOP_OUT"
pass "wfw auto reverts a failing iteration, keeps a verified one, and stops"

echo ""
echo "All wfw auto checks passed."
