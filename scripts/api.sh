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
