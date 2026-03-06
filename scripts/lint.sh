#!/bin/bash
#
# Static checks for shell scripts.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

status=0

if command -v shellcheck >/dev/null 2>&1; then
    echo "[lint] shellcheck"
    shellcheck "$PROJECT_DIR"/scripts/*.sh "$PROJECT_DIR"/tests/*.sh "$PROJECT_DIR"/tests/helpers/*.sh || status=1
else
    echo "[lint] shellcheck 未安装，跳过"
fi

if command -v shfmt >/dev/null 2>&1; then
    echo "[lint] shfmt -d"
    shfmt -d "$PROJECT_DIR"/scripts/*.sh "$PROJECT_DIR"/tests/*.sh "$PROJECT_DIR"/tests/helpers/*.sh || status=1
else
    echo "[lint] shfmt 未安装，跳过"
fi

exit "$status"