#!/bin/bash
#
# series 参数解析测试（离线）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/helpers/assert.sh"
source "$PROJECT_DIR/scripts/export.sh"
source "$PROJECT_DIR/scripts/commands_series.sh"

PASS=0
FAIL=0

echo "=== Series Args Tests ==="
echo ""

echo "[Test 1] 基础参数解析"
parse_series_command_args "history" slug-a 2025-01-01 2025-01-31 1d --format csv --out /tmp/a.csv >/dev/null 2>&1
CODE=$?
assert_status "parse base args exits 0" 0 "$CODE"
assert_eq "slug parsed" "slug-a" "$SERIES_SLUG"
assert_eq "from parsed" "2025-01-01" "$SERIES_FROM_DATE"
assert_eq "to parsed" "2025-01-31" "$SERIES_TO_DATE"
assert_eq "interval parsed" "1d" "$SERIES_INTERVAL"
assert_eq "format parsed" "csv" "$SERIES_FORMAT"
assert_eq "out parsed" "/tmp/a.csv" "$SERIES_OUT"

echo "[Test 2] 等号参数解析"
parse_series_command_args "trend" slug-b 2025-02-01 2025-02-05 --format=json >/dev/null 2>&1
CODE=$?
assert_status "parse equals format exits 0" 0 "$CODE"
assert_eq "default interval" "1d" "$SERIES_INTERVAL"
assert_eq "format parsed with equals" "json" "$SERIES_FORMAT"

echo "[Test 3] --out 依赖 --format"
parse_series_command_args "history" slug-c 2025-01-01 2025-01-31 --out /tmp/b.csv >/dev/null 2>&1
CODE=$?
assert_status "out without format exits non-zero" 1 "$CODE"

echo "[Test 4] 未知参数"
parse_series_command_args "volume-trend" slug-d 2025-01-01 2025-01-31 --unknown x >/dev/null 2>&1
CODE=$?
assert_status "unknown option exits non-zero" 1 "$CODE"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]