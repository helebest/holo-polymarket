#!/bin/bash
#
# API 模块单元测试
# 测试 Gamma API 请求和响应解析

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$PROJECT_DIR/scripts/api.sh"

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

assert_not_empty() {
    local desc="$1" actual="$2"
    if [ -n "$actual" ] && [ "$actual" != "null" ] && [ "$actual" != "[]" ]; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc (empty or null)"
        FAIL=$((FAIL + 1))
    fi
}

assert_gt() {
    local desc="$1" value="$2" min="$3"
    # Handle both integers and floats
    local result
    result=$(awk "BEGIN { print ($value > $min) ? 1 : 0 }" 2>/dev/null)
    if [ "$result" = "1" ]; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc (value=$value, expected > $min)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== API Tests ==="
echo ""

# Test 1: fetch_hot_events returns valid JSON array
echo "[Test 1] fetch_hot_events returns valid JSON"
RESULT=$(fetch_hot_events 2)
IS_ARRAY=$(echo "$RESULT" | jq 'type' 2>/dev/null)
assert_eq "response is JSON array" '"array"' "$IS_ARRAY"

# Test 2: hot events have expected fields
echo "[Test 2] hot events have required fields"
TITLE=$(echo "$RESULT" | jq -r '.[0].title // empty')
assert_not_empty "first event has title" "$TITLE"
SLUG=$(echo "$RESULT" | jq -r '.[0].slug // empty')
assert_not_empty "first event has slug" "$SLUG"
MARKETS=$(echo "$RESULT" | jq '.[0].markets | length')
assert_gt "first event has markets" "$MARKETS" 0

# Test 3: markets have outcomePrices
echo "[Test 3] markets have outcomePrices"
PRICES=$(echo "$RESULT" | jq -r '.[0].markets[0].outcomePrices // empty')
assert_not_empty "first market has outcomePrices" "$PRICES"

# Test 4: search_events returns results
echo "[Test 4] search_events returns results"
SEARCH=$(search_events "bitcoin" 2)
SEARCH_LEN=$(echo "$SEARCH" | jq 'length' 2>/dev/null)
assert_gt "search for 'bitcoin' returns results" "${SEARCH_LEN:-0}" 0

# Test 5: fetch_event_detail returns data
echo "[Test 5] fetch_event_detail returns data"
DETAIL=$(fetch_event_detail "fed-decision-in-march-885")
DETAIL_TITLE=$(echo "$DETAIL" | jq -r '.[0].title // empty')
assert_not_empty "detail has title" "$DETAIL_TITLE"

# Test 6: event detail has markets with prices
echo "[Test 6] event detail markets have prices"
DETAIL_MARKETS=$(echo "$DETAIL" | jq '.[0].markets | length')
assert_gt "detail has markets" "$DETAIL_MARKETS" 0
DETAIL_PRICE=$(echo "$DETAIL" | jq -r '.[0].markets[0].outcomePrices // empty')
assert_not_empty "detail market has prices" "$DETAIL_PRICE"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
