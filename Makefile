# FancyTasksNG Makefile
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

.PHONY: all build install update test clean translate

all: build

build:
	@bash tools/build.sh

install:
	@bash tools/install.sh

uninstall:
	@bash tools/uninstall.sh

update:
	@bash tools/update.sh

test:
	@bash tools/testing.sh

translate:
	@cd tools/translate && bash ./merge && bash ./build

clean:
	@rm -rf build release
	@rm -rf package/contents/locale/*
	@echo "Cleanup complete."
