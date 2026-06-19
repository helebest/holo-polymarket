#!/bin/bash
#
# Static checks for the shell scripts (polymarket-query skill + tests).

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

SHELL_FILES=(
    "$PROJECT_DIR"/skills/polymarket-query/scripts/*.sh
    "$PROJECT_DIR"/tests/*.sh
    "$PROJECT_DIR"/tests/helpers/*.sh
)

status=0

if command -v shellcheck >/dev/null 2>&1; then
    echo "[lint] shellcheck"
    shellcheck "${SHELL_FILES[@]}" || status=1
else
    echo "[lint] shellcheck not installed, skipping"
fi

if command -v shfmt >/dev/null 2>&1; then
    echo "[lint] shfmt -d"
    shfmt -d "${SHELL_FILES[@]}" || status=1
else
    echo "[lint] shfmt not installed, skipping"
fi

exit "$status"
