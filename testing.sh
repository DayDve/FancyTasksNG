#!/bin/bash
# SPDX-FileCopyrightText: 2023 Alexandra Stone <alexankitty@gmail.com>
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
bash $SCRIPT_DIR/build.sh
kpackagetool6 -u $SCRIPT_DIR/release/FancyTasks.tar.gz
QML_DISABLE_DISK_CACHE=true plasmawindowed io.github.daydve.fancytasksng
