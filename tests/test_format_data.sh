#!/bin/bash
#
# Data API 格式化模块单元测试
# 使用 mock 数据测试 leaderboard / positions / trades 输出格式

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/helpers/assert.sh"
source "$PROJECT_DIR/scripts/format.sh"

PASS=0
FAIL=0

echo "=== Data Format Tests ==="
echo ""

# ==================== Leaderboard ====================

echo "[Test 1] format_leaderboard - basic output"
MOCK_LEADERBOARD='[
    {"rank":"1","userName":"FollowMeABC123","proxyWallet":"0xc257ea7e3a81ca8e16df8935d44d513959fa358e","vol":7995.26,"pnl":81219.14,"profileImage":"","xUsername":"","verifiedBadge":false},
    {"rank":"2","userName":"greatscott44","proxyWallet":"0x5c2bd19cb9bb241f864a057e4b2da6d2a3d62575","vol":102943.98,"pnl":46802.37,"profileImage":"","xUsername":"trader44","verifiedBadge":true},
    {"rank":"3","userName":"bcda","proxyWallet":"0xb45a797faa52b0fd8adc56d30382022b7b12192c","vol":87266.04,"pnl":44910.18,"profileImage":"","xUsername":"","verifiedBadge":false}
]'
OUTPUT=$(echo "$MOCK_LEADERBOARD" | format_leaderboard)
assert_contains "shows rank #1" "#1" "$OUTPUT"
assert_contains "shows username" "FollowMeABC123" "$OUTPUT"
assert_contains "shows PnL" "81219" "$OUTPUT"
assert_contains "shows volume" "7995" "$OUTPUT"
assert_contains "shows rank #3" "#3" "$OUTPUT"
assert_contains "shows third user" "bcda" "$OUTPUT"

echo "[Test 2] format_leaderboard - shows X/Twitter handle when available"
assert_contains "shows X handle" "@trader44" "$OUTPUT"
assert_not_contains "no empty @ for missing X" "@\"\"" "$OUTPUT"

echo "[Test 3] format_leaderboard - shows wallet address (truncated)"
assert_contains "shows truncated wallet" "0xc257…" "$OUTPUT"

echo "[Test 4] format_leaderboard - empty list"
EMPTY_OUTPUT=$(echo '[]' | format_leaderboard)
assert_contains "empty message" "暂无数据" "$EMPTY_OUTPUT"

# ==================== Positions ====================

echo "[Test 5] format_positions - basic output"
MOCK_POSITIONS='[
    {"title":"Will Bitcoin hit 100K?","size":5000.50,"currentValue":4200.00,"cashPnl":1200.50,"percentPnl":28.57,"market":"0xabc123","outcome":"Yes","curPrice":0.84},
    {"title":"Fed rate cut in March","size":3000.00,"currentValue":2850.00,"cashPnl":-150.00,"percentPnl":-5.00,"market":"0xdef456","outcome":"No","curPrice":0.95}
]'
OUTPUT=$(echo "$MOCK_POSITIONS" | format_positions)
assert_contains "shows market title" "Bitcoin hit 100K" "$OUTPUT"
assert_contains "shows outcome" "Yes" "$OUTPUT"
assert_contains "shows PnL positive" "1200" "$OUTPUT"
assert_contains "shows size" "5000" "$OUTPUT"
assert_contains "shows negative PnL" "\$150" "$OUTPUT"

echo "[Test 6] format_positions - shows profit/loss indicators"
assert_contains "profit indicator" "📈" "$OUTPUT"
assert_contains "loss indicator" "📉" "$OUTPUT"

echo "[Test 7] format_positions - empty positions"
EMPTY_OUTPUT=$(echo '[]' | format_positions)
assert_contains "empty message" "暂无持仓" "$EMPTY_OUTPUT"

# ==================== Trades ====================

echo "[Test 8] format_trades - basic output"
MOCK_TRADES='[
    {"title":"Bitcoin to 100K?","side":"BUY","size":500.00,"price":0.72,"timestamp":1739577600,"outcome":"Yes"},
    {"title":"ETH reaches 5K","side":"SELL","size":300.00,"price":0.45,"timestamp":1739491200,"outcome":"No"}
]'
OUTPUT=$(echo "$MOCK_TRADES" | format_trades)
assert_contains "shows trade title" "Bitcoin to 100K" "$OUTPUT"
assert_contains "shows BUY side" "买入" "$OUTPUT"
assert_contains "shows SELL side" "卖出" "$OUTPUT"
assert_contains "shows price" "0.72" "$OUTPUT"
assert_contains "shows size" "500" "$OUTPUT"

echo "[Test 9] format_trades - empty trades"
EMPTY_OUTPUT=$(echo '[]' | format_trades)
assert_contains "empty message" "暂无交易" "$EMPTY_OUTPUT"

echo "[Test 10] format_trades - shows time with hours"
assert_contains "shows date" "2025" "$OUTPUT"
assert_contains "shows UTC time" "UTC" "$OUTPUT"

# ==================== format_pnl helper ====================

echo "[Test 11] format_pnl - positive/negative/zero"
assert_eq "positive PnL" "+\$1,234.56" "$(format_pnl 1234.56)"
assert_eq "negative PnL" "-\$567.89" "$(format_pnl -567.89)"
assert_eq "zero PnL" "\$0.00" "$(format_pnl 0)"

echo "[Test 12] format_pnl - large numbers"
assert_eq "large positive" "+\$81,219.14" "$(format_pnl 81219.14)"
assert_eq "large negative" "-\$236,057.46" "$(format_pnl -236057.456)"

# ==================== format_address helper ====================

echo "[Test 13] format_address - truncation"
assert_eq "truncated address" "0xc257…358e" "$(format_address 0xc257ea7e3a81ca8e16df8935d44d513959fa358e)"
assert_eq "short input" "0xabc" "$(format_address 0xabc)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]