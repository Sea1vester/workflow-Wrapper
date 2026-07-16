#!/usr/bin/env bash
# wfw validate must not crash when WFW_NO_MISTAKES_SKIP is empty (bash set -u + empty arrays).
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
cat >"$MOCK_BIN/git" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "push" ]; then
  echo "MOCK_GIT_PUSH=$*"
  exit 0
fi
if [ "$1" = "rev-parse" ]; then
  echo ".git"
  exit 0
fi
if [ "$1" = "diff" ]; then
  exit 0
fi
exec /usr/bin/git "$@" 2>/dev/null || exit 0
EOF
chmod +x "$MOCK_BIN/git"

WORKDIR="$TEST_DIR/worktree"
mkdir -p "$WORKDIR"
ln -sf /tmp/shared-plan.html "$WORKDIR/lavish_artifact.html"

OUT="$(cd "$WORKDIR" && PATH="$MOCK_BIN:$PATH" WFW_NO_MISTAKES_SKIP= WFW_SKIP_WORKTREE_CLEANUP=1 "$WFW_BIN" validate 2>&1)" \
  || fail "wfw validate failed with empty WFW_NO_MISTAKES_SKIP: $OUT"
echo "$OUT" | grep -q 'MOCK_GIT_PUSH=push no-mistakes HEAD' || fail "unexpected push: $OUT"
echo "$OUT" | grep -q 'no-mistakes.skip' && fail "skip option should be omitted when unset: $OUT"
pass "wfw validate works when WFW_NO_MISTAKES_SKIP is empty"

echo ""
echo "All wfw validate checks passed."
