#!/bin/bash
#
# Common helpers shared by CLI modules.

COMMON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pm_error() {
    echo "Error: $*" >&2
}

pm_warn() {
    echo "Warning: $*" >&2
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
        pm_error "Missing dependencies: ${missing[*]}"
        return 1
    fi

    return 0
}

url_encode() {
    local raw="$1"
    jq -rn --arg v "$raw" '$v|@uri'
}

# Convert epoch seconds to UTC YYYY-MM-DD, compatible with GNU date and BSD/macOS date
epoch_to_ymd_utc() {
    local ts="$1"
    date -u -d "@${ts}" +%Y-%m-%d 2>/dev/null \
        || date -u -r "${ts}" +%Y-%m-%d 2>/dev/null
}

# Convert "YYYY-MM-DD HH:MM:SS" (UTC) to epoch seconds, compatible with GNU date and BSD/macOS date
ymd_time_to_epoch_utc() {
    local datetime="$1"
    date -u -d "${datetime}" +%s 2>/dev/null \
        || date -u -j -f "%Y-%m-%d %H:%M:%S" "${datetime}" +%s 2>/dev/null
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
        epoch_to_ymd_utc "$ts" 2>/dev/null || echo "N/A"
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
            pm_error "Internal error: unknown time boundary argument: $bound"
            return 1
            ;;
    esac

    ymd_time_to_epoch_utc "${day} ${suffix}"
}