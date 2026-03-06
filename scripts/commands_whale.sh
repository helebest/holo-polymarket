#!/bin/bash
#
# Whale tracking commands.

normalize_time_period() {
    local raw="$1"
    case "$raw" in
        d|day|DAY) echo "DAY" ;;
        w|week|WEEK) echo "WEEK" ;;
        m|month|MONTH) echo "MONTH" ;;
        a|all|ALL) echo "ALL" ;;
        *) echo "DAY" ;;
    esac
}

handle_whale_command() {
    local cmd="$1"
    shift || true

    case "$cmd" in
        leaderboard|lb)
            local limit="${1:-10}"
            local order="${2:-pnl}"
            local time_period="${3:-DAY}"

            if [ "$1" = "-t" ] || [ "$1" = "--time" ]; then
                time_period="${2:-DAY}"
                limit="${3:-10}"
                order="${4:-pnl}"
            fi

            time_period="$(normalize_time_period "$time_period")"

            local order_label
            case "$order" in
                vol|volume)
                    order="vol"
                    order_label="交易量"
                    ;;
                *)
                    order="pnl"
                    order_label="盈利"
                    ;;
            esac

            echo "🏆 Polymarket 排行榜 (按${order_label}, ${time_period}, Top ${limit})"
            echo ""
            fetch_leaderboard "$limit" "$order" "$time_period" | format_leaderboard
            ;;
        positions|pos)
            local addr="$1"
            local limit="${2:-10}"
            if [ -z "$addr" ]; then
                echo "用法: bash polymarket.sh positions <钱包地址> [limit]"
                return 1
            fi

            echo "📊 持仓查询: $(format_address "$addr")"
            echo ""
            fetch_positions "$addr" "$limit" | format_positions
            ;;
        trades)
            local addr="$1"
            local limit="${2:-10}"
            if [ -z "$addr" ]; then
                echo "用法: bash polymarket.sh trades <钱包地址> [limit]"
                return 1
            fi

            echo "📜 交易记录: $(format_address "$addr")"
            echo ""
            fetch_trades "$addr" "$limit" | format_trades
            ;;
        *)
            return 2
            ;;
    esac

    return 0
}