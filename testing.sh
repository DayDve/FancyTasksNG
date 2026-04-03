#!/bin/bash
# SPDX-FileCopyrightText: 2023 Alexandra Stone <alexankitty@gmail.com>
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PACKAGE_DIR="$SCRIPT_DIR/package"
TEMP_SHARE="/tmp/fancytasks-preview-$(whoami)/share"

echo "1. Compiling translations..."
bash "$PACKAGE_DIR/translate/build"

echo "2. Setting up temporary locale prefix..."
# Create a fake XDG data structure to allow gettext/KI18n to find catalogs
# without installing the package into the system.
rm -rf "$(dirname "$TEMP_SHARE")"
mkdir -p "$TEMP_SHARE"
ln -s "$PACKAGE_DIR/contents/locale" "$TEMP_SHARE/locale"

# Point XDG_DATA_DIRS to our fake share directory.
# This ensures plasmawindowed finds the translations for our domain.
export XDG_DATA_DIRS="$TEMP_SHARE:$XDG_DATA_DIRS"

echo "3. Starting plasmawindowed from local source..."
QML_DISABLE_DISK_CACHE=true plasmawindowed "$PACKAGE_DIR"
