#!/bin/bash
#
# 导出工具：支持 CSV/JSON 导出

# 校验导出格式
# 用法: validate_export_format <csv|json>
validate_export_format() {
    local format="$1"
    case "$format" in
        csv|json)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 将时间戳/日期值转换为 YYYY-MM-DD
_export_series_date() {
    local raw="$1"
    if [ -z "$raw" ] || [ "$raw" = "null" ]; then
        echo "N/A"
        return
    fi

    if echo "$raw" | grep -Eq '^[0-9]+$'; then
        local ts="$raw"
        if [ "$ts" -gt 9999999999 ] 2>/dev/null; then
            ts=$((ts / 1000))
        fi
        date -u -d "@$ts" +%Y-%m-%d 2>/dev/null || echo "N/A"
        return
    fi

    if echo "$raw" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
        echo "${raw:0:10}"
        return
    fi

    echo "N/A"
}

# 检测序列值列名（price/volume/value）
_detect_value_column() {
    local input="$1"
    if echo "$input" | jq -e 'any(.[]?; has("price"))' >/dev/null 2>&1; then
        echo "price"
        return
    fi
    if echo "$input" | jq -e 'any(.[]?; has("volume"))' >/dev/null 2>&1; then
        echo "volume"
        return
    fi
    echo "value"
}

# 将 JSON 序列导出为 CSV
# 用法: export_to_csv <json_array> <outfile>
export_to_csv() {
    local input="$1"
    local outfile="$2"

    if ! echo "$input" | jq -e 'type == "array"' >/dev/null 2>&1; then
        echo "导出失败: 数据格式无效（需为 JSON 数组）" >&2
        return 1
    fi
    if [ -z "$outfile" ]; then
        echo "导出失败: 缺少输出文件路径" >&2
        return 1
    fi

    local out_dir
    out_dir="$(dirname "$outfile")"
    if [ ! -d "$out_dir" ]; then
        echo "导出失败: 输出目录不存在: $out_dir" >&2
        return 1
    fi

    local value_col
    value_col="$(_detect_value_column "$input")"

    local tmp_file
    tmp_file=$(mktemp "${out_dir}/.export_csv.XXXXXX") || {
        echo "导出失败: 无法创建临时文件" >&2
        return 1
    }

    {
        printf "date,%s\n" "$value_col"
        echo "$input" | jq -r --arg col "$value_col" '
            .[] |
            [
                (.timestamp // .time // .ts // .date // .datetime // ""),
                (
                    if $col == "price" then (.price // .value // .close // .p // "")
                    elif $col == "volume" then (.volume // .value // .vol // "")
                    else (.value // .price // .volume // .close // .p // .vol // "")
                    end
                )
            ] | @tsv
        ' | while IFS=$'\t' read -r raw_time raw_value; do
            local day
            day=$(_export_series_date "$raw_time")
            printf "%s,%s\n" "$day" "$raw_value"
        done
    } > "$tmp_file" 2>/dev/null || {
        rm -f "$tmp_file"
        echo "导出失败: 写入文件失败" >&2
        return 1
    }

    mv "$tmp_file" "$outfile" 2>/dev/null || {
        rm -f "$tmp_file"
        echo "导出失败: 写入文件失败" >&2
        return 1
    }
}

# 将 JSON 序列导出为标准 JSON 包装结构
# 用法: export_to_json <json_array> <outfile>
export_to_json() {
    local input="$1"
    local outfile="$2"

    if ! echo "$input" | jq -e 'type == "array"' >/dev/null 2>&1; then
        echo "导出失败: 数据格式无效（需为 JSON 数组）" >&2
        return 1
    fi
    if [ -z "$outfile" ]; then
        echo "导出失败: 缺少输出文件路径" >&2
        return 1
    fi

    local out_dir
    out_dir="$(dirname "$outfile")"
    if [ ! -d "$out_dir" ]; then
        echo "导出失败: 输出目录不存在: $out_dir" >&2
        return 1
    fi

    local tmp_file
    tmp_file=$(mktemp "${out_dir}/.export_json.XXXXXX") || {
        echo "导出失败: 无法创建临时文件" >&2
        return 1
    }

    jq -n \
        --arg schema_version "1.0" \
        --arg exported_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --argjson data "$input" \
        '{
            schema_version: $schema_version,
            exported_at: $exported_at,
            count: ($data | length),
            data: $data
        }' > "$tmp_file" 2>/dev/null || {
        rm -f "$tmp_file"
        echo "导出失败: 写入文件失败" >&2
        return 1
    }

    mv "$tmp_file" "$outfile" 2>/dev/null || {
        rm -f "$tmp_file"
        echo "导出失败: 写入文件失败" >&2
        return 1
    }
}
