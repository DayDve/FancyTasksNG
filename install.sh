#!/bin/bash
# SPDX-FileCopyrightText: 2022-2023 Alexandra Stone <alexankitty@gmail.com>
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later
SCRIPT_DIR=$(dirname $(readlink -f "$0"))

echo "Compiling translations..."
bash "$SCRIPT_DIR/package/translate/build"

echo "Installing plasmoid ..."
kpackagetool6 -t Plasma/Applet --install "$SCRIPT_DIR/package"

bash "$SCRIPT_DIR/iconinstall.sh"
echo "Install complete."
