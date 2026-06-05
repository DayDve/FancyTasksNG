#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>
# SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/functions.sh"

PACKAGE_DIR="$(readlink -f "${SCRIPT_DIR}/../package")"

log_info "Compiling translations..."
"${SCRIPT_DIR}/compile_messages.sh"

log_info "Updating plasmoid ..."
kpackagetool6 -t Plasma/Applet --upgrade "${PACKAGE_DIR}"

log_info "Restarting Plasma..."
if systemctl --user is-active --quiet plasma-plasmashell.service; then
  systemctl --user restart plasma-plasmashell.service
else
  plasmashell --replace >/dev/null 2>&1 &
  disown
fi

log_success "Update complete."
