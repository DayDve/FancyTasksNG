#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_DIR}/functions.sh"
PLASMOID_ID=$(get_metadata "Id" "${SCRIPT_DIR}/../package/metadata.json")

if [ -z "$PLASMOID_ID" ]; then
    echo "Error: Could not determine Plasmoid ID from metadata.json."
    exit 1
fi

echo "Uninstalling plasmoid $PLASMOID_ID ..."
kpackagetool6 -t Plasma/Applet --remove "$PLASMOID_ID"
echo "Uninstall complete."
