#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-FileCopyrightText: 2023 Alexandra <alexankitty@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/functions.sh"

# Configuration
PACKAGE_NAME="FancyTasksNG"
ICON_NAME="icon" # Standardized KPackage icon name
PACKAGE_DIR="$(readlink -f "${SCRIPT_DIR}/../package")"
BUILD_DIR="${SCRIPT_DIR}/build"
RELEASE_DIR="$(readlink -f "${SCRIPT_DIR}/../release")"

# Cleanup function
cleanup() {
    rm -rf "${BUILD_DIR}"
}

# EXIT trap fires when script finishes (successfully or after error)
trap cleanup EXIT

# ---------------------------------------------------------

# Run translation scripts in a subshell
(
    "${SCRIPT_DIR}/extract_messages.sh"
    "${SCRIPT_DIR}/compile_messages.sh"
)

# Prepare directories
rm -rf "${RELEASE_DIR}"
mkdir -p "${BUILD_DIR}" "${RELEASE_DIR}"

# Copy package files
cp -r "${PACKAGE_DIR}"/{contents,metadata.json,"${ICON_NAME}.svg"} "${BUILD_DIR}"

# Create archive
cd "${BUILD_DIR}"
zip -q -r "${RELEASE_DIR}/${PACKAGE_NAME}.plasmoid" .
cd - > /dev/null

log_success "Build complete: ${RELEASE_DIR}/${PACKAGE_NAME}.plasmoid"
