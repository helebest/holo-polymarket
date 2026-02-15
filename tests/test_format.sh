#!/bin/bash
#
# 格式化模块单元测试
# 使用 mock 数据测试输出格式

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$PROJECT_DIR/scripts/format.sh"

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        echo "     expected: $expected"
        echo "     actual:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local desc="$1" expected="$2" actual="$3"
    if echo "$actual" | grep -qF "$expected"; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        echo "     expected to contain: $expected"
        echo "     actual: $(echo "$actual" | head -3)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Format Tests ==="
echo ""

# Test 1: format_volume
echo "[Test 1] format_volume"
assert_eq "millions" '$6.6M' "$(format_volume 6600000)"
assert_eq "thousands" '$42.5K' "$(format_volume 42500)"
assert_eq "billions" '$1.2B' "$(format_volume 1200000000)"
assert_eq "small" '$500' "$(format_volume 500)"
assert_eq "null" '$0' "$(format_volume "")"

# Test 2: format_prob
echo "[Test 2] format_prob"
assert_eq "92.5%" "92.5%" "$(format_prob 0.925)"
assert_eq "6.5%" "6.5%" "$(format_prob 0.065)"
assert_eq "0.1%" "0.1%" "$(format_prob 0.001)"
assert_eq "null" "N/A" "$(format_prob "")"

# Test 3: format_hot_events with mock data
echo "[Test 3] format_hot_events"
MOCK_EVENTS='[{
    "title": "Fed decision in March",
    "slug": "fed-decision-in-march-885",
    "volume24hr": 6600000,
    "volume": 109000000,
    "markets": [
        {"groupItemTitle": "No change", "outcomePrices": "[\"0.925\", \"0.075\"]", "volume24hr": 347000},
        {"groupItemTitle": "25 bps decrease", "outcomePrices": "[\"0.065\", \"0.935\"]", "volume24hr": 1078000}
    ]
}]'
OUTPUT=$(echo "$MOCK_EVENTS" | format_hot_events)
assert_contains "shows title" "Fed decision in March" "$OUTPUT"
assert_contains "shows percentage" "92.5%" "$OUTPUT"
assert_contains "shows slug link" "polymarket.com/event/fed-decision-in-march-885" "$OUTPUT"
assert_contains "shows 24h volume" "6.6M" "$OUTPUT"

# Test 4: format_event_detail with mock data
echo "[Test 4] format_event_detail"
MOCK_DETAIL='[{
    "title": "Bitcoin to reach 100K?",
    "slug": "bitcoin-100k",
    "description": "Will Bitcoin reach $100,000?",
    "markets": [
        {"groupItemTitle": "Yes", "question": "Will BTC hit 100K?", "outcomePrices": "[\"0.72\", \"0.28\"]", "volume24hr": 500000},
        {"groupItemTitle": "No", "question": "Will BTC not hit 100K?", "outcomePrices": "[\"0.28\", \"0.72\"]", "volume24hr": 200000}
    ]
}]'
OUTPUT=$(echo "$MOCK_DETAIL" | format_event_detail)
assert_contains "shows title" "Bitcoin to reach 100K?" "$OUTPUT"
assert_contains "shows Yes prob" "72.0%" "$OUTPUT"
assert_contains "shows link" "polymarket.com/event/bitcoin-100k" "$OUTPUT"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
