.PHONY: build pull run shell update clean prune setup

# Fixed compose project name (mirrors `name:` in docker-compose.yaml) so the
# cleanup targets can reliably find this project's containers even if the repo
# directory is renamed.
COMPOSE_PROJECT_NAME ?= opencode
export COMPOSE_PROJECT_NAME

COMPOSE := docker compose

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
	@mkdir -p $(WORK_DIR) config data
	@touch .env
	@if [ ! -s .env ]; then \
		echo "⚠️  .env file is empty. Copy .env.example and fill in your API keys:"; \
		echo "   cp .env.example .env"; \
		echo "   $$EDITOR .env"; \
	fi

build: setup
	@echo "Pulling latest upstream opencode image..."
	docker pull ghcr.io/anomalyco/opencode:latest
	@echo "Building local image (upstream + git)..."
	$(COMPOSE) build --pull

# Pull the upstream image without git (for reference/debugging)
pull: setup
	docker pull ghcr.io/anomalyco/opencode:latest

# Update opencode to the latest upstream: stop old containers, pull the newest
# base image, rebuild the local image (upstream + git), then delete only the
# exact images this project just replaced. Nothing else on the Docker daemon
# is touched.
update: setup
	@echo "==> Stopping existing opencode containers..."
	-$(COMPOSE) down --remove-orphans
	@set -e; \
	old_local=$$(docker images -q local/opencode:latest); \
	old_upstream=$$(docker images -q ghcr.io/anomalyco/opencode:latest); \
	echo "==> Pulling latest upstream opencode image..."; \
	docker pull ghcr.io/anomalyco/opencode:latest; \
	echo "==> Rebuilding local image (upstream + git)..."; \
	$(COMPOSE) build --pull; \
	new_local=$$(docker images -q local/opencode:latest); \
	new_upstream=$$(docker images -q ghcr.io/anomalyco/opencode:latest); \
	echo "==> Removing the opencode images that were just replaced..."; \
	for id in $$old_local $$old_upstream; do \
		case "$$id" in \
			""|"$$new_local"|"$$new_upstream") ;; \
			*) echo "    removing image $$id"; docker image rm -f "$$id" >/dev/null 2>&1 || true ;; \
		esac; \
	done; \
	echo "✔ opencode is up to date. Run 'make run' to start it."

run: setup
	WORK_DIR=$(WORK_DIR_ABS) $(COMPOSE) run --rm opencode

shell: setup
	WORK_DIR=$(WORK_DIR_ABS) $(COMPOSE) run --entrypoint /bin/bash --rm opencode

# Remove only resources belonging to this opencode project: its stopped or
# interrupted containers (matched by the compose project label) and any
# lingering dangling local/opencode images (matched by the label baked into
# local images by the Dockerfile). No other project's containers, images, or
# build cache are touched.
prune:
	@ids=$$(docker ps -aq --filter "label=com.docker.compose.project=$(COMPOSE_PROJECT_NAME)"); \
	if [ -n "$$ids" ]; then \
		echo "Removing leftover opencode containers..."; \
		docker rm -f $$ids; \
	else \
		echo "No leftover opencode containers."; \
	fi
	@echo "Removing dangling opencode images..."
	@docker image prune -f --filter "label=org.opencode.local=true"

clean:
	-$(COMPOSE) down --remove-orphans
	-@docker image rm -f local/opencode:latest
	@$(MAKE) --no-print-directory prune
