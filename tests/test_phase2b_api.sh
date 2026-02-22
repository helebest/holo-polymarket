#!/bin/bash
#
# Phase 2b API/CLI 测试

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

echo "=== Phase 2b API/CLI Tests ==="
echo ""

# CLI tests

echo "[Test 1] history 参数校验"
OUT=$(bash "$PROJECT_DIR/scripts/polymarket.sh" history 2>&1)
CODE=$?
assert_status "history missing args exits 1" 1 "$CODE"
assert_contains "history usage shown" "history <event-slug> <from> <to> [interval]" "$OUT"

echo "[Test 2] trend 参数校验"
OUT=$(bash "$PROJECT_DIR/scripts/polymarket.sh" trend test-slug 2025-01-02 2025-01-01 2h 2>&1)
CODE=$?
assert_status "trend invalid args exits 1" 1 "$CODE"
assert_contains "trend invalid range message" "时间范围无效" "$OUT"

echo "[Test 3] volume-trend 参数校验"
OUT=$(bash "$PROJECT_DIR/scripts/polymarket.sh" volume-trend test-slug 2025-01-01 2025-01-02 30m 2>&1)
CODE=$?
assert_status "volume-trend invalid interval exits 1" 1 "$CODE"
assert_contains "volume-trend invalid interval message" "interval 无效" "$OUT"

# API validation tests

echo "[Test 4] validate_interval"
validate_interval "1h" >/dev/null 2>&1
assert_status "1h valid" 0 "$?"
validate_interval "4h" >/dev/null 2>&1
assert_status "4h valid" 0 "$?"
validate_interval "1d" >/dev/null 2>&1
assert_status "1d valid" 0 "$?"
validate_interval "2h" >/dev/null 2>&1
assert_status "2h invalid" 1 "$?"

echo "[Test 5] validate_time_range"
validate_time_range "2025-01-01" "2025-01-31" >/dev/null 2>&1
assert_status "valid range" 0 "$?"
validate_time_range "2025/01/01" "2025-01-31" >/dev/null 2>&1
assert_status "invalid from format" 1 "$?"
validate_time_range "2025-02-01" "2025-01-31" >/dev/null 2>&1
assert_status "from greater than to" 1 "$?"

echo "[Test 6] fetch_history_series 参数校验"
RESULT=$(fetch_history_series "price" "" "2025-01-01" "2025-01-31" "1d" 2>/dev/null)
CODE=$?
assert_status "missing slug returns non-zero" 1 "$CODE"
assert_eq "missing slug returns empty array" "[]" "${RESULT:-[]}"

RESULT=$(fetch_history_series "unknown" "test-slug" "2025-01-01" "2025-01-31" "1d" 2>/dev/null)
CODE=$?
assert_status "unknown series type returns non-zero" 1 "$CODE"
assert_eq "unknown series type returns empty array" "[]" "${RESULT:-[]}"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
