#!/bin/bash
#
# Polymarket Gamma API 封装
# 所有 API 调用集中在这里，方便测试和替换

GAMMA_API="${GAMMA_API_BASE:-https://gamma-api.polymarket.com}"
CURL_TIMEOUT="${CURL_TIMEOUT:-15}"

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
