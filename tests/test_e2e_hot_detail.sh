#!/bin/bash
#
# End-to-end test: hot → detail pipeline
# Fetches hot events, views each detail, and verifies the full workflow
# Network required, not included in run_tests.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/helpers/assert.sh"
source "$PROJECT_DIR/skills/polymarket-query/scripts/api.sh"
source "$PROJECT_DIR/skills/polymarket-query/scripts/format.sh"

PASS=0
FAIL=0

echo "=== E2E Test: hot → detail pipeline ==="
echo ""

# Step 1: fetch top 10 hot events
echo "[Step 1] fetch_hot_events 10"
HOT_RESULT=$(fetch_hot_events 10)
IS_ARRAY=$(echo "$HOT_RESULT" | jq 'type' 2>/dev/null)
assert_eq "returns JSON array" '"array"' "$IS_ARRAY"

EVENT_COUNT=$(echo "$HOT_RESULT" | jq 'length' 2>/dev/null)
assert_gt "event count > 0" "${EVENT_COUNT:-0}" 0
echo "  ℹ️  Fetched $EVENT_COUNT events"
echo ""

# Step 2: extract all slugs into an array (portable; `mapfile` needs bash 4+)
SLUG_ARRAY=()
while IFS= read -r slug_line; do
    [ -n "$slug_line" ] && SLUG_ARRAY+=("$slug_line")
done < <(echo "$HOT_RESULT" | jq -r '.[].slug // empty' | tr -d '\r')
if [ ${#SLUG_ARRAY[@]} -eq 0 ]; then
    echo "  ❌ Unable to extract slug, aborting test"
    FAIL=$((FAIL + 1))
    echo ""
    echo "=== Results: $PASS passed, $FAIL failed ==="
    exit 1
fi

# Step 3: view detail for each slug
for i in "${!SLUG_ARRAY[@]}"; do
    slug="${SLUG_ARRAY[$i]}"
    echo "[Step 3.$((i + 1))] detail: $slug"

    DETAIL=$(fetch_event_detail "$slug")
    DETAIL_TITLE=$(echo "$DETAIL" | jq -r '.[0].title // empty')
    assert_not_empty "[$slug] detail has title" "$DETAIL_TITLE"

    FORMAT_OUTPUT=$(echo "$DETAIL" | format_event_detail 2>&1)
    FORMAT_EXIT=$?
    assert_status "[$slug] format_event_detail exit code 0" 0 "$FORMAT_EXIT"
    assert_not_empty "[$slug] format_event_detail output non-empty" "$FORMAT_OUTPUT"

    echo ""
done

# Step 4: summary
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]