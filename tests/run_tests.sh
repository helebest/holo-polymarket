#!/bin/bash
#
# 运行所有测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOTAL_PASS=0
TOTAL_FAIL=0

run_test_file() {
    local file="$1"
    echo ""
    bash "$file"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    else
        TOTAL_PASS=$((TOTAL_PASS + 1))
    fi
}

echo "🧪 Running Holo Polymarket Tests"
echo "================================="

run_test_file "$SCRIPT_DIR/test_format.sh"
run_test_file "$SCRIPT_DIR/test_format_data.sh"
run_test_file "$SCRIPT_DIR/test_api.sh"
run_test_file "$SCRIPT_DIR/test_data_api.sh"
run_test_file "$SCRIPT_DIR/test_phase2b_api.sh"

echo ""
echo "================================="
echo "📋 Test Suites: $TOTAL_PASS passed, $TOTAL_FAIL failed"

if [ $TOTAL_FAIL -gt 0 ]; then
    exit 1
fi
echo "✅ All tests passed!"
