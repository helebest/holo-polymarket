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
    leaderboard|lb)
        LIMIT="${1:-10}"
        ORDER="${2:-pnl}"
        if [ "$ORDER" = "vol" ] || [ "$ORDER" = "volume" ]; then
            echo "🏆 Polymarket 排行榜 (按交易量, Top ${LIMIT})"
            ORDER="vol"
        else
            echo "🏆 Polymarket 排行榜 (按盈利, Top ${LIMIT})"
            ORDER="pnl"
        fi
        echo ""
        fetch_leaderboard "$LIMIT" "$ORDER" | format_leaderboard
        ;;
    positions|pos)
        ADDR="$1"
        LIMIT="${2:-10}"
        if [ -z "$ADDR" ]; then
            echo "用法: bash polymarket.sh positions <钱包地址> [limit]"
            exit 1
        fi
        echo "📊 持仓查询: $(format_address "$ADDR")"
        echo ""
        fetch_positions "$ADDR" "$LIMIT" | format_positions
        ;;
    trades)
        ADDR="$1"
        LIMIT="${2:-10}"
        if [ -z "$ADDR" ]; then
            echo "用法: bash polymarket.sh trades <钱包地址> [limit]"
            exit 1
        fi
        echo "📜 交易记录: $(format_address "$ADDR")"
        echo ""
        fetch_trades "$ADDR" "$LIMIT" | format_trades
        ;;
    history)
        SLUG="$1"
        FROM_DATE="$2"
        TO_DATE="$3"
        INTERVAL="${4:-1d}"
        if [ -z "$SLUG" ] || [ -z "$FROM_DATE" ] || [ -z "$TO_DATE" ]; then
            echo "用法: bash polymarket.sh history <event-slug> <from> <to> [interval]"
            exit 1
        fi
        if ! validate_time_range "$FROM_DATE" "$TO_DATE"; then
            echo "时间范围无效: from/to 必须是 YYYY-MM-DD 且 from <= to"
            exit 1
        fi
        if ! validate_interval "$INTERVAL"; then
            echo "interval 无效: 仅支持 1h/4h/1d"
            exit 1
        fi
        echo "🕒 历史价格: ${SLUG} | ${FROM_DATE} -> ${TO_DATE} | ${INTERVAL}"
        echo ""
        RESULT=$(fetch_history_series "price" "$SLUG" "$FROM_DATE" "$TO_DATE" "$INTERVAL")
        echo "$RESULT" | format_price_history_table
        [ "${PIPESTATUS[1]}" -eq 0 ] || exit 1
        ;;
    trend)
        SLUG="$1"
        FROM_DATE="$2"
        TO_DATE="$3"
        INTERVAL="${4:-1d}"
        if [ -z "$SLUG" ] || [ -z "$FROM_DATE" ] || [ -z "$TO_DATE" ]; then
            echo "用法: bash polymarket.sh trend <event-slug> <from> <to> [interval]"
            exit 1
        fi
        if ! validate_time_range "$FROM_DATE" "$TO_DATE"; then
            echo "时间范围无效: from/to 必须是 YYYY-MM-DD 且 from <= to"
            exit 1
        fi
        if ! validate_interval "$INTERVAL"; then
            echo "interval 无效: 仅支持 1h/4h/1d"
            exit 1
        fi
        echo "📈 概率趋势: ${SLUG} | ${FROM_DATE} -> ${TO_DATE} | ${INTERVAL}"
        echo ""
        RESULT=$(fetch_history_series "price" "$SLUG" "$FROM_DATE" "$TO_DATE" "$INTERVAL")
        echo "$RESULT" | format_trend_summary
        [ "${PIPESTATUS[1]}" -eq 0 ] || exit 1
        ;;
    volume-trend)
        SLUG="$1"
        FROM_DATE="$2"
        TO_DATE="$3"
        INTERVAL="${4:-1d}"
        if [ -z "$SLUG" ] || [ -z "$FROM_DATE" ] || [ -z "$TO_DATE" ]; then
            echo "用法: bash polymarket.sh volume-trend <event-slug> <from> <to> [interval]"
            exit 1
        fi
        if ! validate_time_range "$FROM_DATE" "$TO_DATE"; then
            echo "时间范围无效: from/to 必须是 YYYY-MM-DD 且 from <= to"
            exit 1
        fi
        if ! validate_interval "$INTERVAL"; then
            echo "interval 无效: 仅支持 1h/4h/1d"
            exit 1
        fi
        echo "📊 交易量趋势: ${SLUG} | ${FROM_DATE} -> ${TO_DATE} | ${INTERVAL}"
        echo ""
        RESULT=$(fetch_history_series "volume" "$SLUG" "$FROM_DATE" "$TO_DATE" "$INTERVAL")
        echo "$RESULT" | format_volume_trend_table
        [ "${PIPESTATUS[1]}" -eq 0 ] || exit 1
        ;;
    *)
        echo "Holo Polymarket - 预测市场工具"
        echo ""
        echo "用法: bash polymarket.sh <command> [args...]"
        echo ""
        echo "命令:"
        echo "  hot [limit]                    查看热门预测（默认5条）"
        echo "  search <关键词> [limit]        搜索预测市场"
        echo "  detail <event-slug>            查看事件详情"
        echo "  leaderboard [limit] [pnl|vol]  查看排行榜（默认按盈利）"
        echo "  positions <地址> [limit]       查看用户持仓"
        echo "  trades <地址> [limit]          查看用户交易记录"
        echo "  history <slug> <from> <to> [interval]      历史价格"
        echo "  trend <slug> <from> <to> [interval]        概率趋势"
        echo "  volume-trend <slug> <from> <to> [interval] 交易量趋势"
        echo ""
        echo "别名: lb = leaderboard, pos = positions"
        echo ""
        echo "示例:"
        echo "  bash polymarket.sh hot 3"
        echo "  bash polymarket.sh search bitcoin"
        echo "  bash polymarket.sh lb 5 vol"
        echo "  bash polymarket.sh positions 0xc257ea7e...358e 10"
        echo "  bash polymarket.sh trades 0xc257ea7e...358e 5"
        echo "  bash polymarket.sh history fed-decision-in-march-885 2025-01-01 2025-01-31 1d"
        exit 1
        ;;
esac
