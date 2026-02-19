#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later
# Скрипт для извлечения значений из metadata.json
# Использование: ./get_metadata.sh "Ключ"

DIR=$(dirname $(readlink -f "$0"))
METADATA_FILE="$DIR/../metadata.json"
KEY="$1"

if [ -z "$KEY" ] || [ ! -f "$METADATA_FILE" ]; then
  exit 1
fi

# 1. Пробуем grep -P (быстро и точно)
val=$(grep -oP "\"$KEY\"\s*:\s*\"\K[^\"]+" "$METADATA_FILE" 2> /dev/null)

# 2. Если grep -P нет, используем sed (резерв)
if [ -z "$val" ]; then
  val=$(grep "\"$KEY\":" "$METADATA_FILE" | head -n 1 | sed -E 's/.*"'"$KEY"'"\s*:\s*"([^"]+)".*/\1/')
fi

echo "$val"
