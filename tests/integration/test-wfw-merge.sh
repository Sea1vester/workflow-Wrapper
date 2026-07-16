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

REPO="$TEST_DIR/app"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email "test@example.com"
git -C "$REPO" config user.name "Test"
printf '%s\n' "main" >"$REPO/README.md"
git -C "$REPO" add README.md
git -C "$REPO" commit -q -m init
git -C "$REPO" branch -M main

FEATURE_WT="$TEST_DIR/feature-wt"
git -C "$REPO" worktree add -b feature-a "$FEATURE_WT" -q
printf '%s\n' "feature" >>"$FEATURE_WT/README.md"
git -C "$FEATURE_WT" add README.md
git -C "$FEATURE_WT" commit -q -m "feature change"
ln -sf "$REPO/my_team_workspace/shared_lavish_plan.html" "$FEATURE_WT/lavish_artifact.html" 2>/dev/null || \
  ln -sf /tmp/shared-plan.html "$FEATURE_WT/lavish_artifact.html"

OUT="$(cd "$FEATURE_WT" && WFW_SKIP_WORKTREE_CLEANUP=1 "$WFW_BIN" merge 2>&1)" || fail "wfw merge failed: $OUT"
echo "$OUT" | grep -q 'Merged feature-a into main' || fail "unexpected merge output: $OUT"
grep -qxF 'feature' "$REPO/README.md" || fail "merge did not land on main worktree"
pass "wfw merge lands feature branch on main"

echo ""
echo "All wfw merge checks passed."
