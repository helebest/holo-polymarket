#!/bin/bash
#
# API 单元测试（离线，mock curl/data_get）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/helpers/assert.sh"
source "$PROJECT_DIR/scripts/api.sh"

PASS=0
FAIL=0

echo "=== API Unit Tests (Offline) ==="
echo ""

echo "[Test 1] URL 编码 - search_events"
curl() {
    printf '%s' "${@: -1}"
    return 0
}
OUT=$(search_events "btc & eth" 2)
assert_contains "search query is URL-encoded" "title=btc%20%26%20eth" "$OUT"

echo "[Test 2] URL 编码 - fetch_event_detail"
OUT=$(fetch_event_detail "fed/decision march")
assert_contains "detail slug is URL-encoded" "slug=fed%2Fdecision%20march" "$OUT"

echo "[Test 3] URL 编码 - fetch_positions/fetch_trades"
OUT=$(fetch_positions "0xabc?foo=1" 3)
assert_contains "positions user is URL-encoded" "user=0xabc%3Ffoo%3D1" "$OUT"
OUT=$(fetch_trades "0xabc?foo=1" 3)
assert_contains "trades user is URL-encoded" "user=0xabc%3Ffoo%3D1" "$OUT"

echo "[Test 4] clob_get 缺 token 时返回非零"
unset POLYMARKET_BEARER_TOKEN
unset _POLYMARKET_BEARER_TOKEN
POLYMARKET_CREDENTIALS_FILE="/tmp/non-existent-polymarket-token"
OUT=$(clob_get "/prices-history" "market=1" 2>/dev/null)
CODE=$?
assert_status "clob_get without token exits non-zero" 1 "$CODE"
assert_eq "clob_get without token has empty output" "" "$OUT"

echo "[Test 5] curl 超时路径传播"
curl() {
    return 28
}
OUT=$(gamma_get "/events" "limit=1" 2>/dev/null)
CODE=$?
assert_status "gamma_get timeout exits 28" 28 "$CODE"
assert_eq "gamma_get timeout output empty" "" "$OUT"

echo "[Test 6] volume 接口异常响应不写缓存"
data_get() {
    echo '{"error":"bad"}'
}
cache_get() {
    return 1
}
CACHE_SET_CALLED=0
cache_set() {
    CACHE_SET_CALLED=1
    return 0
}
RESULT=$(fetch_volume_history "bad slug" "2025-01-01" "2025-01-02" "1d" 2>/dev/null)
CODE=$?
assert_status "fetch_volume_history invalid payload exits non-zero" 1 "$CODE"
assert_eq "fetch_volume_history invalid payload returns []" "[]" "$RESULT"
assert_eq "fetch_volume_history invalid payload does not cache" "0" "$CACHE_SET_CALLED"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]