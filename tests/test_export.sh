#!/bin/bash
#
# Export capability tests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$PROJECT_DIR/scripts/export.sh"

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

echo "=== Export Tests ==="
echo ""

MOCK_PRICE='[
  {"timestamp":1735689600,"price":0.45},
  {"timestamp":1735776000,"price":0.50}
]'

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[Test 1] CSV 导出（包含表头）"
CSV_FILE="$TMP_DIR/history.csv"
export_to_csv "$MOCK_PRICE" "$CSV_FILE" >/tmp/export_test.out 2>/tmp/export_test.err
CODE=$?
assert_status "csv export returns 0" 0 "$CODE"
CSV_CONTENT=$(cat "$CSV_FILE" 2>/dev/null)
assert_contains "csv header date" "date" "$CSV_CONTENT"
assert_contains "csv header value column" "price" "$CSV_CONTENT"
assert_contains "csv has row value" "0.45" "$CSV_CONTENT"

echo "[Test 2] JSON 导出（schema 合法）"
JSON_FILE="$TMP_DIR/history.json"
export_to_json "$MOCK_PRICE" "$JSON_FILE" >/tmp/export_test.out 2>/tmp/export_test.err
CODE=$?
assert_status "json export returns 0" 0 "$CODE"
SCHEMA_OK=$(jq -r '
    (.schema_version | type == "string") and
    (.exported_at | type == "string") and
    (.count == 2) and
    (.data | type == "array" and length == 2)
' "$JSON_FILE")
assert_eq "json schema valid" "true" "$SCHEMA_OK"

echo "[Test 3] 空数据导出"
EMPTY_FILE="$TMP_DIR/empty.csv"
export_to_csv '[]' "$EMPTY_FILE" >/tmp/export_test.out 2>/tmp/export_test.err
CODE=$?
assert_status "empty csv export returns 0" 0 "$CODE"
EMPTY_LINES=$(wc -l < "$EMPTY_FILE" | tr -d ' ')
assert_eq "empty csv has header only" "1" "$EMPTY_LINES"

echo "[Test 4] 文件写入错误处理"
BAD_FILE="$TMP_DIR/not-exist-dir/out.csv"
ERR_MSG=$(export_to_csv "$MOCK_PRICE" "$BAD_FILE" 2>&1 >/dev/null)
CODE=$?
assert_status "write error returns non-zero" 1 "$CODE"
assert_contains "write error message shown" "导出失败" "$ERR_MSG"

echo "[Test 5] 格式参数校验"
validate_export_format "csv" >/dev/null 2>&1
assert_status "csv valid" 0 "$?"
validate_export_format "json" >/dev/null 2>&1
assert_status "json valid" 0 "$?"
validate_export_format "xml" >/dev/null 2>&1
assert_status "xml invalid" 1 "$?"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
