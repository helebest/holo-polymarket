#!/bin/bash
#
# Holo Polymarket - 预测市场查询工具
# 用法: bash polymarket.sh <command> [args...]

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载模块
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/api.sh"
source "$SCRIPT_DIR/format.sh"
source "$SCRIPT_DIR/export.sh"
source "$SCRIPT_DIR/commands_market.sh"
source "$SCRIPT_DIR/commands_whale.sh"
source "$SCRIPT_DIR/commands_series.sh"

print_usage() {
    echo "Holo Polymarket - 预测市场工具"
    echo ""
    echo "用法: bash polymarket.sh <command> [args...]"
    echo ""
    echo "市场查询:"
    echo "  hot [limit]                 热门预测（默认 5 条）"
    echo "  search <关键词> [limit]     搜索预测市场"
    echo "  detail <event-slug>         查看事件详情"
    echo ""
    echo "大户追踪:"
    echo "  leaderboard [limit] [pnl|vol] [day|week|month|all]"
    echo "                              排行榜（别名 lb）"
    echo "  positions <地址> [limit]    查看持仓（别名 pos）"
    echo "  trades <地址> [limit]       查看交易记录"
    echo ""
    echo "历史分析:  <slug> <from> <to> [interval] [--format csv|json] [--out 文件]"
    echo "  history                     历史价格"
    echo "  trend                       概率趋势"
    echo "  volume-trend                交易量趋势"
    echo ""
    echo "交易功能请使用官方 Polymarket CLI:"
    echo "  https://github.com/Polymarket/polymarket-cli"
    echo ""
    echo "示例:"
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
