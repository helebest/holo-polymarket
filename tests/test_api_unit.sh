#!/bin/bash
#
# API unit tests (offline, mock curl/data_get)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/helpers/assert.sh"
source "$PROJECT_DIR/skills/polymarket-query/scripts/api.sh"

PASS=0
FAIL=0

echo "=== API Unit Tests (Offline) ==="
echo ""

echo "[Test 1] URL encoding - search_events"
curl() {
    printf '%s' "${@: -1}"
    return 0
}
OUT=$(search_events "btc & eth" 2)
assert_contains "search query is URL-encoded" "title=btc%20%26%20eth" "$OUT"

echo "[Test 2] URL encoding - fetch_event_detail"
OUT=$(fetch_event_detail "fed/decision march")
assert_contains "detail slug is URL-encoded" "slug=fed%2Fdecision%20march" "$OUT"

echo "[Test 3] URL encoding - fetch_positions/fetch_trades"
OUT=$(fetch_positions "0xabc?foo=1" 3)
assert_contains "positions user is URL-encoded" "user=0xabc%3Ffoo%3D1" "$OUT"
OUT=$(fetch_trades "0xabc?foo=1" 3)
assert_contains "trades user is URL-encoded" "user=0xabc%3Ffoo%3D1" "$OUT"

echo "[Test 4] clob_get works without a token (prices-history is public)"
unset POLYMARKET_BEARER_TOKEN
unset _POLYMARKET_BEARER_TOKEN
POLYMARKET_CREDENTIALS_FILE="/tmp/non-existent-polymarket-token"
# Echo all curl args so we can assert which headers were attached.
curl() {
    printf '%s' "$*"
    return 0
}
OUT=$(clob_get "/prices-history" "market=1")
CODE=$?
assert_status "clob_get without token succeeds (public endpoint)" 0 "$CODE"
assert_not_contains "clob_get without token sends no Authorization header" "Authorization" "$OUT"
assert_contains "clob_get without token still hits prices-history" "prices-history" "$OUT"

echo "[Test 4b] clob_get attaches a bearer header when a token is available"
POLYMARKET_BEARER_TOKEN="dummy_test_token"
OUT=$(clob_get "/prices-history" "market=1")
CODE=$?
assert_status "clob_get with token succeeds" 0 "$CODE"
assert_contains "clob_get with token sends Authorization header" "Authorization: Bearer dummy_test_token" "$OUT"
unset POLYMARKET_BEARER_TOKEN
unset _POLYMARKET_BEARER_TOKEN

echo "[Test 5] curl timeout path propagation"
curl() {
    return 28
}
OUT=$(gamma_get "/events" "limit=1" 2>/dev/null)
CODE=$?
assert_status "gamma_get timeout exits 28" 28 "$CODE"
assert_eq "gamma_get timeout output empty" "" "$OUT"

echo "[Test 6] volume endpoint invalid response is not cached"
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

echo "[Test 7] load_polymarket_funder resolves env then credentials file"
unset POLYMARKET_FUNDER
# env wins
POLYMARKET_FUNDER="0xEnvFunder"
OUT=$(load_polymarket_funder)
CODE=$?
assert_status "funder env resolves" 0 "$CODE"
assert_eq "funder env value" "0xEnvFunder" "$OUT"
unset POLYMARKET_FUNDER
# credentials file: FUNDER key, tolerant of spaces around '='
TMP_CRED=$(mktemp)
printf '# creds\nFUNDER = 0xFileFunder\nAPI_KEY=ignored\n' >"$TMP_CRED"
POLYMARKET_CREDENTIALS_FILE="$TMP_CRED"
OUT=$(load_polymarket_funder)
CODE=$?
assert_status "funder file resolves" 0 "$CODE"
assert_eq "funder file value" "0xFileFunder" "$OUT"
# POLYMARKET_FUNDER key variant in the file is also accepted
printf 'POLYMARKET_FUNDER=0xFilePrefixed\n' >"$TMP_CRED"
OUT=$(load_polymarket_funder)
assert_eq "funder file POLYMARKET_FUNDER key" "0xFilePrefixed" "$OUT"
rm -f "$TMP_CRED"
# missing env + missing file -> non-zero
POLYMARKET_CREDENTIALS_FILE="/tmp/non-existent-polymarket-funder-xyz"
OUT=$(load_polymarket_funder)
CODE=$?
assert_status "funder missing returns non-zero" 1 "$CODE"
unset POLYMARKET_CREDENTIALS_FILE

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]