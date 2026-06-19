#!/bin/bash
#
# Phase 2b format output tests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/helpers/assert.sh"
source "$PROJECT_DIR/skills/polymarket-query/scripts/format.sh"

PASS=0
FAIL=0

echo "=== Phase 2b Format Tests ==="
echo ""

MOCK_PRICE='[
    {"timestamp": 1735689600, "price": 0.45},
    {"timestamp": 1735776000, "price": 0.50},
    {"timestamp": 1735862400, "price": 0.62}
]'

MOCK_VOLUME='[
    {"timestamp": 1735689600, "volume": 1200},
    {"timestamp": 1735776000, "volume": 9800},
    {"timestamp": 1735862400, "volume": 3500000}
]'

# Test 1: format_price_history_table
echo "[Test 1] format_price_history_table - table output"
OUTPUT=$(echo "$MOCK_PRICE" | format_price_history_table)
assert_contains "shows header date" "Date" "$OUTPUT"
assert_contains "shows header price" "Probability" "$OUTPUT"
assert_contains "shows first date" "2025-01-01" "$OUTPUT"
assert_contains "shows first price as percent" "45.0%" "$OUTPUT"
assert_contains "shows last price as percent" "62.0%" "$OUTPUT"

# Test 2: format_trend_summary
echo "[Test 2] format_trend_summary - start/end and change"
OUTPUT=$(echo "$MOCK_PRICE" | format_trend_summary)
assert_contains "shows start" "Start: 45.0%" "$OUTPUT"
assert_contains "shows end" "End: 62.0%" "$OUTPUT"
assert_contains "shows absolute change" "Absolute change: +17.0pp" "$OUTPUT"
assert_contains "shows relative change" "Relative change: +37.8%" "$OUTPUT"

# Test 3: format_volume_trend_table
echo "[Test 3] format_volume_trend_table - volume table"
OUTPUT=$(echo "$MOCK_VOLUME" | format_volume_trend_table)
assert_contains "shows header volume" "Volume" "$OUTPUT"
assert_contains "shows first volume" '$1.2K' "$OUTPUT"
assert_contains "shows last volume" '$3.5M' "$OUTPUT"

# Test 4: empty data handling
echo "[Test 4] empty data handling"
OUTPUT=$(echo '[]' | format_price_history_table)
assert_contains "price empty message" "No historical price data" "$OUTPUT"
OUTPUT=$(echo '[]' | format_trend_summary)
assert_contains "trend empty message" "No trend data" "$OUTPUT"
OUTPUT=$(echo '[]' | format_volume_trend_table)
assert_contains "volume empty message" "No volume data" "$OUTPUT"

# Test 5: invalid input handling
echo "[Test 5] invalid input handling"
OUTPUT=$(echo 'not-json' | format_price_history_table 2>&1)
CODE=$?
assert_status "price invalid returns non-zero" 1 "$CODE"
assert_contains "price invalid message" "Invalid data format" "$OUTPUT"

OUTPUT=$(echo 'not-json' | format_trend_summary 2>&1)
CODE=$?
assert_status "trend invalid returns non-zero" 1 "$CODE"
assert_contains "trend invalid message" "Invalid data format" "$OUTPUT"

OUTPUT=$(echo 'not-json' | format_volume_trend_table 2>&1)
CODE=$?
assert_status "volume invalid returns non-zero" 1 "$CODE"
assert_contains "volume invalid message" "Invalid data format" "$OUTPUT"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]