#!/bin/bash
#
# Holo Polymarket - prediction market query tool
# Usage: bash polymarket.sh <command> [args...]

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load modules
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/api.sh"
source "$SCRIPT_DIR/format.sh"
source "$SCRIPT_DIR/export.sh"
source "$SCRIPT_DIR/commands_market.sh"
source "$SCRIPT_DIR/commands_whale.sh"
source "$SCRIPT_DIR/commands_series.sh"

print_usage() {
    echo "Holo Polymarket - prediction market tool"
    echo ""
    echo "Usage: bash polymarket.sh <command> [args...]"
    echo ""
    echo "Market queries:"
    echo "  hot [limit]                 Hot markets (default 5)"
    echo "  search <keyword> [limit]    Search prediction markets"
    echo "  detail <event-slug>         View event detail"
    echo ""
    echo "Whale tracking:"
    echo "  leaderboard [limit] [pnl|vol] [day|week|month|all]"
    echo "                              Leaderboard (alias lb)"
    echo "  positions <address> [limit] View positions (alias pos)"
    echo "  trades <address> [limit]    View trade history"
    echo ""
    echo "Historical analysis:  <slug> <from> <to> [interval] [--format csv|json] [--out file]"
    echo "  history                     Price history"
    echo "  trend                       Probability trend"
    echo "  volume-trend                Volume trend"
    echo ""
    echo "This skill is read-only. For trading (buy/sell/cancel),"
    echo "use the polymarket-trade skill (Python, dry-run by default)."
    echo ""
    echo "Examples:"
    echo "  bash polymarket.sh hot 3"
    echo "  bash polymarket.sh search bitcoin"
    echo "  bash polymarket.sh detail fed-decision-in-march-885"
    echo "  bash polymarket.sh lb 10 pnl week"
    echo "  bash polymarket.sh positions 0xc257ea7e...358e"
    echo "  bash polymarket.sh history fed-decision-in-march-885 2025-01-01 2025-01-31 1d"
    echo "  bash polymarket.sh trend fed-decision-in-march-885 2025-01-01 2025-01-31 --format csv"
}

main() {
    require_commands curl jq || return 1

    local cmd="$1"
    shift || true

    case "$cmd" in
        hot|search|detail)
            handle_market_command "$cmd" "$@"
            ;;
        leaderboard|lb|positions|pos|trades)
            handle_whale_command "$cmd" "$@"
            ;;
        history|trend|volume-trend)
            handle_series_command "$cmd" "$@"
            ;;
        *)
            print_usage
            return 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
