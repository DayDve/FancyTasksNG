# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

# FancyTasksNG Makefile
.PHONY: all build install update test clean translate

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
	@./tools/testing.sh

translate:
	@./tools/extract_messages.sh
	@./tools/compile_messages.sh

clean:
	@rm -rf build release
	@rm -rf package/contents/locale/*
	@echo "Cleanup complete."
