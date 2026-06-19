#!/bin/bash
#
# Polymarket API wrapper
# All API calls are centralized here for easier testing and replacement

GAMMA_API="${GAMMA_API_BASE:-https://gamma-api.polymarket.com}"
DATA_API="${DATA_API_BASE:-https://data-api.polymarket.com}"
CLOB_API="${CLOB_API_BASE:-https://clob.polymarket.com}"
CURL_TIMEOUT="${CURL_TIMEOUT:-15}"
CURL_RETRY="${CURL_RETRY:-2}"
# The credentials file path is resolved in _pm_resolve_credentials_file across multiple candidate locations (agent-neutral).
# If POLYMARKET_CREDENTIALS_FILE is set, only that path is used.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cache.sh"
source "$SCRIPT_DIR/common.sh"

http_get() {
    local url="$1"
    shift || true

    # Auto-detect proxy environment variables
    local proxy=""
    if [ -n "${HTTPS_PROXY:-}" ]; then
        proxy="$HTTPS_PROXY"
    elif [ -n "${https_proxy:-}" ]; then
        proxy="$https_proxy"
    elif [ -n "${HTTP_PROXY:-}" ]; then
        proxy="$HTTP_PROXY"
    elif [ -n "${http_proxy:-}" ]; then
        proxy="$http_proxy"
    fi

    local curl_args=(-fsS --max-time "$CURL_TIMEOUT" --retry "$CURL_RETRY" --retry-delay 1 --retry-connrefused "$@")
    if [ -n "$proxy" ]; then
        curl_args+=(-x "$proxy")
    fi

    local output
    output=$(curl "${curl_args[@]}" "$url" 2>/dev/null)
    local curl_code=$?
    if [ "$curl_code" -ne 0 ]; then
        pm_error "Request failed: ${url} (curl=${curl_code})"
        return "$curl_code"
    fi

    printf '%s' "$output"
}

# Generic GET request
# Usage: gamma_get "/events" "limit=5&active=true"
gamma_get() {
    local path="$1"
    local params="$2"
    local url="${GAMMA_API}${path}"
    if [ -n "$params" ]; then
        url="${url}?${params}"
    fi

    http_get "$url"
}

# Generic Data API GET request
# Usage: data_get "/v1/leaderboard" "limit=5"
data_get() {
    local path="$1"
    local params="$2"
    local url="${DATA_API}${path}"
    if [ -n "$params" ]; then
        url="${url}?${params}"
    fi

    http_get "$url"
}

# Generic CLOB API GET request
# Usage: clob_get "/prices-history" "market=...&startTs=...&endTs=..."
# The /prices-history endpoint is public, so no auth is required. A bearer token
# is attached only when one is available (env var or credentials file), never
# demanded — historical price queries must work with public data alone.
clob_get() {
    local path="$1"
    local params="$2"
    local url="${CLOB_API}${path}"
    local bearer_token

    if [ -n "$params" ]; then
        url="${url}?${params}"
    fi

    bearer_token=$(load_polymarket_bearer_token 2>/dev/null) || bearer_token=""
    if [ -n "$bearer_token" ]; then
        http_get "$url" -H "Authorization: Bearer ${bearer_token}"
    else
        http_get "$url"
    fi
}

# Resolve the credentials file path (agent-neutral). When POLYMARKET_CREDENTIALS_FILE
# is set it is used exclusively; otherwise the first existing candidate wins.
_pm_resolve_credentials_file() {
    if [ -n "${POLYMARKET_CREDENTIALS_FILE:-}" ]; then
        printf '%s' "$POLYMARKET_CREDENTIALS_FILE"
        return 0
    fi

    local candidates=(
        "./.credentials"
        "$HOME/.config/holo-polymarket/credentials"
        "$HOME/.openclaw/credentials/polymarket_credentials"
    )
    local candidate
    for candidate in "${candidates[@]}"; do
        if [ -f "$candidate" ]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

# Load the Polymarket bearer token (env var first, then a credentials file).
load_polymarket_bearer_token() {
    if [ -n "${POLYMARKET_BEARER_TOKEN:-}" ]; then
        echo "$POLYMARKET_BEARER_TOKEN"
        return 0
    fi

    if [ -n "${_POLYMARKET_BEARER_TOKEN:-}" ]; then
        echo "$_POLYMARKET_BEARER_TOKEN"
        return 0
    fi

    local cred_file
    cred_file=$(_pm_resolve_credentials_file) || return 1
    if [ ! -f "$cred_file" ]; then
        return 1
    fi

    # Accept BEARER_TOKEN or TOKEN field names.
    local token
    token=$(awk -F'=' '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        {
            k=$1
            v=substr($0, index($0, "=") + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
            if (k=="BEARER_TOKEN" || k=="TOKEN") {
                print v
                exit
            }
        }
    ' "$cred_file")

    if [ -z "$token" ]; then
        return 1
    fi

    _POLYMARKET_BEARER_TOKEN="$token"
    echo "$token"
}

# Fetch hot events
# Usage: fetch_hot_events [limit]
fetch_hot_events() {
    local limit="${1:-5}"
    gamma_get "/events" "limit=${limit}&active=true&closed=false&order=volume24hr&ascending=false"
}

# Search events
# Usage: search_events <query> [limit]
search_events() {
    local query="$1"
    local limit="${2:-5}"
    local encoded_query

    encoded_query=$(url_encode "$query") || return 1
    gamma_get "/events" "limit=${limit}&active=true&closed=false&title=${encoded_query}"
}

# Fetch event detail (by slug)
# Usage: fetch_event_detail <slug>
fetch_event_detail() {
    local slug="$1"
    local encoded_slug

    encoded_slug=$(url_encode "$slug") || return 1
    gamma_get "/events" "slug=${encoded_slug}"
}

# Fetch leaderboard
# Usage: fetch_leaderboard [limit] [orderBy] [timePeriod]
# orderBy: pnl (default) | vol
# timePeriod: DAY (default) | WEEK | MONTH | ALL
fetch_leaderboard() {
    local limit="${1:-10}"
    local order_by="${2:-pnl}"
    local time_period="${3:-DAY}"

    case "$time_period" in
        DAY|WEEK|MONTH|ALL) ;;
        *) time_period="DAY" ;;
    esac

    data_get "/v1/leaderboard" "limit=${limit}&orderBy=${order_by}&timePeriod=${time_period}"
}

# Fetch user positions
# Usage: fetch_positions <wallet_address> [limit] [sortBy]
# sortBy (values accepted by the Data API): CASHPNL (default) | PERCENTPNL |
#   CURRENT | INITIAL | TOKENS | TITLE | RESOLVING | PRICE | AVGPRICE
fetch_positions() {
    local user="$1"
    local limit="${2:-10}"
    local sort_by="${3:-CASHPNL}"
    local encoded_user

    if [ -z "$user" ]; then
        echo "[]"
        return 1
    fi

    encoded_user=$(url_encode "$user") || return 1
    data_get "/positions" "user=${encoded_user}&limit=${limit}&sortBy=${sort_by}&sortDirection=DESC"
}

# Fetch user trade history
# Usage: fetch_trades <wallet_address> [limit]
fetch_trades() {
    local user="$1"
    local limit="${2:-10}"
    local encoded_user

    if [ -z "$user" ]; then
        echo "[]"
        return 1
    fi

    encoded_user=$(url_encode "$user") || return 1
    data_get "/trades" "user=${encoded_user}&limit=${limit}"
}

# ==================== Historical data and trends ====================

# Get CLOB token ID by market slug
# Usage: get_clob_token_id <market_slug>
get_clob_token_id() {
    local slug="$1"
    local encoded_slug key cached response token_id

    if [ -z "$slug" ]; then
        return 1
    fi

    key=$(cache_key "clob-token-id" "$GAMMA_API" "slug=${slug}")
    if cached=$(cache_get "$key"); then
        echo "$cached"
        return 0
    fi

    encoded_slug=$(url_encode "$slug") || return 1

    # Try an exact match first
    response=$(gamma_get "/markets" "slug=${encoded_slug}") || return 1
    token_id=$(echo "$response" | jq -r '
        .[0] // empty |
        (
            .clobTokenId //
            (
                .clobTokenIds //
                "[]"
                | if type == "string" then (fromjson? // []) else . end
                | .[0]
            )
        ) // empty
    ')

    # If the exact match fails, fall back to search
    if [ -z "$token_id" ] || [ "$token_id" = "null" ]; then
        response=$(gamma_get "/markets" "search=${encoded_slug}&limit=1") || return 1
        token_id=$(echo "$response" | jq -r '
            .[0] // empty |
            (
                .clobTokenId //
                (
                    .clobTokenIds //
                    "[]"
                    | if type == "string" then (fromjson? // []) else . end
                    | .[0]
                )
            ) // empty
        ')
    fi

    if [ -z "$token_id" ] || [ "$token_id" = "null" ]; then
        return 1
    fi

    cache_set "$key" "$token_id" "${CACHE_TTL:-300}" >/dev/null 2>&1
    echo "$token_id"
}

# Validate the interval argument
# Usage: validate_interval <interval>
# Supported: 1h | 4h | 1d
validate_interval() {
    local interval="$1"
    case "$interval" in
        1h|4h|1d)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Validate the time range
# Usage: validate_time_range <from> <to>
# Date format: YYYY-MM-DD, and from <= to
validate_time_range() {
    local from_date="$1"
    local to_date="$2"

    if ! echo "$from_date" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        return 1
    fi
    if ! echo "$to_date" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        return 1
    fi

    local from_epoch
    local to_epoch
    from_epoch=$(date_to_epoch_utc "$from_date" start) || return 1
    to_epoch=$(date_to_epoch_utc "$to_date" start) || return 1
    [ -n "$from_epoch" ] && [ -n "$to_epoch" ] || return 1

    [ "$from_epoch" -le "$to_epoch" ]
}

# Fetch price history data (via market slug -> clobTokenId -> CLOB prices-history)
# Usage: fetch_price_history <market_slug> <from> <to> [interval]
fetch_price_history() {
    local slug="$1"
    local from_date="$2"
    local to_date="$3"
    local interval="${4:-1d}"
    local from_ts to_ts bucket token_id params key cached response

    if [ -z "$slug" ]; then
        echo "[]"
        return 1
    fi
    validate_time_range "$from_date" "$to_date" || {
        echo "[]"
        return 1
    }
    validate_interval "$interval" || {
        echo "[]"
        return 1
    }

    token_id=$(get_clob_token_id "$slug") || {
        echo "[]"
        return 1
    }

    from_ts=$(date_to_epoch_utc "$from_date" "start") || {
        echo "[]"
        return 1
    }
    to_ts=$(date_to_epoch_utc "$to_date" "end") || {
        echo "[]"
        return 1
    }

    case "$interval" in
        1h) bucket=3600 ;;
        4h) bucket=14400 ;;
        1d) bucket=86400 ;;
        *) echo "[]"; return 1 ;;
    esac

    params="market=${token_id}&startTs=${from_ts}&endTs=${to_ts}&fidelity=1"
    key=$(cache_key "history-price" "$CLOB_API" "${params}&interval=${interval}")
    if cached=$(cache_get "$key"); then
        echo "$cached"
        return 0
    fi

    response=$(clob_get "/prices-history" "$params") || {
        echo "[]"
        return 1
    }

    response=$(echo "$response" | jq -c \
        --argjson from "$from_ts" \
        --argjson to "$to_ts" \
        --argjson bucket "$bucket" '
        [ (.history // . // [])[]?
          | {
                timestamp: ((.t // .timestamp // .time // .ts // .date // .datetime // empty) | tonumber?),
                price: ((.p // .price // .value // .close // empty) | tonumber?)
            }
          | select(.timestamp != null and .price != null)
          | select(.timestamp >= $from and .timestamp <= $to)
        ]
        | if $bucket > 1 then
            group_by((.timestamp / $bucket | floor))
            | map(.[-1])
          else
            .
          end
        | sort_by(.timestamp)
    ') || {
        echo "[]"
        return 1
    }

    if [ -z "$response" ] || [ "$response" = "null" ]; then
        response="[]"
    fi

    cache_set "$key" "$response" "${CACHE_TTL:-60}" >/dev/null 2>&1
    echo "$response"
}

# Fetch volume history data
# Usage: fetch_volume_history <event_slug> <from> <to> [interval]
fetch_volume_history() {
    local slug="$1"
    local from_date="$2"
    local to_date="$3"
    local interval="${4:-1d}"
    local encoded_slug params key cached response

    if [ -z "$slug" ]; then
        echo "[]"
        return 1
    fi
    validate_time_range "$from_date" "$to_date" || {
        echo "[]"
        return 1
    }
    validate_interval "$interval" || {
        echo "[]"
        return 1
    }

    encoded_slug=$(url_encode "$slug") || {
        echo "[]"
        return 1
    }

    params="slug=${encoded_slug}&from=${from_date}&to=${to_date}&interval=${interval}"
    key=$(cache_key "history-volume" "$DATA_API" "$params")
    if cached=$(cache_get "$key"); then
        echo "$cached"
        return 0
    fi

    response=$(data_get "/history/volume" "$params") || {
        echo "[]"
        return 1
    }

    if ! echo "$response" | jq -e 'type == "array"' >/dev/null 2>&1; then
        pm_error "Volume history endpoint returned an unexpected response, expected a JSON array"
        echo "[]"
        return 1
    fi

    cache_set "$key" "$response" "${CACHE_TTL:-60}" >/dev/null 2>&1
    echo "$response"
}

# Unified entry point for historical series queries
# Usage: fetch_history_series <price|volume> <market_slug> <from> <to> [interval]
fetch_history_series() {
    local series_type="$1"
    local slug="$2"
    local from_date="$3"
    local to_date="$4"
    local interval="${5:-1d}"

    if [ -z "$slug" ]; then
        echo "[]"
        return 1
    fi

    case "$series_type" in
        price)
            fetch_price_history "$slug" "$from_date" "$to_date" "$interval"
            ;;
        volume)
            fetch_volume_history "$slug" "$from_date" "$to_date" "$interval"
            ;;
        *)
            echo "[]"
            return 1
            ;;
    esac
}
