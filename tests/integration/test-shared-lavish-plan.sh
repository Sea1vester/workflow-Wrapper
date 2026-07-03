#!/usr/bin/env bash
# Integration test: shared Lavish plan across parallel treehouse leases.
# Requires: repo bin/hack-wrap.sh, treehouse on PATH, git.
# Skips gracefully when treehouse is unavailable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WFW_BIN="$REPO_ROOT/bin/hack-wrap.sh"

if [ ! -x "$WFW_BIN" ]; then
  echo "SKIP: $WFW_BIN not found or not executable"
  exit 0
fi

if ! command -v treehouse >/dev/null 2>&1; then
  echo "SKIP: treehouse not on PATH (cannot run in CI without treehouse)"
  exit 0
fi

TEST_DIR=""
WORKTREE_A=""
WORKTREE_B=""
WORKTREE_SUB=""

cleanup() {
  if [ -n "${WORKTREE_A:-}" ]; then
    treehouse return "$WORKTREE_A" >/dev/null 2>&1 || true
  fi
  if [ -n "${WORKTREE_B:-}" ] && [ "$WORKTREE_B" != "$WORKTREE_A" ]; then
    treehouse return "$WORKTREE_B" >/dev/null 2>&1 || true
  fi
  if [ -n "${WORKTREE_SUB:-}" ] && [ "$WORKTREE_SUB" != "$WORKTREE_A" ] && [ "$WORKTREE_SUB" != "$WORKTREE_B" ]; then
    treehouse return "$WORKTREE_SUB" >/dev/null 2>&1 || true
  fi
  if [ -n "${TEST_DIR:-}" ] && [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

canonical_path() {
  local path="$1"
  local dir base
  dir="$(dirname "$path")"
  base="$(basename "$path")"
  printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
}

parse_worktree() {
  sed -n 's/^Ready in worktree: //p'
}

TEST_DIR="$(mktemp -d)"
cd "$TEST_DIR"

git init -q
git config user.email "wfw-test@example.com"
git config user.name "wfw-test"
echo "fixture" >README.md
git add README.md
git commit -q -m "init test repo"

OUT_A="$("$WFW_BIN" start feature-a 2>&1)" || fail "wfw start feature-a failed: $OUT_A"
OUT_B="$("$WFW_BIN" start feature-b 2>&1)" || fail "wfw start feature-b failed: $OUT_B"

SHARED_PLAN="$(canonical_path "$TEST_DIR/my_team_workspace/shared_lavish_plan.html")"

[ -f "$TEST_DIR/treehouse.toml" ] || fail "treehouse.toml missing at repo root"
[ ! -f "$TEST_DIR/my_team_workspace/treehouse.toml" ] || fail "treehouse.toml should not be under my_team_workspace"
pass "treehouse.toml at repo root only"

WORKTREE_A="$(printf '%s\n' "$OUT_A" | parse_worktree)"
WORKTREE_B="$(printf '%s\n' "$OUT_B" | parse_worktree)"

[ -n "$WORKTREE_A" ] || fail "could not parse worktree path for feature-a"
[ -n "$WORKTREE_B" ] || fail "could not parse worktree path for feature-b"
[ "$WORKTREE_A" != "$WORKTREE_B" ] || fail "feature-a and feature-b leased the same worktree"
pass "two distinct leased worktrees"

LINK_A="$(canonical_path "$(readlink "$WORKTREE_A/lavish_artifact.html")")"
LINK_B="$(canonical_path "$(readlink "$WORKTREE_B/lavish_artifact.html")")"
[ -n "$LINK_A" ] && [ -L "$WORKTREE_A/lavish_artifact.html" ] || fail "lavish_artifact.html missing or not a symlink in feature-a"
[ -n "$LINK_B" ] && [ -L "$WORKTREE_B/lavish_artifact.html" ] || fail "lavish_artifact.html missing or not a symlink in feature-b"
[ "$LINK_A" = "$LINK_B" ] || fail "symlinks differ: $LINK_A vs $LINK_B"
[ "$LINK_A" = "$SHARED_PLAN" ] || fail "symlink target is not shared plan: $LINK_A"
pass "both symlinks point to $SHARED_PLAN"

MARKER="wfw-shared-plan-marker-$(date +%s)-$$"
printf '%s\n' "$MARKER" >>"$WORKTREE_A/lavish_artifact.html"
grep -qxF "$MARKER" "$WORKTREE_B/lavish_artifact.html" || fail "edit in feature-a not visible in feature-b"
grep -qxF "$MARKER" "$SHARED_PLAN" || fail "edit did not reach shared_lavish_plan.html"
pass "edits via one worktree symlink are visible in the other"

ROOT_EXCLUDE="$(git -C "$TEST_DIR" rev-parse --git-dir)/info/exclude"
grep -qxF "my_team_workspace/shared_lavish_plan.html" "$ROOT_EXCLUDE" || fail "shared plan not in repo-root exclude: $ROOT_EXCLUDE"
[ -z "$(git -C "$TEST_DIR" ls-files my_team_workspace/shared_lavish_plan.html)" ] || fail "shared plan is tracked at repo root"
pass "shared_lavish_plan.html excluded from git at repo root"

SUBDIR_OUT="$(mkdir -p "$TEST_DIR/subdir" && cd "$TEST_DIR/subdir" && "$WFW_BIN" start feature-subdir 2>&1)" || fail "wfw start from subdirectory failed: $SUBDIR_OUT"
WORKTREE_SUB="$(printf '%s\n' "$SUBDIR_OUT" | parse_worktree)"
LINK_SUB="$(canonical_path "$(readlink "$WORKTREE_SUB/lavish_artifact.html")")"
[ "$LINK_SUB" = "$SHARED_PLAN" ] || fail "subdirectory start symlink wrong: $LINK_SUB"
pass "wfw start from subdirectory still symlinks to shared plan"

BROKEN_LINK="$WORKTREE_A/lavish_artifact.html"
rm -f "$BROKEN_LINK"
ln -s /tmp/wrong-target "$BROKEN_LINK"
REPAIR_OUT="$(cd "$TEST_DIR" && "$WFW_BIN" start feature-a 2>&1)" || fail "wfw start repair failed: $REPAIR_OUT"
WORKTREE_A="$(printf '%s\n' "$REPAIR_OUT" | parse_worktree)"
REPAIRED="$(canonical_path "$(readlink "$WORKTREE_A/lavish_artifact.html")")"
[ "$REPAIRED" = "$SHARED_PLAN" ] || fail "stale symlink not repaired: $REPAIRED"
pass "wfw start repairs stale lavish_artifact.html symlink"

for wt in "$WORKTREE_A" "$WORKTREE_B"; do
  exclude_file="$(git -C "$wt" rev-parse --git-dir)/info/exclude"
  grep -qxF "lavish_artifact.html" "$exclude_file" || fail "lavish_artifact.html not in $exclude_file"
  [ -z "$(git -C "$wt" ls-files lavish_artifact.html)" ] || fail "lavish_artifact.html is tracked by git in $wt"
done
pass "lavish_artifact.html excluded from git in both worktrees"

MOCK_BIN="$TEST_DIR/mock-bin"
mkdir -p "$MOCK_BIN"
cat >"$MOCK_BIN/npx" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-y" ] && [ "$2" = "lavish-axi" ]; then
  echo "LAVISH_AXI_ARTIFACT=$3"
  exit 0
fi
echo "mock npx: unexpected args: $*" >&2
exit 1
EOF
chmod +x "$MOCK_BIN/npx"

PLAN_OUT="$(cd "$WORKTREE_A" && PATH="$MOCK_BIN:$PATH" "$WFW_BIN" plan 2>&1)" || fail "wfw plan failed: $PLAN_OUT"
echo "$PLAN_OUT" | grep -q 'LAVISH_AXI_ARTIFACT=lavish_artifact.html' || fail "wfw plan did not open lavish_artifact.html: $PLAN_OUT"
pass "wfw plan opens lavish-axi against worktree symlink"

echo ""
echo "All shared Lavish plan integration checks passed."
