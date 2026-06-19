#!/bin/bash
#
# History series argument and API validation tests (offline)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/helpers/assert.sh"
source "$PROJECT_DIR/skills/polymarket-query/scripts/api.sh"

PASS=0
FAIL=0

echo "=== History API/CLI Offline Tests ==="
echo ""

# CLI tests

echo "[Test 1] history argument validation"
OUT=$(bash "$PROJECT_DIR/skills/polymarket-query/scripts/polymarket.sh" history 2>&1)
CODE=$?
assert_status "history missing args exits 1" 1 "$CODE"
assert_contains "history usage shown" "history <event-slug> <from> <to> [interval]" "$OUT"

echo "[Test 2] trend argument validation"
OUT=$(bash "$PROJECT_DIR/skills/polymarket-query/scripts/polymarket.sh" trend test-slug 2025-01-02 2025-01-01 2h 2>&1)
CODE=$?
assert_status "trend invalid args exits 1" 1 "$CODE"
assert_contains "trend invalid range message" "Invalid time range" "$OUT"

echo "[Test 3] volume-trend argument validation"
OUT=$(bash "$PROJECT_DIR/skills/polymarket-query/scripts/polymarket.sh" volume-trend test-slug 2025-01-01 2025-01-02 30m 2>&1)
CODE=$?
assert_status "volume-trend invalid interval exits 1" 1 "$CODE"
assert_contains "volume-trend invalid interval message" "Invalid interval" "$OUT"

echo "[Test 4] history export format argument validation"
OUT=$(bash "$PROJECT_DIR/skills/polymarket-query/scripts/polymarket.sh" history test-slug 2025-01-01 2025-01-02 --format xml 2>&1)
CODE=$?
assert_status "history invalid format exits 1" 1 "$CODE"
assert_contains "history invalid format message" "Invalid format" "$OUT"

echo "[Test 5] trend export out argument dependency validation"
OUT=$(bash "$PROJECT_DIR/skills/polymarket-query/scripts/polymarket.sh" trend test-slug 2025-01-01 2025-01-02 --out /tmp/out.csv 2>&1)
CODE=$?
assert_status "trend out without format exits 1" 1 "$CODE"
assert_contains "trend out without format message" "--out must be used together with --format" "$OUT"

echo "[Test 6] series argument combination (--format=csv)"
OUT=$(bash "$PROJECT_DIR/skills/polymarket-query/scripts/polymarket.sh" history test-slug 2025-01-99 2025-01-31 --format=csv 2>&1)
CODE=$?
assert_status "history with --format=csv still validates range" 1 "$CODE"
assert_contains "history invalid date message" "Invalid time range" "$OUT"

echo "[Test 7] series argument combination (unknown argument)"
OUT=$(bash "$PROJECT_DIR/skills/polymarket-query/scripts/polymarket.sh" trend test-slug 2025-01-01 2025-01-31 --foo bar 2>&1)
CODE=$?
assert_status "trend unknown option exits 1" 1 "$CODE"
assert_contains "trend unknown option message" "Unknown argument" "$OUT"

# API validation tests

echo "[Test 8] validate_interval"
validate_interval "1h" >/dev/null 2>&1
assert_status "1h valid" 0 "$?"
validate_interval "4h" >/dev/null 2>&1
assert_status "4h valid" 0 "$?"
validate_interval "1d" >/dev/null 2>&1
assert_status "1d valid" 0 "$?"
validate_interval "2h" >/dev/null 2>&1
assert_status "2h invalid" 1 "$?"

echo "[Test 9] validate_time_range"
validate_time_range "2025-01-01" "2025-01-31" >/dev/null 2>&1
assert_status "valid range" 0 "$?"
validate_time_range "2025/01/01" "2025-01-31" >/dev/null 2>&1
assert_status "invalid from format" 1 "$?"
validate_time_range "2025-02-01" "2025-01-31" >/dev/null 2>&1
assert_status "from greater than to" 1 "$?"

echo "[Test 10] fetch_history_series argument validation"
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