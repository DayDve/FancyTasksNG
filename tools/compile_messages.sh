#!/bin/bash
# SPDX-FileCopyrightText: 2023 Alexandra Stone <alexankitty@gmail.com>
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later
# Version: 8 (Modular)

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/functions.sh"

PACKAGE_DIR="$(readlink -f "${SCRIPT_DIR}/../package")"
METADATA_FILE="${PACKAGE_DIR}/metadata.json"
TRANSLATE_DIR="${SCRIPT_DIR}/translate"

cd "${TRANSLATE_DIR}"

plasmoidName=$(get_metadata "Id" "${METADATA_FILE}")
projectName="plasma_applet_${plasmoidName}"

if [ -z "$plasmoidName" ]; then
    log_error "Couldn't read 'Id' from metadata.json."
    exit 1
fi

if ! command -v msgfmt &> /dev/null; then
    log_error "msgfmt command not found. Need to install gettext."
    log_info "Running 'sudo apt install gettext'"
    sudo apt install gettext
fi

log_info "Compiling messages for ${projectName}"

rm -rf "${PACKAGE_DIR}/contents/locale"

# Use || true to prevent set -e from killing the script if no po files found
catalogs=$(find languages -name '*.po' | sort || true)
if [ -n "$catalogs" ]; then
    for cat in $catalogs; do
        log_info "$cat"
        catLocale=$(basename "${cat%.*}")
        msgfmt -o "${catLocale}.mo" "$cat"

        installPath="${PACKAGE_DIR}/contents/locale/${catLocale}/LC_MESSAGES/${projectName}.mo"

        log_info "Install to ${installPath}"
        mkdir -p "$(dirname "$installPath")"
        mv "${catLocale}.mo" "${installPath}"
    done
fi

log_success "Done building messages"
