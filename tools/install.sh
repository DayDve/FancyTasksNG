#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>
# SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PACKAGE_DIR="$(readlink -f "$SCRIPT_DIR/../package")"

echo "Compiling translations..."
bash "$SCRIPT_DIR/translate/build"

echo "Installing plasmoid ..."
kpackagetool6 -t Plasma/Applet --install "$PACKAGE_DIR"
echo "Install complete."
