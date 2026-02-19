#!/bin/bash
# SPDX-FileCopyrightText: 2023 Alexandra Stone <alexankitty@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later
SCRIPT_DIR=$(dirname $(readlink -f "$0"))
mkdir -p ~/.local/share/icons/hicolor/256x256/apps/
cp "$SCRIPT_DIR/package/FancyTasks.png" ~/.local/share/icons/hicolor/256x256/apps/FancyTasks.png
echo "Icon installed."
