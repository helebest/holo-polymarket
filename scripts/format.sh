#!/bin/bash
#
# 格式化 Polymarket API 响应为可读文本

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
