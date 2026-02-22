#!/bin/bash
#
# Polymarket Gamma API 封装
# 所有 API 调用集中在这里，方便测试和替换

GAMMA_API="${GAMMA_API_BASE:-https://gamma-api.polymarket.com}"
CURL_TIMEOUT="${CURL_TIMEOUT:-15}"
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
# 用法: fetch_leaderboard [limit] [orderBy]
# orderBy: pnl (默认) | vol
fetch_leaderboard() {
    local limit="${1:-10}"
    local order_by="${2:-pnl}"
    data_get "/v1/leaderboard" "limit=${limit}&orderBy=${order_by}"
}

# 获取用户持仓
# 用法: fetch_positions <wallet_address> [limit] [sortBy]
# sortBy: TOKENS (默认) | CASH_PNL | PERCENT_PNL | CURRENT_VALUE
fetch_positions() {
    local user="$1"
    local limit="${2:-10}"
    local sort_by="${3:-CASH_PNL}"
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

# 获取价格历史数据
# 用法: fetch_price_history <event_slug> <from> <to> [interval]
fetch_price_history() {
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
    key=$(cache_key "history-price" "$DATA_API" "$params")
    if cached=$(cache_get "$key"); then
        echo "$cached"
        return 0
    fi

    # API skeleton: 统一通过 data-api 获取历史价格
    response=$(data_get "/history/prices" "$params")
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
# 用法: fetch_history_series <price|volume> <event_slug> <from> <to> [interval]
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
