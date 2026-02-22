#!/bin/bash
#
# Cache 工具函数

CACHE_DIR="${CACHE_DIR:-$HOME/.cache/holo-polymarket}"
CACHE_TTL="${CACHE_TTL:-60}"

cache_init() {
    mkdir -p "$CACHE_DIR"
}

cache_key() {
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s\x1f' "$@" | sha256sum | awk '{print $1}'
    else
        printf '%s\x1f' "$@" | shasum -a 256 | awk '{print $1}'
    fi
}

cache_get() {
    local key="$1"
    local file="$CACHE_DIR/${key}.cache"
    local now expires

    if [ "${NO_CACHE:-0}" = "1" ]; then
        return 1
    fi

    [ -f "$file" ] || return 1

    IFS= read -r expires < "$file" || return 1
    now=$(date +%s)
    if ! echo "$expires" | grep -Eq '^[0-9]+$'; then
        rm -f "$file"
        return 1
    fi
    if [ "$now" -ge "$expires" ]; then
        rm -f "$file"
        return 1
    fi

    tail -n +2 "$file"
    return 0
}

cache_set() {
    local key="$1"
    local data="$2"
    local ttl="${3:-$CACHE_TTL}"
    local file="$CACHE_DIR/${key}.cache"
    local now expires

    if [ "${NO_CACHE:-0}" = "1" ]; then
        return 0
    fi

    cache_init || return 1

    now=$(date +%s)
    expires=$((now + ttl))

    {
        printf '%s\n' "$expires"
        printf '%s' "$data"
    } > "$file"
}

cache_clear() {
    cache_init || return 1
    find "$CACHE_DIR" -type f -name '*.cache' -delete
}

cache_stats() {
    cache_init || return 1

    local entries size_bytes
    entries=$(find "$CACHE_DIR" -type f -name '*.cache' | wc -l | awk '{print $1}')
    size_bytes=$(du -sb "$CACHE_DIR" 2>/dev/null | awk '{print $1}')
    size_bytes="${size_bytes:-0}"

    echo "Cache directory: $CACHE_DIR"
    echo "Entries: $entries"
    echo "Total size: ${size_bytes} bytes"
}
