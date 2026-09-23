#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>
# SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/functions.sh"

PACKAGE_DIR="$(readlink -f "${SCRIPT_DIR}/../package")"
INSTALL_DIR="${SCRIPT_DIR}/build-install"

cleanup() {
    rm -rf "${INSTALL_DIR}"
}
trap cleanup EXIT

log_info "Compiling translations..."
"${SCRIPT_DIR}/compile_messages.sh"

# Keep ConfigPage.qml's cfg_*Default values in sync with main.xml
python3 "${SCRIPT_DIR}/sync_defaults.py"

# Stage a copy so the version can be stamped without touching the committed
# package/metadata.json (see resolve_display_version in functions.sh).
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
cp -r "${PACKAGE_DIR}"/{contents,metadata.json,icon.svg} "${INSTALL_DIR}"
DISPLAY_VERSION="$(resolve_display_version "${INSTALL_DIR}/metadata.json")"
set_metadata_version "${INSTALL_DIR}/metadata.json" "${DISPLAY_VERSION}"

log_info "Installing plasmoid ..."
kpackagetool6 -t Plasma/Applet --install "${INSTALL_DIR}"

log_success "Install complete."
