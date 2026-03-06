#!/bin/bash
#
# Time-series commands.

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

run_series_command() {
    local cmd_name="$1"
    local series_type="$2"
    local formatter_fn="$3"
    local banner="$4"
    shift 4

    parse_series_command_args "$cmd_name" "$@" || return 1

    if ! validate_time_range "$SERIES_FROM_DATE" "$SERIES_TO_DATE"; then
        echo "时间范围无效: from/to 必须是 YYYY-MM-DD 且 from <= to"
        return 1
    fi

    if ! validate_interval "$SERIES_INTERVAL"; then
        echo "interval 无效: 仅支持 1h/4h/1d"
        return 1
    fi

    echo "${banner}: ${SERIES_SLUG} | ${SERIES_FROM_DATE} -> ${SERIES_TO_DATE} | ${SERIES_INTERVAL}"
    echo ""

    local result
    result=$(fetch_history_series "$series_type" "$SERIES_SLUG" "$SERIES_FROM_DATE" "$SERIES_TO_DATE" "$SERIES_INTERVAL") || return 1

    export_series_if_needed "$result" "$cmd_name"
    local export_code=$?
    if [ "$export_code" -eq 1 ]; then
        return 1
    fi

    if [ "$export_code" -eq 2 ]; then
        echo "$result" | "$formatter_fn"
        [ "${PIPESTATUS[1]}" -eq 0 ] || return 1
    fi

    return 0
}

handle_series_command() {
    local cmd="$1"
    shift || true

    case "$cmd" in
        history)
            run_series_command "history" "price" "format_price_history_table" "🕒 历史价格" "$@"
            ;;
        trend)
            run_series_command "trend" "price" "format_trend_summary" "📈 概率趋势" "$@"
            ;;
        volume-trend)
            run_series_command "volume-trend" "volume" "format_volume_trend_table" "📊 交易量趋势" "$@"
            ;;
        *)
            return 2
            ;;
    esac
}