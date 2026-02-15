#!/bin/bash
#
# 格式化 Polymarket API 响应为可读文本

# 格式化钱包地址（截断显示）
# 0xc257ea7e...fa358e → 0xc257…358e
format_address() {
    local addr="$1"
    if [ ${#addr} -le 10 ]; then
        echo "$addr"
        return
    fi
    echo "${addr:0:6}…${addr: -4}"
}

# 格式化盈亏金额（带 +/- 符号和千位逗号）
# 1234.56 → +$1,234.56  |  -567.89 → -$567.89  |  0 → $0.00
format_pnl() {
    local val="$1"
    echo "$val" | awk '{
        v = $1 + 0
        if (v > 0) sign = "+"
        else if (v < 0) { sign = "-"; v = -v }
        else sign = ""

        # 格式化为2位小数
        formatted = sprintf("%.2f", v)

        # 分离整数和小数
        split(formatted, parts, ".")
        integer = parts[1]
        decimal = parts[2]

        # 从右往左添加千位逗号
        result = ""
        len = length(integer)
        for (i = len; i >= 1; i--) {
            if (result != "" && (len - i + 1) % 3 == 1) result = "," result
            result = substr(integer, i, 1) result
        }
        printf "%s$%s.%s", sign, result, decimal
    }'
}

# 格式化金额（美元）
format_volume() {
    local vol="$1"
    if [ -z "$vol" ] || [ "$vol" = "null" ]; then
        echo "\$0"
        return
    fi
    # 用 awk 处理浮点数
    echo "$vol" | awk '{
        if ($1 >= 1000000000) printf "$%.1fB", $1/1000000000
        else if ($1 >= 1000000) printf "$%.1fM", $1/1000000
        else if ($1 >= 1000) printf "$%.1fK", $1/1000
        else printf "$%.0f", $1
    }'
}

# 格式化概率（0.xx → xx%）
format_prob() {
    local price="$1"
    if [ -z "$price" ] || [ "$price" = "null" ]; then
        echo "N/A"
        return
    fi
    echo "$price" | awk '{ printf "%.1f%%", $1 * 100 }'
}

# 格式化热门事件列表
# 输入: JSON 数组（从 stdin）
format_hot_events() {
    jq -r '
        to_entries[] |
        .key as $i |
        .value |
        "\($i + 1). \(.title)" ,
        (
            if (.markets // [] | length) == 0 then
                "   (无市场数据)"
            elif (.markets | length) <= 4 then
                .markets[] |
                "   \(.groupItemTitle // .question): \(
                    if .outcomePrices then
                        (.outcomePrices | fromjson | .[0] | tonumber * 100 | . * 10 | round / 10 | tostring) + "%"
                    else "N/A"
                    end
                )"
            else
                (.markets | map(select(.outcomePrices != null)) | sort_by(- (.outcomePrices | fromjson | .[0] | tonumber)) | .[0:3][] |
                "   \(.groupItemTitle // .question): \(
                    (.outcomePrices | fromjson | .[0] | tonumber * 100 | . * 10 | round / 10 | tostring) + "%"
                )") ,
                "   ... 共 \(.markets | length) 个选项"
            end
        ) ,
        "   📊 24h: \(if .volume24hr then (.volume24hr | tonumber | if . >= 1000000 then (. / 1000000 * 10 | round / 10 | tostring) + "M" elif . >= 1000 then (. / 1000 * 10 | round / 10 | tostring) + "K" else tostring end) else "N/A" end) | 总量: \(if .volume then (.volume | tonumber | if . >= 1000000 then (. / 1000000 * 10 | round / 10 | tostring) + "M" elif . >= 1000 then (. / 1000 * 10 | round / 10 | tostring) + "K" else tostring end) else "N/A" end)",
        "   🔗 https://polymarket.com/event/\(.slug)",
        ""
    '
}

# 格式化事件详情
# 输入: JSON 数组（单个事件，从 stdin）
format_event_detail() {
    jq -r '
        .[0] // empty |
        "📌 \(.title)\n",
        (if .description and (.description | length) > 0 then
            "📝 " + (.description | split("\n") | .[0:3] | join("\n   "))
        else "" end),
        "\n📊 市场选项:\n",
        (
            .markets | sort_by(- (.outcomePrices | fromjson | .[0] | tonumber))[] |
            "  • \(.groupItemTitle // .question): \(
                (.outcomePrices | fromjson | .[0] | tonumber * 100 * 10 | round / 10 | . * 100 | round / 100 | tostring | if test("\\.") then . else . + ".0" end) + "%"
            ) (24h量: \(
                if .volume24hr then
                    (.volume24hr | tonumber | if . >= 1000000 then (. / 1000000 * 10 | round / 10 | tostring) + "M"
                    elif . >= 1000 then (. / 1000 * 10 | round / 10 | tostring) + "K"
                    else (. | round | tostring) end)
                else "N/A" end
            ))"
        ),
        "\n🔗 https://polymarket.com/event/\(.slug)"
    '
}

# ============================================================
# Data API 格式化函数
# ============================================================

# 格式化排行榜
# 输入: JSON 数组（从 stdin）
format_leaderboard() {
    local input
    input=$(cat)
    local len
    len=$(echo "$input" | jq 'length' 2>/dev/null)
    if [ -z "$len" ] || [ "$len" = "0" ]; then
        echo "暂无数据"
        return
    fi
    echo "$input" | jq -r '
        .[] |
        "#\(.rank) \(.userName)" +
        (if .xUsername != "" and .xUsername != null then " (@\(.xUsername))" else "" end) +
        (if .verifiedBadge then " ✅" else "" end),
        "   💰 盈亏: \(
            if .pnl > 0 then "+$" + (.pnl * 100 | round / 100 | tostring)
            elif .pnl < 0 then "-$" + ((-.pnl) * 100 | round / 100 | tostring)
            else "$0.00" end
        ) | 交易量: $\(.vol | . * 100 | round / 100 | tostring)",
        "   🔑 \(.proxyWallet | "\(.[0:6])…\(.[-4:])")",
        ""
    '
}

# 格式化用户持仓
# 输入: JSON 数组（从 stdin）
format_positions() {
    local input
    input=$(cat)
    local len
    len=$(echo "$input" | jq 'length' 2>/dev/null)
    if [ -z "$len" ] || [ "$len" = "0" ]; then
        echo "暂无持仓"
        return
    fi
    echo "$input" | jq -r '
        to_entries[] |
        .key as $i |
        .value |
        "\($i + 1). \(.title)" +
        (if .outcome then " [\(.outcome)]" else "" end),
        "   " +
        (if (.cashPnl // 0) >= 0 then "📈" else "📉" end) +
        " 持仓: \(.size // 0 | . * 100 | round / 100) | 现值: $\(.currentValue // 0 | . * 100 | round / 100)",
        "   💰 盈亏: \(
            if (.cashPnl // 0) > 0 then "+$\(.cashPnl | . * 100 | round / 100)"
            elif (.cashPnl // 0) < 0 then "-$\((-.cashPnl) | . * 100 | round / 100)"
            else "$0.00" end
        ) (\(.percentPnl // 0 | . * 100 | round / 100)%)",
        ""
    '
}

# 格式化用户交易记录
# 输入: JSON 数组（从 stdin）
format_trades() {
    local input
    input=$(cat)
    local len
    len=$(echo "$input" | jq 'length' 2>/dev/null)
    if [ -z "$len" ] || [ "$len" = "0" ]; then
        echo "暂无交易"
        return
    fi
    echo "$input" | jq -r '
        .[] |
        (if .side == "BUY" then "🟢 买入" else "🔴 卖出" end) +
        " | \(.title)" +
        (if .outcome then " [\(.outcome)]" else "" end),
        "   💵 数量: \(.size // 0 | . * 100 | round / 100) @ $\(.price // 0 | . * 10000 | round / 10000)" +
        " | 🕐 \(.timestamp // 0 | todate | split("T") | .[0] + " " + (.[1] | split("Z") | .[0] | .[0:5]) + " UTC")",
        ""
    '
}
