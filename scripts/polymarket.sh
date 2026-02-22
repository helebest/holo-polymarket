#!/bin/bash
#
# Holo Polymarket - 预测市场查询工具
# 用法: bash polymarket.sh <command> [args...]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载模块
source "$SCRIPT_DIR/api.sh"
source "$SCRIPT_DIR/format.sh"
source "$SCRIPT_DIR/export.sh"

SERIES_SLUG=""
SERIES_FROM_DATE=""
SERIES_TO_DATE=""
SERIES_INTERVAL=""
SERIES_FORMAT=""
SERIES_OUT=""

parse_series_command_args() {
    local cmd_name="$1"
    shift

    local -a positional=()
    SERIES_FORMAT=""
    SERIES_OUT=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --format)
                if [ -z "${2:-}" ]; then
                    echo "参数错误: --format 需要取值"
                    return 1
                fi
                SERIES_FORMAT="$2"
                shift 2
                ;;
            --out)
                if [ -z "${2:-}" ]; then
                    echo "参数错误: --out 需要取值"
                    return 1
                fi
                SERIES_OUT="$2"
                shift 2
                ;;
            --format=*)
                SERIES_FORMAT="${1#*=}"
                shift
                ;;
            --out=*)
                SERIES_OUT="${1#*=}"
                shift
                ;;
            --*)
                echo "未知参数: $1"
                return 1
                ;;
            *)
                positional+=("$1")
                shift
                ;;
        esac
    done

    if [ "${#positional[@]}" -lt 3 ] || [ "${#positional[@]}" -gt 4 ]; then
        echo "用法: bash polymarket.sh ${cmd_name} <event-slug> <from> <to> [interval] [--format csv|json] [--out 文件路径]"
        return 1
    fi

    SERIES_SLUG="${positional[0]}"
    SERIES_FROM_DATE="${positional[1]}"
    SERIES_TO_DATE="${positional[2]}"
    SERIES_INTERVAL="${positional[3]:-1d}"

    if [ -n "$SERIES_OUT" ] && [ -z "$SERIES_FORMAT" ]; then
        echo "参数错误: --out 需要与 --format 一起使用"
        return 1
    fi

    if [ -n "$SERIES_FORMAT" ] && ! validate_export_format "$SERIES_FORMAT"; then
        echo "format 无效: 仅支持 csv/json"
        return 1
    fi

    return 0
}

export_series_if_needed() {
    local result_json="$1"
    local cmd_name="$2"

    if [ -z "$SERIES_FORMAT" ]; then
        return 2
    fi

    local out_file="$SERIES_OUT"
    if [ -z "$out_file" ]; then
        out_file="${cmd_name}-${SERIES_SLUG}-${SERIES_FROM_DATE}-${SERIES_TO_DATE}.${SERIES_FORMAT}"
    fi

    if [ "$SERIES_FORMAT" = "csv" ]; then
        export_to_csv "$result_json" "$out_file" || return 1
    else
        export_to_json "$result_json" "$out_file" || return 1
    fi

    echo "导出完成: ${out_file}"
    return 0
}

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
        parse_series_command_args "history" "$@" || exit 1
        SLUG="$SERIES_SLUG"
        FROM_DATE="$SERIES_FROM_DATE"
        TO_DATE="$SERIES_TO_DATE"
        INTERVAL="$SERIES_INTERVAL"
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
        export_series_if_needed "$RESULT" "history"
        EXPORT_CODE=$?
        if [ "$EXPORT_CODE" -eq 1 ]; then
            exit 1
        elif [ "$EXPORT_CODE" -eq 2 ]; then
            echo "$RESULT" | format_price_history_table
            [ "${PIPESTATUS[1]}" -eq 0 ] || exit 1
        fi
        ;;
    trend)
        parse_series_command_args "trend" "$@" || exit 1
        SLUG="$SERIES_SLUG"
        FROM_DATE="$SERIES_FROM_DATE"
        TO_DATE="$SERIES_TO_DATE"
        INTERVAL="$SERIES_INTERVAL"
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
        export_series_if_needed "$RESULT" "trend"
        EXPORT_CODE=$?
        if [ "$EXPORT_CODE" -eq 1 ]; then
            exit 1
        elif [ "$EXPORT_CODE" -eq 2 ]; then
            echo "$RESULT" | format_trend_summary
            [ "${PIPESTATUS[1]}" -eq 0 ] || exit 1
        fi
        ;;
    volume-trend)
        parse_series_command_args "volume-trend" "$@" || exit 1
        SLUG="$SERIES_SLUG"
        FROM_DATE="$SERIES_FROM_DATE"
        TO_DATE="$SERIES_TO_DATE"
        INTERVAL="$SERIES_INTERVAL"
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
        export_series_if_needed "$RESULT" "volume-trend"
        EXPORT_CODE=$?
        if [ "$EXPORT_CODE" -eq 1 ]; then
            exit 1
        elif [ "$EXPORT_CODE" -eq 2 ]; then
            echo "$RESULT" | format_volume_trend_table
            [ "${PIPESTATUS[1]}" -eq 0 ] || exit 1
        fi
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
        echo "  history <slug> <from> <to> [interval] [--format csv|json] [--out 文件]      历史价格"
        echo "  trend <slug> <from> <to> [interval] [--format csv|json] [--out 文件]        概率趋势"
        echo "  volume-trend <slug> <from> <to> [interval] [--format csv|json] [--out 文件] 交易量趋势"
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
