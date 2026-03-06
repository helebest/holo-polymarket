#!/bin/bash
#
# Common helpers shared by CLI modules.

COMMON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pm_error() {
    echo "错误: $*" >&2
}

pm_warn() {
    echo "警告: $*" >&2
}

require_commands() {
    local missing=()
    local cmd
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        pm_error "缺少依赖: ${missing[*]}"
        return 1
    fi

    return 0
}

url_encode() {
    local raw="$1"
    jq -rn --arg v "$raw" '$v|@uri'
}

to_ymd_date() {
    local raw="$1"
    if [ -z "$raw" ] || [ "$raw" = "null" ]; then
        echo "N/A"
        return
    fi

    if echo "$raw" | grep -Eq '^[0-9]+$'; then
        local ts="$raw"
        if [ "$ts" -gt 9999999999 ] 2>/dev/null; then
            ts=$((ts / 1000))
        fi
        date -u -d "@$ts" +%Y-%m-%d 2>/dev/null || echo "N/A"
        return
    fi

    if echo "$raw" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
        echo "${raw:0:10}"
        return
    fi

    echo "N/A"
}

date_to_epoch_utc() {
    local day="$1"
    local bound="${2:-start}"
    local suffix

    case "$bound" in
        start) suffix="00:00:00" ;;
        end) suffix="23:59:59" ;;
        *)
            pm_error "内部错误: 未知时间边界参数: $bound"
            return 1
            ;;
    esac

    date -u -d "${day} ${suffix}" +%s 2>/dev/null
}