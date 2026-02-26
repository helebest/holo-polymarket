#!/bin/bash
#
# Polymarket Gamma API 封装
# 所有 API 调用集中在这里，方便测试和替换

GAMMA_API="${GAMMA_API_BASE:-https://gamma-api.polymarket.com}"
CLOB_API="${CLOB_API_BASE:-https://clob.polymarket.com}"
CURL_TIMEOUT="${CURL_TIMEOUT:-15}"
POLYMARKET_CREDENTIALS_FILE="${POLYMARKET_CREDENTIALS_FILE:-$HOME/.openclaw/credentials/polymarket_credentials}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cache.sh"

# 通用 GET 请求
# 用法: gamma_get "/events" "limit=5&active=true"
gamma_get() {
    local path="$1"
    local params="$2"
    local url="${GAMMA_API}${path}"
    if [ -n "$params" ]; then
        url="${url}?${params}"
    fi
    curl -s --max-time "$CURL_TIMEOUT" "$url"
}

# 读取 Polymarket Bearer Token（优先环境变量，其次 credentials 文件）
load_polymarket_bearer_token() {
    if [ -n "${POLYMARKET_BEARER_TOKEN:-}" ]; then
        echo "$POLYMARKET_BEARER_TOKEN"
        return 0
    fi

    if [ -n "${_POLYMARKET_BEARER_TOKEN:-}" ]; then
        echo "$_POLYMARKET_BEARER_TOKEN"
        return 0
    fi

    if [ ! -f "$POLYMARKET_CREDENTIALS_FILE" ]; then
        return 1
    fi

    # 兼容 BEARER_TOKEN/TOKEN/API_KEY 三种字段名
    local token
    token=$(awk -F'=' '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        {
            k=$1
            v=$2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
            if (k=="BEARER_TOKEN" || k=="TOKEN" || k=="API_KEY") {
                print v
                exit
            }
        }
    ' "$POLYMARKET_CREDENTIALS_FILE")

    if [ -z "$token" ]; then
        return 1
    fi

    _POLYMARKET_BEARER_TOKEN="$token"
    echo "$token"
}

# 通用 CLOB API GET 请求（Bearer Token 认证）
# 用法: clob_get "/prices-history" "market=...&startTs=...&endTs=..."
clob_get() {
    local path="$1"
    local params="$2"
    local url="${CLOB_API}${path}"
    local bearer_token

    if [ -n "$params" ]; then
        url="${url}?${params}"
    fi

    bearer_token=$(load_polymarket_bearer_token) || return 1
    curl -s --max-time "$CURL_TIMEOUT" \
        -H "Authorization: Bearer ${bearer_token}" \
        "$url"
}

# 读取 Polymarket 凭据（L2 认证用）
load_clob_credentials() {
    if [ ! -f "$POLYMARKET_CREDENTIALS_FILE" ]; then
        return 1
    fi
    
    # 读取 API_KEY, SECRET, PASSPHRASE, ADDRESS
    export POLY_API_KEY=$(grep "^API_KEY=" "$POLYMARKET_CREDENTIALS_FILE" | cut -d'=' -f2)
    export POLY_SECRET=$(grep "^SECRET=" "$POLYMARKET_CREDENTIALS_FILE" | cut -d'=' -f2)
    export POLY_PASSPHRASE=$(grep "^PASSPHRASE=" "$POLYMARKET_CREDENTIALS_FILE" | cut -d'=' -f2)
    # 如果没有 ADDRESS，使用默认地址或从环境变量读取
    export POLY_ADDRESS="${POLY_ADDRESS:-$(grep "^ADDRESS=" "$POLYMARKET_CREDENTIALS_FILE" | cut -d'=' -f2)}"
    
    if [ -z "$POLY_API_KEY" ] || [ -z "$POLY_SECRET" ]; then
        return 1
    fi
}

# 生成 L2 认证签名
# 用法: generate_clob_signature <method> <path> <body> <timestamp>
generate_clob_signature() {
    local method="$1"
    local path="$2"
    local body="$3"
    local timestamp="$4"
    
    # 构建待签名字符串: timestamp + method + path + body
    local string_to_sign="${timestamp}${method}${path}${body}"
    
    # 使用 HMAC-SHA256
    echo -n "$string_to_sign" | openssl dgst -sha256 -hmac "$POLY_SECRET" -binary | base64
}

# 通用 CLOB API POST 请求（L2 认证）
# 用法: clob_post "/order" '{"token_id":"...","price":0.5,"size":10,"side":"BUY"}'
clob_post() {
    local path="$1"
    local data="$2"
    local url="${CLOB_API}${path}"
    
    # 加载凭据
    load_clob_credentials || { echo '{"error": "failed to load credentials"}'; return 1; }
    
    # 生成认证 headers
    local timestamp=$(date +%s)
    local signature=$(generate_clob_signature "POST" "$path" "$data" "$timestamp")
    
    curl -s --max-time "$CURL_TIMEOUT" -X POST \
        -H "Content-Type: application/json" \
        -H "POLY_ADDRESS: ${POLY_ADDRESS}" \
        -H "POLY_API_KEY: ${POLY_API_KEY}" \
        -H "POLY_TIMESTAMP: ${timestamp}" \
        -H "POLY_SIGNATURE: ${signature}" \
        -H "POLY_PASSPHRASE: ${POLY_PASSPHRASE}" \
        -d "$data" \
        "$url"
}

# 通用 CLOB API DELETE 请求（L2 认证）
# 用法: clob_delete "/orders/<order_id>"
clob_delete() {
    local path="$1"
    local url="${CLOB_API}${path}"
    
    # 加载凭据
    load_clob_credentials || { echo '{"error": "failed to load credentials"}'; return 1; }
    
    # 生成认证 headers
    local timestamp=$(date +%s)
    local signature=$(generate_clob_signature "DELETE" "$path" "" "$timestamp")
    
    curl -s --max-time "$CURL_TIMEOUT" -X DELETE \
        -H "POLY_ADDRESS: ${POLY_ADDRESS}" \
        -H "POLY_API_KEY: ${POLY_API_KEY}" \
        -H "POLY_TIMESTAMP: ${timestamp}" \
        -H "POLY_SIGNATURE: ${signature}" \
        -H "POLY_PASSPHRASE: ${POLY_PASSPHRASE}" \
        "$url"
}

# 获取热门事件
# 用法: fetch_hot_events [limit]
fetch_hot_events() {
    local limit="${1:-5}"
    gamma_get "/events" "limit=${limit}&active=true&closed=false&order=volume24hr&ascending=false"
}

# 搜索事件
# 用法: search_events <query> [limit]
search_events() {
    local query="$1"
    local limit="${2:-5}"
    # Gamma API 支持 title 模糊搜索 via slug 或用 _q 参数
    gamma_get "/events" "limit=${limit}&active=true&closed=false&title=${query}"
}

# 获取事件详情（通过 slug）
# 用法: fetch_event_detail <slug>
fetch_event_detail() {
    local slug="$1"
    gamma_get "/events" "slug=${slug}"
}

# ============================================================
# Polymarket Data API 封装
# Base URL: https://data-api.polymarket.com
# 公开免费，无需认证
# ============================================================

DATA_API="${DATA_API_BASE:-https://data-api.polymarket.com}"

# 通用 Data API GET 请求
# 用法: data_get "/v1/leaderboard" "limit=5"
data_get() {
    local path="$1"
    local params="$2"
    local url="${DATA_API}${path}"
    if [ -n "$params" ]; then
        url="${url}?${params}"
    fi
    curl -s --max-time "$CURL_TIMEOUT" "$url"
}

# 获取排行榜
# 用法: fetch_leaderboard [limit] [orderBy] [timePeriod]
# orderBy: pnl (默认) | vol
# timePeriod: DAY (默认) | WEEK | MONTH | ALL
fetch_leaderboard() {
    local limit="${1:-10}"
    local order_by="${2:-pnl}"
    local time_period="${3:-DAY}"
    
    # 验证 timePeriod
    case "$time_period" in
        DAY|WEEK|MONTH|ALL) ;;
        *) time_period="DAY" ;;
    esac
    
    data_get "/v1/leaderboard" "limit=${limit}&orderBy=${order_by}&timePeriod=${time_period}"
}

# 获取用户持仓
# 用法: fetch_positions <wallet_address> [limit] [sortBy]
# sortBy: TOKENS (默认) | CASH_PNL | PERCENT_PNL | CURRENT_VALUE
fetch_positions() {
    local user="$1"
    local limit="${2:-10}"
    local sort_by="${3:-CASHPNL}"
    if [ -z "$user" ]; then
        echo "[]"
        return 1
    fi
    data_get "/positions" "user=${user}&limit=${limit}&sortBy=${sort_by}&sortDirection=DESC"
}

# 获取用户交易记录
# 用法: fetch_trades <wallet_address> [limit]
fetch_trades() {
    local user="$1"
    local limit="${2:-10}"
    if [ -z "$user" ]; then
        echo "[]"
        return 1
    fi
    data_get "/trades" "user=${user}&limit=${limit}"
}

# ==================== Phase 2b: 历史数据与趋势 ====================

# 通过市场 slug 获取 CLOB token ID
# 用法: get_clob_token_id <market_slug>
get_clob_token_id() {
    local slug="$1"
    local key cached response token_id

    if [ -z "$slug" ]; then
        return 1
    fi

    key=$(cache_key "clob-token-id" "$GAMMA_API" "slug=${slug}")
    if cached=$(cache_get "$key"); then
        echo "$cached"
        return 0
    fi

    # 先尝试精确匹配
    response=$(gamma_get "/markets" "slug=${slug}")
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

    # 如果精确匹配失败，尝试 search
    if [ -z "$token_id" ] || [ "$token_id" = "null" ]; then
        response=$(gamma_get "/markets" "search=${slug}&limit=1")
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

# 下单（市价单/限价单）
# 用法: place_order <token_id> <price> <size> <side> [order_type]
# side: BUY | SELL
# order_type: GTC (默认) | FOK | IOC
place_order() {
    local token_id="$1"
    local price="$2"
    local size="$3"
    local side="$4"
    local order_type="${5:-GTC}"

    if [ -z "$token_id" ] || [ -z "$price" ] || [ -z "$size" ] || [ -z "$side" ]; then
        echo '{"error": "missing required parameters"}'
        return 1
    fi

    # 验证 side
    case "$side" in
        BUY|SELL) ;;
        *) echo '{"error": "side must be BUY or SELL"}'; return 1 ;;
    esac

    # 构建订单 JSON
    local order_json
    order_json=$(cat <<EOF
{
    "token_id": "$token_id",
    "price": $price,
    "size": $size,
    "side": "$side",
    "order_type": "$order_type"
}
EOF
)

    clob_post "/orders" "$order_json"
}

# 验证 interval 参数
# 用法: validate_interval <interval>
# 支持: 1h | 4h | 1d
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

# 验证时间范围
# 用法: validate_time_range <from> <to>
# 日期格式: YYYY-MM-DD, 且 from <= to
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
    from_epoch=$(date -d "$from_date" +%s 2>/dev/null) || return 1
    to_epoch=$(date -d "$to_date" +%s 2>/dev/null) || return 1

    [ "$from_epoch" -le "$to_epoch" ]
}

# 获取价格历史数据（通过 market slug -> clobTokenId -> CLOB prices-history）
# 用法: fetch_price_history <market_slug> <from> <to> [interval]
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

    from_ts=$(date -u -d "${from_date} 00:00:00" +%s 2>/dev/null) || {
        echo "[]"
        return 1
    }
    to_ts=$(date -u -d "${to_date} 23:59:59" +%s 2>/dev/null) || {
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
    ')
    if [ -z "$response" ] || [ "$response" = "null" ]; then
        response="[]"
    fi

    cache_set "$key" "$response" "${CACHE_TTL:-60}" >/dev/null 2>&1
    echo "$response"
}

# 获取交易量历史数据
# 用法: fetch_volume_history <event_slug> <from> <to> [interval]
fetch_volume_history() {
    local slug="$1"
    local from_date="$2"
    local to_date="$3"
    local interval="${4:-1d}"
    local params key cached response

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

    params="slug=${slug}&from=${from_date}&to=${to_date}&interval=${interval}"
    key=$(cache_key "history-volume" "$DATA_API" "$params")
    if cached=$(cache_get "$key"); then
        echo "$cached"
        return 0
    fi

    # API skeleton: 统一通过 data-api 获取历史交易量
    response=$(data_get "/history/volume" "$params")
    cache_set "$key" "$response" "${CACHE_TTL:-60}" >/dev/null 2>&1
    echo "$response"
}

# 统一历史序列查询入口
# 用法: fetch_history_series <price|volume> <market_slug> <from> <to> [interval]
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
