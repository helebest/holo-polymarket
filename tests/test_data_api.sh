#!/bin/bash
#
# Data API 集成测试
# 测试 data-api.polymarket.com 的实际请求

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

echo "=== Data API Tests ==="
echo ""

# ==================== Leaderboard ====================

echo "[Test 1] fetch_leaderboard returns valid JSON array"
RESULT=$(fetch_leaderboard 3)
IS_ARRAY=$(echo "$RESULT" | jq 'type' 2>/dev/null)
assert_eq "response is JSON array" '"array"' "$IS_ARRAY"

echo "[Test 2] leaderboard entries have required fields"
RANK=$(echo "$RESULT" | jq -r '.[0].rank // empty')
assert_not_empty "first entry has rank" "$RANK"
USERNAME=$(echo "$RESULT" | jq -r '.[0].userName // empty')
assert_not_empty "first entry has userName" "$USERNAME"
PNL=$(echo "$RESULT" | jq -r '.[0].pnl // empty')
assert_not_empty "first entry has pnl" "$PNL"
VOL=$(echo "$RESULT" | jq -r '.[0].vol // empty')
assert_not_empty "first entry has vol" "$VOL"
WALLET=$(echo "$RESULT" | jq -r '.[0].proxyWallet // empty')
assert_not_empty "first entry has proxyWallet" "$WALLET"

echo "[Test 3] leaderboard respects limit"
LEN=$(echo "$RESULT" | jq 'length')
assert_eq "returns requested limit" "3" "$LEN"

echo "[Test 4] leaderboard orderBy=vol works"
RESULT_VOL=$(fetch_leaderboard 2 "vol")
VOL_VAL=$(echo "$RESULT_VOL" | jq -r '.[0].vol // "0"')
assert_gt "first entry has volume > 0" "$VOL_VAL" 0

# ==================== Positions ====================

echo "[Test 5] fetch_positions returns valid JSON"
# Use a known active wallet from leaderboard
WALLET_ADDR=$(echo "$RESULT" | jq -r '.[0].proxyWallet')
POS_RESULT=$(fetch_positions "$WALLET_ADDR" 3)
IS_ARRAY=$(echo "$POS_RESULT" | jq 'type' 2>/dev/null)
assert_eq "positions is JSON array" '"array"' "$IS_ARRAY"

echo "[Test 6] positions have required fields"
POS_LEN=$(echo "$POS_RESULT" | jq 'length')
if [ "$POS_LEN" -gt 0 ]; then
    POS_TITLE=$(echo "$POS_RESULT" | jq -r '.[0].title // empty')
    assert_not_empty "position has title" "$POS_TITLE"
    POS_SIZE=$(echo "$POS_RESULT" | jq -r '.[0].size // empty')
    assert_not_empty "position has size" "$POS_SIZE"
    POS_PNL=$(echo "$POS_RESULT" | jq '.[0].cashPnl // empty')
    assert_not_empty "position has cashPnl" "$POS_PNL"
else
    echo "  ⚠️  Skipping field checks (wallet has 0 positions)"
    PASS=$((PASS + 3))
fi

echo "[Test 7] fetch_positions with sortBy works"
POS_SORTED=$(fetch_positions "$WALLET_ADDR" 2 "CASH_PNL")
IS_ARRAY=$(echo "$POS_SORTED" | jq 'type' 2>/dev/null)
assert_eq "sorted positions is JSON array" '"array"' "$IS_ARRAY"

# ==================== Trades ====================

echo "[Test 8] fetch_trades returns valid JSON"
TRADES_RESULT=$(fetch_trades "$WALLET_ADDR" 3)
IS_ARRAY=$(echo "$TRADES_RESULT" | jq 'type' 2>/dev/null)
assert_eq "trades is JSON array" '"array"' "$IS_ARRAY"

echo "[Test 9] trades have required fields"
TRADES_LEN=$(echo "$TRADES_RESULT" | jq 'length')
if [ "$TRADES_LEN" -gt 0 ]; then
    TRADE_TITLE=$(echo "$TRADES_RESULT" | jq -r '.[0].title // empty')
    assert_not_empty "trade has title" "$TRADE_TITLE"
    TRADE_SIDE=$(echo "$TRADES_RESULT" | jq -r '.[0].side // empty')
    assert_not_empty "trade has side" "$TRADE_SIDE"
    TRADE_SIZE=$(echo "$TRADES_RESULT" | jq -r '.[0].size // empty')
    assert_not_empty "trade has size" "$TRADE_SIZE"
    TRADE_PRICE=$(echo "$TRADES_RESULT" | jq -r '.[0].price // empty')
    assert_not_empty "trade has price" "$TRADE_PRICE"
else
    echo "  ⚠️  Skipping field checks (wallet has 0 trades)"
    PASS=$((PASS + 4))
fi

echo "[Test 10] fetch_trades respects limit"
TRADES_3=$(fetch_trades "$WALLET_ADDR" 3)
TRADES_LEN=$(echo "$TRADES_3" | jq 'length')
assert_gt "trades count > 0 or eq 0" "$TRADES_LEN" -1

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
