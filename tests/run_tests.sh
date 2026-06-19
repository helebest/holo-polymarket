#!/bin/bash
#
# Run tests (offline by default; with RUN_LIVE_TESTS=1 also run live integration tests)

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

# Offline tests (always run)
run_test_file "$SCRIPT_DIR/test_format.sh"
run_test_file "$SCRIPT_DIR/test_format_data.sh"
run_test_file "$SCRIPT_DIR/test_cache.sh"
run_test_file "$SCRIPT_DIR/test_history_api.sh"
run_test_file "$SCRIPT_DIR/test_history_format.sh"
run_test_file "$SCRIPT_DIR/test_export.sh"
run_test_file "$SCRIPT_DIR/test_api_unit.sh"
run_test_file "$SCRIPT_DIR/test_series_args.sh"

# Live integration tests (optional)
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