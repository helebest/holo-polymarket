#!/bin/bash
#
# Export utilities: supports CSV/JSON export

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Validate the export format
# Usage: validate_export_format <csv|json>
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

# Detect the series value column name (price/volume/value)
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

# Export a JSON series to CSV
# Usage: export_to_csv <json_array> <outfile>
export_to_csv() {
    local input="$1"
    local outfile="$2"

    if ! echo "$input" | jq -e 'type == "array"' >/dev/null 2>&1; then
        echo "Export failed: invalid data format (must be a JSON array)" >&2
        return 1
    fi
    if [ -z "$outfile" ]; then
        echo "Export failed: missing output file path" >&2
        return 1
    fi

    local out_dir
    out_dir="$(dirname "$outfile")"
    if [ ! -d "$out_dir" ]; then
        echo "Export failed: output directory does not exist: $out_dir" >&2
        return 1
    fi

    local value_col
    value_col="$(_detect_value_column "$input")"

    local tmp_file
    tmp_file=$(mktemp "${out_dir}/.export_csv.XXXXXX") || {
        echo "Export failed: unable to create temporary file" >&2
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
            day=$(to_ymd_date "$raw_time")
            printf "%s,%s\n" "$day" "$raw_value"
        done
    } > "$tmp_file" 2>/dev/null || {
        rm -f "$tmp_file"
        echo "Export failed: failed to write file" >&2
        return 1
    }

    mv "$tmp_file" "$outfile" 2>/dev/null || {
        rm -f "$tmp_file"
        echo "Export failed: failed to write file" >&2
        return 1
    }
}

# Export a JSON series into a standard JSON wrapper structure
# Usage: export_to_json <json_array> <outfile>
export_to_json() {
    local input="$1"
    local outfile="$2"

    if ! echo "$input" | jq -e 'type == "array"' >/dev/null 2>&1; then
        echo "Export failed: invalid data format (must be a JSON array)" >&2
        return 1
    fi
    if [ -z "$outfile" ]; then
        echo "Export failed: missing output file path" >&2
        return 1
    fi

    local out_dir
    out_dir="$(dirname "$outfile")"
    if [ ! -d "$out_dir" ]; then
        echo "Export failed: output directory does not exist: $out_dir" >&2
        return 1
    fi

    local tmp_file
    tmp_file=$(mktemp "${out_dir}/.export_json.XXXXXX") || {
        echo "Export failed: unable to create temporary file" >&2
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
        echo "Export failed: failed to write file" >&2
        return 1
    }

    mv "$tmp_file" "$outfile" 2>/dev/null || {
        rm -f "$tmp_file"
        echo "Export failed: failed to write file" >&2
        return 1
    }
}