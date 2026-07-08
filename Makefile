.PHONY: build run shell clean setup

# ─── Host user/group for file permissions ───────────────────────────
HOST_UID := $(shell id -u)
HOST_GID := $(shell id -g)

# ─── Working directory ──────────────────────────────────────────────
# Defaults to ./workspace. Override with: make run WORK_DIR=/path/to/repo
WORK_DIR ?= $(shell grep -E '^WORK_DIR=' .env 2>/dev/null | tail -1 | sed 's/^WORK_DIR=//')
ifeq ($(WORK_DIR),)
WORK_DIR := ./workspace
endif
WORK_DIR_ABS := $(shell mkdir -p $(WORK_DIR) && cd $(WORK_DIR) && pwd)

# ─── Targets ────────────────────────────────────────────────────────

setup:
	@mkdir -p $(WORK_DIR) config
	@touch .env
	@if [ ! -s .env ]; then \
		echo "⚠️  .env file is empty. Copy .env.example and fill in your API keys:"; \
		echo "   cp .env.example .env"; \
		echo "   $$EDITOR .env"; \
	fi

build: setup
	docker compose pull

run: setup
	WORK_DIR=$(WORK_DIR_ABS) docker compose run --rm opencode

shell: setup
	WORK_DIR=$(WORK_DIR_ABS) docker compose run --entrypoint /bin/bash --rm opencode

clean:
	docker compose down --remove-orphans
