#!/bin/bash
#
# Cache 模块单元测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$PROJECT_DIR/scripts/cache.sh"

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

assert_contains() {
    local desc="$1" expected="$2" actual="$3"
    if printf '%s' "$actual" | grep -Fq -- "$expected"; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        echo "     expected to contain: $expected"
        echo "     actual: $actual"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Cache Tests ==="
echo ""

TMP_CACHE_DIR="$(mktemp -d)"
export CACHE_DIR="$TMP_CACHE_DIR"
unset NO_CACHE

cleanup() {
    rm -rf "$TMP_CACHE_DIR"
}
trap cleanup EXIT

echo "[Test 1] cache_init"
cache_init >/dev/null 2>&1
assert_status "cache_init exits 0" 0 "$?"
if [ -d "$CACHE_DIR" ]; then
    assert_eq "cache directory created" "yes" "yes"
else
    assert_eq "cache directory created" "yes" "no"
fi

echo "[Test 2] cache_key generation"
KEY_A1="$(cache_key "history" "slug-a" "2025-01-01" "2025-01-02" "1d")"
KEY_A2="$(cache_key "history" "slug-a" "2025-01-01" "2025-01-02" "1d")"
KEY_B="$(cache_key "history" "slug-b" "2025-01-01" "2025-01-02" "1d")"
assert_eq "same input generates same key" "$KEY_A1" "$KEY_A2"
if [ "$KEY_A1" != "$KEY_B" ]; then
    assert_eq "different input generates different key" "yes" "yes"
else
    assert_eq "different input generates different key" "yes" "no"
fi

echo "[Test 3] cache miss/hit"
MISS_RESULT="$(cache_get "$KEY_A1" 2>/dev/null)"
assert_status "cache_get miss returns non-zero" 1 "$?"
assert_eq "cache_get miss returns empty output" "" "$MISS_RESULT"

CACHE_PAYLOAD='[{"timestamp":"2025-01-01","value":0.52}]'
cache_set "$KEY_A1" "$CACHE_PAYLOAD" 30 >/dev/null 2>&1
assert_status "cache_set exits 0" 0 "$?"
HIT_RESULT="$(cache_get "$KEY_A1")"
assert_status "cache_get hit returns 0" 0 "$?"
assert_eq "cache_get hit returns stored payload" "$CACHE_PAYLOAD" "$HIT_RESULT"

echo "[Test 4] cache TTL expiration"
TTL_KEY="$(cache_key "ttl" "sample")"
cache_set "$TTL_KEY" "ttl-data" 1 >/dev/null 2>&1
sleep 2
TTL_RESULT="$(cache_get "$TTL_KEY" 2>/dev/null)"
assert_status "expired cache returns non-zero" 1 "$?"
assert_eq "expired cache returns empty output" "" "$TTL_RESULT"

echo "[Test 5] cache clear"
cache_set "$(cache_key "clear" "1")" "one" 30 >/dev/null 2>&1
cache_set "$(cache_key "clear" "2")" "two" 30 >/dev/null 2>&1
cache_clear >/dev/null 2>&1
assert_status "cache_clear exits 0" 0 "$?"
REMAINING_COUNT="$(find "$CACHE_DIR" -type f -name '*.cache' | wc -l | awk '{print $1}')"
assert_eq "cache_clear removes all entries" "0" "$REMAINING_COUNT"

echo "[Test 6] cache stats"
cache_set "$(cache_key "stats" "1")" "s1" 30 >/dev/null 2>&1
cache_set "$(cache_key "stats" "2")" "s2" 30 >/dev/null 2>&1
STATS_OUTPUT="$(cache_stats)"
assert_contains "cache_stats includes cache dir" "Cache directory: $CACHE_DIR" "$STATS_OUTPUT"
assert_contains "cache_stats includes entry count" "Entries: 2" "$STATS_OUTPUT"
assert_contains "cache_stats includes total size" "Total size:" "$STATS_OUTPUT"

echo "[Test 7] NO_CACHE handling"
NO_CACHE=1
export NO_CACHE
NC_KEY="$(cache_key "no-cache" "k")"
cache_set "$NC_KEY" "ignored" 30 >/dev/null 2>&1
NO_CACHE_RESULT="$(cache_get "$NC_KEY" 2>/dev/null)"
assert_status "cache_get bypasses cache when NO_CACHE=1" 1 "$?"
assert_eq "cache_get returns empty output when NO_CACHE=1" "" "$NO_CACHE_RESULT"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
