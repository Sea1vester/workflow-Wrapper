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

MOCK_BIN="$TEST_DIR/mock-bin"
mkdir -p "$MOCK_BIN"
cat >"$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "MOCK_AGENT_CLI=claude PWD=$PWD ARGS=$*"
EOF
chmod +x "$MOCK_BIN/claude"

WORKDIR="$TEST_DIR/worktree"
mkdir -p "$WORKDIR"
git -C "$WORKDIR" init -q
git -C "$WORKDIR" commit --allow-empty -m init -q
ln -sf /tmp/shared-plan.html "$WORKDIR/lavish_artifact.html"

OUT="$(cd "$WORKDIR" && PATH="$MOCK_BIN:$PATH" WFW_AGENT_CLI=claude "$WFW_BIN" agent 2>&1)" || fail "wfw agent failed: $OUT"
echo "$OUT" | grep -q 'MOCK_AGENT_CLI=claude' || fail "agent CLI not launched: $OUT"
echo "$OUT" | grep -q 'worktree' || fail "agent not launched in worktree: $OUT"
pass "wfw agent execs detected CLI inside leased worktree"

echo ""
echo "All wfw agent checks passed."
