#!/bin/bash
#
# Regression tests for fetch_price_history range chunking (offline, mocked).
#
# The CLOB /prices-history endpoint rejects an explicit startTs/endTs span
# longer than 15 days (HTTP 400, "interval is too long"), independent of
# fidelity and global across markets (verified empirically: 15d -> 200,
# 16d -> 400). fetch_price_history must therefore split the requested range
# into <=14-day chunks, fetch each chunk, and stitch the results together.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/helpers/assert.sh"
source "$PROJECT_DIR/skills/polymarket-query/scripts/api.sh"

PASS=0
FAIL=0

echo "=== fetch_price_history range chunking (offline, mocked) ==="
echo ""

# CLOB rejects spans > 15 days; the client must chunk at <= 14 days.
MAX_CHUNK_SECONDS=$((14 * 86400))

# --- Mocks: keep everything offline ----------------------------------------
get_clob_token_id() { echo "TESTTOKEN"; }   # skip Gamma resolution
cache_get() { return 1; }                    # always a cache miss
cache_set() { return 0; }                    # never persist

RECORD="$(mktemp "${TMPDIR:-/tmp}/pm_chunk_record.XXXXXX")"
trap 'rm -f "$RECORD"' EXIT

# Mock clob_get: record each call's [startTs,endTs] (one line "START END") and
# emit synthetic history with a point just after start and just before end so
# every chunk contributes covered data. When BAD_START matches a chunk's start,
# emit a malformed-but-HTTP-200 body (.history is not an array) to simulate a
# corrupt response on one chunk.
clob_get() {
    local params="$2" start end
    start=$(printf '%s' "$params" | sed -n 's/.*startTs=\([0-9][0-9]*\).*/\1/p')
    end=$(printf '%s' "$params" | sed -n 's/.*endTs=\([0-9][0-9]*\).*/\1/p')
    printf '%s %s\n' "$start" "$end" >>"$RECORD"
    if [ -n "${BAD_START:-}" ] && [ "$start" = "$BAD_START" ]; then
        printf '{"history":"corrupt-not-an-array"}'
    else
        printf '{"history":[{"t":%s,"p":0.5},{"t":%s,"p":0.5}]}' "$((start + 3600))" "$((end - 3600))"
    fi
}

max_chunk_span() {
    local s e span max=0
    while read -r s e; do
        span=$((e - s))
        [ "$span" -gt "$max" ] && max=$span
    done <"$RECORD"
    echo "$max"
}

# ---------------------------------------------------------------------------
echo "[Test 1] a 40-day range is split into <=14-day chunks"
: >"$RECORD"
OUT=$(fetch_price_history "test-market" "2026-05-01" "2026-06-10" "1d")
CALLS=$(wc -l <"$RECORD" | tr -d ' ')
assert_gt "40-day range issues more than one clob_get call" "$CALLS" 1

SPAN=$(max_chunk_span)
assert_status "largest chunk span <= 14 days (got ${SPAN}s)" 0 \
    "$([ "${SPAN:-0}" -le "$MAX_CHUNK_SECONDS" ] && echo 0 || echo 1)"

# ---------------------------------------------------------------------------
echo "[Test 2] chunks cover [from,to] contiguously (no gaps)"
FROM=$(date_to_epoch_utc "2026-05-01" start)
TO=$(date_to_epoch_utc "2026-06-10" end)
MIN_START=$(sort -n "$RECORD" | head -1 | awk '{print $1}')
MAX_END=$(sort -n -k2,2 "$RECORD" | tail -1 | awk '{print $2}')
assert_eq "first chunk starts at the range start" "$FROM" "$MIN_START"
assert_eq "last chunk ends at the range end" "$TO" "$MAX_END"

GAP=0
prev_end=""
while read -r s e; do
    if [ -n "$prev_end" ] && [ "$s" -gt "$prev_end" ]; then
        GAP=1
    fi
    prev_end="$e"
done < <(sort -n "$RECORD")
assert_status "chunks are contiguous (no gaps)" 0 "$GAP"

# ---------------------------------------------------------------------------
echo "[Test 3] stitched output spans the full range"
assert_not_empty "stitched output is non-empty" "$OUT"
NPOINTS=$(echo "$OUT" | jq 'length' 2>/dev/null)
assert_gt "stitched daily series has multiple points" "${NPOINTS:-0}" 1
FIRST_TS=$(echo "$OUT" | jq '.[0].timestamp' 2>/dev/null)
LAST_TS=$(echo "$OUT" | jq '.[-1].timestamp' 2>/dev/null)
assert_status "series starts within the first day of the range" 0 \
    "$([ "${FIRST_TS:-0}" -lt "$((FROM + 86400))" ] && echo 0 || echo 1)"
assert_status "series ends within the last day of the range" 0 \
    "$([ "${LAST_TS:-0}" -gt "$((TO - 86400))" ] && echo 0 || echo 1)"

# ---------------------------------------------------------------------------
echo "[Test 4] a short (<=14-day) range still uses a single request"
: >"$RECORD"
OUT2=$(fetch_price_history "test-market" "2026-06-01" "2026-06-10" "1d")
CALLS2=$(wc -l <"$RECORD" | tr -d ' ')
assert_eq "10-day range issues exactly one clob_get call" "1" "$CALLS2"

# ---------------------------------------------------------------------------
echo "[Test 5] a malformed HTTP-200 chunk is skipped, not allowed to wipe the series"
: >"$RECORD"
# Corrupt the 2nd chunk (its start = range start + one 14-day window).
BAD_START=$(($(date_to_epoch_utc "2026-05-01" start) + 14 * 86400))
OUT5=$(fetch_price_history "test-market" "2026-05-01" "2026-06-10" "1d")
RC5=$?
unset BAD_START
assert_status "fetch still exits 0 despite a corrupt chunk" 0 "$RC5"
assert_eq "result is a JSON array despite a corrupt chunk" "array" \
    "$(printf '%s' "$OUT5" | jq -r 'type' 2>/dev/null)"
assert_gt "good chunks survive (series not wiped to empty)" \
    "$(printf '%s' "$OUT5" | jq 'length' 2>/dev/null)" 0

# ---------------------------------------------------------------------------
echo "[Test 6] an over-long range is rejected without fanning out into requests"
: >"$RECORD"
OUT6=$(fetch_price_history "test-market" "2024-01-01" "2026-06-19" "1d" 2>/dev/null)
RC6=$?
CALLS6=$(wc -l <"$RECORD" | tr -d ' ')
assert_eq "over-long (~2.5y) range returns []" "[]" "$OUT6"
assert_status "over-long range exits non-zero" 1 "$RC6"
assert_eq "over-long range issues zero clob_get calls (no fan-out)" "0" "$CALLS6"

# ---------------------------------------------------------------------------
# Live regression: a real >15-day range must succeed end-to-end (this is the
# case that returned HTTP 400 before chunking). Only runs under RUN_LIVE_TESTS;
# resolves a market slug dynamically so it does not hardcode a transient market.
# ---------------------------------------------------------------------------
if [ "${RUN_LIVE_TESTS:-0}" = "1" ]; then
    echo "[Live] a real >15-day range returns stitched data (was HTTP 400 before)"
    live_slug=$(fetch_hot_events 5 2>/dev/null |
        jq -r '[.[].markets[]?.slug] | map(select(. != null and . != "")) | .[0] // empty' 2>/dev/null)
    if [ -z "$live_slug" ]; then
        echo "  ⚠️  skipped: could not resolve a live market slug"
    else
        live_to_epoch=$(date -u +%s)
        live_from_epoch=$((live_to_epoch - 30 * 86400))
        live_from=$(epoch_to_ymd_utc "$live_from_epoch")
        live_to=$(epoch_to_ymd_utc "$live_to_epoch")
        live_out=$(NO_CACHE=1 fetch_price_history "$live_slug" "$live_from" "$live_to" 1d)
        live_rc=$?
        assert_status "live 30-day fetch_price_history exits 0 ($live_slug)" 0 "$live_rc"
        assert_eq "live 30-day result is a JSON array" "array" \
            "$(printf '%s' "$live_out" | jq -r 'type' 2>/dev/null)"
    fi
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
