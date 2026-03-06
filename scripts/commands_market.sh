#!/bin/bash
#
# Market query commands.

handle_market_command() {
    local cmd="$1"
    shift || true

    case "$cmd" in
        hot)
            local limit="${1:-5}"
            echo "🔥 Polymarket 热门预测 (Top ${limit})"
            echo ""
            fetch_hot_events "$limit" | format_hot_events
            ;;
        search)
            local query="$1"
            local limit="${2:-5}"
            if [ -z "$query" ]; then
                echo "用法: bash polymarket.sh search <关键词> [limit]"
                return 1
            fi

            echo "🔍 搜索: ${query}"
            echo ""

            local result
            result=$(search_events "$query" "$limit") || return 1
            if [ "$(echo "$result" | jq 'length' 2>/dev/null)" = "0" ]; then
                echo "未找到相关预测市场"
            else
                echo "$result" | format_hot_events
            fi
            ;;
        detail)
            local slug="$1"
            if [ -z "$slug" ]; then
                echo "用法: bash polymarket.sh detail <event-slug>"
                return 1
            fi

            local result
            result=$(fetch_event_detail "$slug") || return 1
            if [ "$(echo "$result" | jq 'length' 2>/dev/null)" = "0" ]; then
                echo "未找到事件: ${slug}"
            else
                echo "$result" | format_event_detail
            fi
            ;;
        *)
            return 2
            ;;
    esac

    return 0
}