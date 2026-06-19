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
                    order_label="Volume"
                    ;;
                *)
                    order="pnl"
                    order_label="P&L"
                    ;;
            esac

            echo "🏆 Polymarket leaderboard (by ${order_label}, ${time_period}, Top ${limit})"
            echo ""
            fetch_leaderboard "$limit" "$order" "$time_period" | format_leaderboard
            ;;
        positions|pos)
            local addr="$1"
            local limit="${2:-10}"
            local filter_active=""
            
            # Support the --active flag to filter unresolved positions (can appear at any position)
            if [ "$1" = "--active" ]; then
                filter_active="yes"
                addr="$2"
                limit="${3:-10}"
            elif [ "$2" = "--active" ]; then
                filter_active="yes"
                limit="${3:-10}"
            elif [ "$3" = "--active" ]; then
                filter_active="yes"
            fi
            
            if [ -z "$addr" ]; then
                echo "Usage: bash polymarket.sh positions <wallet-address> [limit] [--active]"
                return 1
            fi

            echo "📊 Positions: $(format_address "$addr")"
            echo ""
            if [ -n "$filter_active" ]; then
                local now
                now=$(date +%Y-%m-%d)
                fetch_positions "$addr" "$limit" | jq --arg now "$now" '[.[] | select(.endDate != "" and .endDate > $now)]' | format_positions
            else
                fetch_positions "$addr" "$limit" | format_positions
            fi
            ;;
        trades)
            local addr="$1"
            local limit="${2:-10}"
            if [ -z "$addr" ]; then
                echo "Usage: bash polymarket.sh trades <wallet-address> [limit]"
                return 1
            fi

            echo "📜 Trade history: $(format_address "$addr")"
            echo ""
            fetch_trades "$addr" "$limit" | format_trades
            ;;
        *)
            return 2
            ;;
    esac

    return 0
}