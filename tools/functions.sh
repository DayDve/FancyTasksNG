#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

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
    val=$(grep -oP "\"$key\"\s*:\s*\"\K[^\"]+" "$metadata_file" 2> /dev/null)

    # 2. If grep -P is not available, use sed (fallback)
    if [ -z "$val" ]; then
        val=$(grep "\"$key\":" "$metadata_file" | head -n 1 | sed -E 's/.*"'"$key"'"\s*:\s*"([^"]+)".*/\1/')
    fi

    echo "$val"
}
