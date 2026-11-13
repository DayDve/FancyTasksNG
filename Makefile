# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

# FancyTasksNG Makefile
.PHONY: all build install update test test-panel test-desktop clean translate diag

all: build

build:
	@./tools/build.sh

install:
	@./tools/install.sh

uninstall:
	@./tools/uninstall.sh

update:
	@./tools/update.sh

test:
	@./tools/testing.sh window

# Nested KWin + plasmashell; SCREEN=WIDTHxHEIGHT for a window instead of full screen.
test-panel:
	@SCREEN="$(SCREEN)" ./tools/testing.sh panel

test-desktop:
	@SCREEN="$(SCREEN)" ./tools/testing.sh desktop

translate:
	@./tools/extract_messages.sh
	@./tools/compile_messages.sh

clean:
	@rm -rf build release
	@rm -rf package/contents/locale/*
	@echo "Cleanup complete."

diag:
	@./tools/diag.sh
