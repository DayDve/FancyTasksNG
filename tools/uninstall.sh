#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/functions.sh"

PACKAGE_DIR="$(readlink -f "${SCRIPT_DIR}/../package")"
METADATA_FILE="${PACKAGE_DIR}/metadata.json"

PLASMOID_ID=$(get_metadata "Id" "${METADATA_FILE}")

if [ -z "$PLASMOID_ID" ]; then
    log_error "Could not determine Plasmoid ID from metadata.json."
    exit 1
fi

log_info "Uninstalling plasmoid ${PLASMOID_ID} ..."
kpackagetool6 -t Plasma/Applet --remove "${PLASMOID_ID}"

log_success "Uninstall complete."
