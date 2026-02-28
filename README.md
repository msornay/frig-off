# Frig-Off

French spam call blocker for iOS using Live Caller ID Lookup (iOS 18+).

Blocks calls from ARCEP-designated commercial call prefixes ("demarchage
telephonique") using a self-hosted PIR server with homomorphic encryption
(BFV scheme). The server never sees which number is being queried.

## Prerequisites

- Swift 6.0+
- Docker

## Quick start

Build and run the PIR server locally:

```
make build
make generate-db
make run
```

The server listens on `http://localhost:8080` by default. Override with
`PORT=9090 make run`.

## Make targets

| Target | Description |
|--------|-------------|
| `make build` | Build the server in release mode |
| `make test` | Run tests in a Docker container |
| `make run` | Start the PIR server locally |
| `make generate-db` | Generate PIR keyword databases from ARCEP prefixes |
| `make docker-build` | Build the production Docker image |
| `make deploy` | Deploy to Clever Cloud (requires `clever-tools`) |
| `make clean` | Remove build artifacts and Docker images |

## Project structure

```
Sources/
  FrigOffKit/        Shared library: prefix definitions, database builder
  GenerateDB/        CLI tool to expand prefixes into PIR keyword databases
  PIRServer/         Hummingbird HTTP server serving PIR queries
  PrivacyPass/       Privacy Pass token issuance and verification
config/
  service-config.json   Server configuration (users, use cases, shard counts)
```

## Configuration

Edit `config/service-config.json` to set your user token:

```json
{
  "users": [{ "tier": "tier1", "tokens": ["YOUR_SECRET_TOKEN"] }],
  "usecases": [
    { "name": "block", "fileStem": "data/block", "shardCount": 10 },
    { "name": "identity", "fileStem": "data/identity", "shardCount": 10 }
  ]
}
```

## Deployment

The server deploys as a Docker container on Clever Cloud:

```
make deploy
```

This requires the `clever-tools` CLI (`npm i -g clever-tools`) and a linked
Clever Cloud application. The Dockerfile handles database generation and shard
processing in a multi-stage build.

## How it works

1. `generate-db` expands the 17 ARCEP prefixes (~12.5M phone numbers) into
   PIR keyword databases.
2. `PIRProcessDatabase` (from Apple's swift-homomorphic-encryption) processes
   them into optimized binary shards.
3. The PIR server serves these shards. iOS devices query it using homomorphic
   encryption -- the server computes over encrypted queries without seeing the
   plaintext phone number.
4. On a dev-signed iOS build, the Live Caller ID Lookup extension talks
   directly to the server (no Apple relay needed).
