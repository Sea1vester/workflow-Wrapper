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

WT="$TEST_DIR/detached-wt"
git -C "$REPO" worktree add --detach "$WT" main -q
ln -sf /tmp/shared-plan.html "$WT/lavish_artifact.html"
mkdir -p "$WT/.wfw"
printf '%s\n' 'stage1-2' >"$WT/.wfw/lease-holder"
printf '%s\n' 'feature/stage1-2' >"$WT/.wfw/branch"
printf '%s\n' 'feature work' >>"$WT/README.md"
git -C "$WT" add README.md
git -C "$WT" commit -q -m "feature work"

OUT="$(cd "$WT" && WFW_SKIP_WORKTREE_CLEANUP=1 "$WFW_BIN" merge 2>&1)" || fail "wfw merge from detached HEAD failed: $OUT"
echo "$OUT" | grep -q 'Merged feature/stage1-2 into main' || fail "unexpected merge output: $OUT"
grep -qxF 'feature work' "$REPO/README.md" || fail "merge did not land on main"
pass "wfw merge recovers feature branch from detached HEAD via .wfw metadata"

echo ""
echo "All wfw branch checks passed."
