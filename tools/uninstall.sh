#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PLASMOID_ID=$("$SCRIPT_DIR/translate/get_metadata.sh" "Id")

if [ -z "$PLASMOID_ID" ]; then
    echo "Error: Could not determine Plasmoid ID from metadata.json."
    exit 1
fi

echo "Uninstalling plasmoid $PLASMOID_ID ..."
kpackagetool6 -t Plasma/Applet --remove "$PLASMOID_ID"
echo "Uninstall complete."
