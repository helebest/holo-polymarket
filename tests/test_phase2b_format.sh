#!/bin/bash
#
# Phase 2b 格式化输出测试

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
    if printf '%s' "$actual" | grep -Fq "$expected"; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        echo "     expected to contain: $expected"
        echo "     actual: $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_status() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" -eq "$actual" ]; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        echo "     expected status: $expected"
        echo "     actual status:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

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
echo "[Test 1] format_price_history_table - 表格输出"
OUTPUT=$(echo "$MOCK_PRICE" | format_price_history_table)
assert_contains "shows header date" "日期" "$OUTPUT"
assert_contains "shows header price" "概率" "$OUTPUT"
assert_contains "shows first date" "2025-01-01" "$OUTPUT"
assert_contains "shows first price as percent" "45.0%" "$OUTPUT"
assert_contains "shows last price as percent" "62.0%" "$OUTPUT"

# Test 2: format_trend_summary
echo "[Test 2] format_trend_summary - 起止与变化"
OUTPUT=$(echo "$MOCK_PRICE" | format_trend_summary)
assert_contains "shows start" "起始: 45.0%" "$OUTPUT"
assert_contains "shows end" "结束: 62.0%" "$OUTPUT"
assert_contains "shows absolute change" "绝对变化: +17.0pp" "$OUTPUT"
assert_contains "shows relative change" "相对变化: +37.8%" "$OUTPUT"

# Test 3: format_volume_trend_table
echo "[Test 3] format_volume_trend_table - 交易量表格"
OUTPUT=$(echo "$MOCK_VOLUME" | format_volume_trend_table)
assert_contains "shows header volume" "交易量" "$OUTPUT"
assert_contains "shows first volume" '$1.2K' "$OUTPUT"
assert_contains "shows last volume" '$3.5M' "$OUTPUT"

# Test 4: empty data handling
echo "[Test 4] 空数据处理"
OUTPUT=$(echo '[]' | format_price_history_table)
assert_contains "price empty message" "暂无历史价格数据" "$OUTPUT"
OUTPUT=$(echo '[]' | format_trend_summary)
assert_contains "trend empty message" "暂无趋势数据" "$OUTPUT"
OUTPUT=$(echo '[]' | format_volume_trend_table)
assert_contains "volume empty message" "暂无交易量数据" "$OUTPUT"

# Test 5: invalid input handling
echo "[Test 5] 非法输入处理"
OUTPUT=$(echo 'not-json' | format_price_history_table 2>&1)
CODE=$?
assert_status "price invalid returns non-zero" 1 "$CODE"
assert_contains "price invalid message" "数据格式无效" "$OUTPUT"

OUTPUT=$(echo 'not-json' | format_trend_summary 2>&1)
CODE=$?
assert_status "trend invalid returns non-zero" 1 "$CODE"
assert_contains "trend invalid message" "数据格式无效" "$OUTPUT"

OUTPUT=$(echo 'not-json' | format_volume_trend_table 2>&1)
CODE=$?
assert_status "volume invalid returns non-zero" 1 "$CODE"
assert_contains "volume invalid message" "数据格式无效" "$OUTPUT"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
