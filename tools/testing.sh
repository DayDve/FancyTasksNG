#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/functions.sh"

PACKAGE_DIR="$(readlink -f "${SCRIPT_DIR}/../package")"
TEMP_SHARE="/tmp/fancytasks-preview-$(whoami)/share"

log_info "1. Compiling translations..."
"${SCRIPT_DIR}/compile_messages.sh"

log_info "2. Setting up temporary locale prefix..."
# Create a fake XDG data structure to allow gettext/KI18n to find catalogs
# without installing the package into the system.
rm -rf "$(dirname "${TEMP_SHARE}")"
mkdir -p "${TEMP_SHARE}"
ln -s "${PACKAGE_DIR}/contents/locale" "${TEMP_SHARE}/locale"

log_info "3. Starting plasmawindowed from local source..."

# Point XDG_DATA_DIRS to our fake share directory.
# This ensures plasmawindowed finds the translations for our domain.
export XDG_DATA_DIRS="${TEMP_SHARE}:${XDG_DATA_DIRS:-}"
export QT_LOGGING_RULES="kf.*=false;org.kde.*=false"
export QML_DISABLE_DISK_CACHE="true"

plasmawindowed "${PACKAGE_DIR}"
