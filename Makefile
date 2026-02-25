.PHONY: test deploy build generate-db run docker-build clean

# Frig-Off: French Spam Call Blocker
# PIR server using Swift + homomorphic encryption, deployed via Docker on Clever Cloud.
#
# Prerequisites:
#   - Swift 6.0+ (for local builds)
#   - Docker (for containerized builds and deployment)

SWIFT      ?= swift
DOCKER     ?= docker
IMAGE_NAME ?= frig-off
PORT       ?= 8080

## ── Build ──────────────────────────────────────────────────────────────────────

build:
	$(SWIFT) build -c release

## ── Test ───────────────────────────────────────────────────────────────────────
## Runs swift test inside a Docker container (swift:6.0).
## Docker layer caching makes repeated runs fast when only tests change.

test:
	$(DOCKER) build -f Dockerfile.test -t $(IMAGE_NAME)-test .

## ── Run ────────────────────────────────────────────────────────────────────────

run:
	$(SWIFT) run pir-server --config config/service-config.json --port $(PORT)

## ── Database generation ────────────────────────────────────────────────────────

generate-db:
	$(SWIFT) run generate-db

## ── Docker ─────────────────────────────────────────────────────────────────────

docker-build:
	$(DOCKER) build -t $(IMAGE_NAME) .

## ── Deploy (Clever Cloud via Docker) ───────────────────────────────────────────
## Requires: clever-tools CLI (npm i -g clever-tools), linked app.
## The server listens on 0.0.0.0:$$PORT (set by Clever Cloud).

deploy: docker-build
	@command -v clever >/dev/null 2>&1 || { echo "Install clever-tools: npm i -g clever-tools"; exit 1; }
	clever deploy

## ── Clean ──────────────────────────────────────────────────────────────────────

clean:
	$(SWIFT) package clean 2>/dev/null || true
	$(DOCKER) rmi $(IMAGE_NAME) $(IMAGE_NAME)-test 2>/dev/null || true
