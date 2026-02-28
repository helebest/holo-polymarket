#!/bin/bash
#
# 端到端测试：hot → detail 流水线
# 拉取热门事件，逐个查看详情，验证完整工作流
# 需要网络，不包含在 run_tests.sh 中
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$PROJECT_DIR/scripts/api.sh"
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

assert_status() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc (exit code=$actual, expected $expected)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== E2E Test: hot → detail 流水线 ==="
echo ""

# Step 1: 拉取 top 10 热门事件
echo "[Step 1] fetch_hot_events 10"
HOT_RESULT=$(fetch_hot_events 10)
IS_ARRAY=$(echo "$HOT_RESULT" | jq 'type' 2>/dev/null)
assert_eq "返回 JSON 数组" '"array"' "$IS_ARRAY"

EVENT_COUNT=$(echo "$HOT_RESULT" | jq 'length' 2>/dev/null)
assert_gt "事件数量 > 0" "${EVENT_COUNT:-0}" 0
echo "  ℹ️  获取到 $EVENT_COUNT 个事件"
echo ""

# Step 2: 提取所有 slug 到数组
mapfile -t SLUG_ARRAY < <(echo "$HOT_RESULT" | jq -r '.[].slug // empty' | tr -d '\r')
if [ ${#SLUG_ARRAY[@]} -eq 0 ]; then
    echo "  ❌ 无法提取 slug，终止测试"
    FAIL=$((FAIL + 1))
    echo ""
    echo "=== Results: $PASS passed, $FAIL failed ==="
    exit 1
fi

# Step 3: 逐个 slug 查看详情
for i in "${!SLUG_ARRAY[@]}"; do
    slug="${SLUG_ARRAY[$i]}"
    echo "[Step 3.$((i + 1))] detail: $slug"

    # 获取事件详情
    DETAIL=$(fetch_event_detail "$slug")
    DETAIL_TITLE=$(echo "$DETAIL" | jq -r '.[0].title // empty')
    assert_not_empty "[$slug] 详情有 title" "$DETAIL_TITLE"

    # 管道到 format_event_detail，验证不崩溃
    FORMAT_OUTPUT=$(echo "$DETAIL" | format_event_detail 2>&1)
    FORMAT_EXIT=$?
    assert_status "[$slug] format_event_detail 退出码 0" 0 "$FORMAT_EXIT"
    assert_not_empty "[$slug] format_event_detail 输出非空" "$FORMAT_OUTPUT"

    echo ""
done

# Step 4: 汇总
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
