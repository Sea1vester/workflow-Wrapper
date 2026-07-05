#!/usr/bin/env bash
# Point this repo at version-controlled git hooks (strips Cursor co-author trailers).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

chmod +x "$ROOT/.githooks/prepare-commit-msg"
git -C "$ROOT" config core.hooksPath .githooks

echo "Git hooks enabled for $(basename "$ROOT"):"
echo "  core.hooksPath = .githooks"
echo "  prepare-commit-msg strips Cursor commit attribution trailers"
