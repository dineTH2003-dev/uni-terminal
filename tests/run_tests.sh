#!/usr/bin/env bash
# tests/run_tests.sh — Run the UniShell BATS test suite.
#
# Usage:
#   ./tests/run_tests.sh           Run all tests
#   ./tests/run_tests.sh --tap     TAP output (for CI)
#
# Installs BATS automatically if not found (requires apt or brew).

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Ensure bats is available ─────────────────────────────────────────────────
if ! command -v bats >/dev/null 2>&1; then
  echo "[INFO] bats not found — attempting to install..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y bats
  elif command -v brew >/dev/null 2>&1; then
    brew install bats-core
  else
    echo "[ERR]  Install bats manually: https://bats-core.readthedocs.io"
    exit 1
  fi
fi

echo ""
echo "  UniShell Test Suite"
echo "  ═══════════════════"
echo ""

bats "$@" "$REPO_ROOT/tests/"*.bats
