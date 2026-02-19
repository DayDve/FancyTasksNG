#!/bin/bash
# SPDX-FileCopyrightText: 2023 Alexandra Stone <alexankitty@gmail.com>
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

# Stop execution on error
set -e

SCRIPT_DIR=$(dirname $(readlink -f "$0"))

# Configuration
PACKAGE_NAME="FancyTasks"
ICON_NAME="${PACKAGE_NAME}" # Defaults to package name

BUILD_DIR="$SCRIPT_DIR/build"
RELEASE_DIR="$SCRIPT_DIR/release"

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Error handler function
handle_error() {
  local line_num="$1"
  echo -e "${RED}Error: Build failed at line ${line_num}!${NC}"
}

# Cleanup function
cleanup() {
  rm -rf "$BUILD_DIR"
}

# Set up traps
# ERR trap fires when a command fails (because of set -e)
trap 'handle_error $LINENO' ERR
# EXIT trap fires when script finishes (successfully or after error)
trap cleanup EXIT

# ---------------------------------------------------------

# Run translation scripts in a subshell
(
  cd "$SCRIPT_DIR/package/translate/"
  bash ./merge
  bash ./build
)

# Prepare directories
rm -rf "$RELEASE_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$RELEASE_DIR"

# Copy package files
cp -r "$SCRIPT_DIR/package"/{contents,metadata.json,"${ICON_NAME}.png"} "$BUILD_DIR"

# Create archive
tar -C "$BUILD_DIR" -czf "$RELEASE_DIR/${PACKAGE_NAME}.tar.gz" .

echo -e "${GREEN}Build complete: $RELEASE_DIR/${PACKAGE_NAME}.tar.gz${NC}"
