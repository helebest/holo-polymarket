#!/bin/bash
#
# Holo Polymarket - 预测市场查询工具
# 用法: bash polymarket.sh <command> [args...]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载模块
source "$SCRIPT_DIR/api.sh"
source "$SCRIPT_DIR/format.sh"

CMD="$1"
shift || true

case "$CMD" in
    hot)
        LIMIT="${1:-5}"
        echo "🔥 Polymarket 热门预测 (Top ${LIMIT})"
        echo ""
        fetch_hot_events "$LIMIT" | format_hot_events
        ;;
    search)
        QUERY="$1"
        LIMIT="${2:-5}"
        if [ -z "$QUERY" ]; then
            echo "用法: bash polymarket.sh search <关键词> [limit]"
            exit 1
        fi
        echo "🔍 搜索: ${QUERY}"
        echo ""
        RESULT=$(search_events "$QUERY" "$LIMIT")
        if [ "$(echo "$RESULT" | jq 'length')" = "0" ] 2>/dev/null; then
            echo "未找到相关预测市场"
        else
            echo "$RESULT" | format_hot_events
        fi
        ;;
    detail)
        SLUG="$1"
        if [ -z "$SLUG" ]; then
            echo "用法: bash polymarket.sh detail <event-slug>"
            exit 1
        fi
        RESULT=$(fetch_event_detail "$SLUG")
        if [ "$(echo "$RESULT" | jq 'length')" = "0" ] 2>/dev/null; then
            echo "未找到事件: ${SLUG}"
        else
            echo "$RESULT" | format_event_detail
        fi
        ;;
    *)
        echo "Holo Polymarket - 预测市场查询"
        echo ""
        echo "用法: bash polymarket.sh <command> [args...]"
        echo ""
        echo "命令:"
        echo "  hot [limit]              查看热门预测（默认5条）"
        echo "  search <关键词> [limit]  搜索预测市场"
        echo "  detail <event-slug>      查看事件详情"
        echo ""
        echo "示例:"
        echo "  bash polymarket.sh hot 3"
        echo "  bash polymarket.sh search bitcoin"
        echo "  bash polymarket.sh detail fed-decision-in-march-885"
        exit 1
        ;;
esac
