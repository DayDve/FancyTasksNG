#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

# Stop execution on error, treat unset variables as an error, catch pipe failures
set -Eeuo pipefail

# ANSI Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

# Error handler function
handle_error() {
    local line_num="$1"
    log_error "Script failed at line ${line_num}!"
}

# Set up global error trap
trap 'handle_error $LINENO' ERR

# Function to extract values from metadata.json
# Usage: get_metadata "Key" "PathToMetadata"
get_metadata() {
    local key="$1"
    local metadata_file="$2"
    
    if [ -z "$key" ] || [ ! -f "$metadata_file" ]; then
        return 1
    fi

    local val
    # 1. Try grep -P (fast and exact)
    # Using '|| true' because grep exits with 1 if nothing is found, which would trigger 'set -e'
    val=$(grep -oP "\"$key\"\s*:\s*\"\K[^\"]+" "$metadata_file" 2> /dev/null || true)

    # 2. If grep -P is not available, use sed (fallback)
    if [ -z "$val" ]; then
        val=$(grep "\"$key\":" "$metadata_file" | head -n 1 | sed -E 's/.*"'"$key"'"\s*:\s*"([^"]+)".*/\1/' || true)
    fi

    echo "$val"
}

# Function to update translation status in ReadMe.md
update_translation_status() {
    local lang_dir="$1"
    local readme_file="$2"

    if [ ! -f "${lang_dir}/template.pot" ]; then
        log_error "template.pot not found in ${lang_dir}."
        return 1
    fi

    local total_strings
    total_strings=$(grep -c '^msgid ' "${lang_dir}/template.pot" || true)
    if [ "$total_strings" -gt 0 ]; then
        total_strings=$((total_strings - 1)) # Subtract 1 for the empty msgid at the header
    else
        total_strings=0
    fi

    local temp_table
    temp_table=$(mktemp)
    echo "| Locale   | Lines   | % Done |" > "$temp_table"
    echo "|----------|---------|--------|" >> "$temp_table"
    printf "| %-8s | %-7s | %-6s |\n" "Template" "$total_strings" "" >> "$temp_table"

    local catalogs
    catalogs=$(find "${lang_dir}" -name '*.po' | sort || true)
    if [ -n "$catalogs" ]; then
        for po_file in $catalogs; do
            local locale
            locale=$(basename "$po_file" .po)
            
            local stat_output
            stat_output=$(msgfmt --statistics -o /dev/null "$po_file" 2>&1 || true)
            local translated
            translated=$(echo "$stat_output" | grep -oP '\d+(?= translated)' || echo 0)
            
            local percent=0
            if [ "$total_strings" -gt 0 ]; then
                percent=$((translated * 100 / total_strings))
            fi
            
            local lines_str="${translated}/${total_strings}"
            local percent_str="${percent}%"
            printf "| %-8s | %-7s | %-6s |\n" "$locale" "$lines_str" "$percent_str" >> "$temp_table"
        done
    fi

    sed -i '/^## Status/,$d' "$readme_file"
    echo "## Status" >> "$readme_file"
    cat "$temp_table" >> "$readme_file"
    rm -f "$temp_table"

    log_success "Updated translation status in ReadMe.md"
}
