#!/bin/bash
# SPDX-FileCopyrightText: 2025 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later
SCRIPT_DIR=$(dirname $(readlink -f "$0"))
mkdir -p ~/.local/share/icons/hicolor/scalable/apps/
cp "$SCRIPT_DIR/package/FancyTasksNG.svg" ~/.local/share/icons/hicolor/scalable/apps/FancyTasksNG.svg
echo "Icon installed."
