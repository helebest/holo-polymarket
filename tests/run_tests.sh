#!/bin/bash
#
# 运行测试（默认离线；RUN_LIVE_TESTS=1 时追加在线集成测试）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOTAL_PASS=0
TOTAL_FAIL=0

run_test_file() {
    local file="$1"
    echo ""
    bash "$file"
    local exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    else
        TOTAL_PASS=$((TOTAL_PASS + 1))
    fi
}

echo "🧪 Running Holo Polymarket Tests"
echo "================================="
echo "Mode: offline"

# 离线测试（必跑）
run_test_file "$SCRIPT_DIR/test_format.sh"
run_test_file "$SCRIPT_DIR/test_format_data.sh"
run_test_file "$SCRIPT_DIR/test_cache.sh"
run_test_file "$SCRIPT_DIR/test_history_api.sh"
run_test_file "$SCRIPT_DIR/test_history_format.sh"
run_test_file "$SCRIPT_DIR/test_export.sh"
run_test_file "$SCRIPT_DIR/test_api_unit.sh"
run_test_file "$SCRIPT_DIR/test_series_args.sh"

# 在线集成测试（可选）
if [ "${RUN_LIVE_TESTS:-0}" = "1" ]; then
    echo ""
    echo "Mode: live API"
    run_test_file "$SCRIPT_DIR/test_api.sh"
    run_test_file "$SCRIPT_DIR/test_data_api.sh"
fi

echo ""
echo "================================="
echo "📋 Test Suites: $TOTAL_PASS passed, $TOTAL_FAIL failed"

if [ "$TOTAL_FAIL" -gt 0 ]; then
    exit 1
fi

echo "✅ All tests passed!"