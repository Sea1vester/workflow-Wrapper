#!/usr/bin/env bash
# Unit-style checks for wfw plan open/poll/reply sequencing (mocked lavish-axi).
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

MOCK_BIN="$TEST_DIR/mock-bin"
mkdir -p "$MOCK_BIN"
cat >"$MOCK_BIN/npx" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-y" ] && [ "$2" = "lavish-axi" ]; then
  if [ "$3" = "poll" ]; then
    if [ "${5:-}" = "--agent-reply" ]; then
      echo "LAVISH_AXI_POLL_REPLY=$4"
      exit 0
    fi
    echo "LAVISH_AXI_POLL=$4"
    exit 0
  fi
  echo "LAVISH_AXI_ARTIFACT=$3"
  exit 0
fi
echo "mock npx: unexpected args: $*" >&2
exit 1
EOF
chmod +x "$MOCK_BIN/npx"

WORKDIR="$TEST_DIR/worktree"
mkdir -p "$WORKDIR/.lavish"
printf '%s\n' '<!DOCTYPE html><html><body>plan</body></html>' >"$WORKDIR/.lavish/plan.html"

run_wfw() {
  (cd "$WORKDIR" && PATH="$MOCK_BIN:$PATH" "$WFW_BIN" "$@")
}

PLAN_OUT="$(run_wfw plan 2>&1)" || fail "wfw plan failed: $PLAN_OUT"
echo "$PLAN_OUT" | grep -q 'LAVISH_AXI_ARTIFACT=.lavish/plan.html' || fail "expected open: $PLAN_OUT"
echo "$PLAN_OUT" | grep -q 'listening for Lavish feedback' || fail "expected listen banner: $PLAN_OUT"
echo "$PLAN_OUT" | grep -q 'LAVISH_AXI_POLL=.lavish/plan.html' || fail "expected poll: $PLAN_OUT"
pass "wfw plan opens and polls"

PROMPT_OUT="$(run_wfw plan "oauth flow" 2>&1)" || fail "wfw plan with prompt failed: $PROMPT_OUT"
echo "$PROMPT_OUT" | grep -q 'Prompt queued in .wfw/last-prompt.txt' || fail "expected queued prompt: $PROMPT_OUT"
echo "$PROMPT_OUT" | grep -q 'LAVISH_AXI_POLL=' && fail "prompt plan should not poll yet: $PROMPT_OUT"
[ -f "$WORKDIR/.wfw/last-prompt.txt" ] || fail "missing queued prompt file"
grep -qxF 'oauth flow' "$WORKDIR/.wfw/last-prompt.txt" || fail "prompt file contents wrong"
pass "wfw plan <prompt> queues only (no poll before agent builds HTML)"

REPLY_OUT="$(run_wfw plan --reply "Updated auth section" 2>&1)" || fail "wfw plan --reply failed: $REPLY_OUT"
echo "$REPLY_OUT" | grep -q 'listening for Lavish feedback' || fail "expected listen banner on reply: $REPLY_OUT"
echo "$REPLY_OUT" | grep -q 'LAVISH_AXI_POLL=.lavish/plan.html' || fail "expected follow-up poll: $REPLY_OUT"
pass "wfw plan --reply posts agent reply and listens again"

echo ""
echo "All wfw plan poll sequencing checks passed."
