#!/bin/bash
#
# Shared assertions for shell tests.

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

assert_not_contains() {
    local desc="$1" unexpected="$2" actual="$3"
    if printf '%s' "$actual" | grep -Fq -- "$unexpected"; then
        echo "  ❌ $desc"
        echo "     should NOT contain: $unexpected"
        FAIL=$((FAIL + 1))
    else
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
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

assert_line_count_ge() {
    local desc="$1" min="$2" actual="$3"
    local count
    count=$(echo "$actual" | wc -l)
    if [ "$count" -ge "$min" ]; then
        echo "  ✅ $desc (got $count lines)"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc (got $count lines, expected >= $min)"
        FAIL=$((FAIL + 1))
    fi
}