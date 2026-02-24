# Frig-Off PIR Server
# Multi-stage build: generate database, build server, run.
#
# Prerequisites: swift-homomorphic-encryption's PIRProcessDatabase must be
# available during the build stage to process the keyword databases into
# optimized shards.

# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM swift:6.0 AS builder

WORKDIR /build
COPY Package.swift Package.resolved ./
COPY Sources/ Sources/
COPY Tests/ Tests/
COPY config/ config/

# Resolve dependencies and build in release mode.
RUN swift build -c release

# Generate the PIR keyword databases (block + identity).
RUN mkdir -p data && \
    swift run -c release generate-db --output data --generate-configs

# Install PIRProcessDatabase and process the databases into shards.
# This step uses the HE library's CLI tool to produce the binary shard files
# that the PIR service reads at runtime.
RUN swift package experimental-install -c release \
        --product PIRProcessDatabase \
        --package-url https://github.com/apple/swift-homomorphic-encryption && \
    ~/.swiftpm/bin/PIRProcessDatabase config/block-config.json && \
    ~/.swiftpm/bin/PIRProcessDatabase config/identity-config.json

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM swift:6.0-slim

WORKDIR /app

# Copy the PIR service binary (built from pir-service-example, added later).
# For now, copy the database generation output.
COPY --from=builder /build/data/ data/
COPY --from=builder /build/config/service-config.json config/service-config.json

# Clever Cloud sets $PORT; default to 8080 for local dev.
ENV PORT=8080
EXPOSE ${PORT}

# The PIRService binary will be added in Phase 2 when the server is built.
# For now this image contains the processed database shards.
CMD ["echo", "PIR service binary not yet integrated -- see TODOs.md Phase 2"]
