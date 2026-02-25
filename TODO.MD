
make test should trigger tests in docker containers and PASS!


# Frig-Off -- French Spam Call Blocker

> iOS app that blocks French commercial/spam phone calls ("demarchage telephonique")
> using **Live Caller ID Lookup** (iOS 18+) with a self-hosted PIR server.
>
> This architecture uses homomorphic encryption (BFV scheme) for privacy-preserving
> phone number lookups. The server never sees which number is being queried.
>
> **Target**: dev-signed builds for personal use (no Apple relay approval needed).
> **Deployment target**: iOS 18.0+. **Language**: Swift (app + server).

---

## Architecture Overview

```
  iPhone (dev build)                          Clever Cloud
  ┌─────────────────────┐                    ┌─────────────────────────┐
  │  FrigOff App        │                    │  pir-service (Swift)    │
  │  ┌────────────────┐ │                    │                         │
  │  │ Settings UI    │ │                    │  /config     → PIR params│
  │  │ (SwiftUI)      │ │                    │  /queries    → PIR query │
  │  └────────────────┘ │                    │  /issue      → tokens    │
  │                     │                    │                         │
  │  ┌────────────────┐ │   PIR over HTTPS   │  ┌─────────────────┐   │
  │  │ LiveCallerID   │─┼───────────────────►│  │ BFV homomorphic │   │
  │  │ Lookup Ext.    │ │   (no relay in     │  │ encryption      │   │
  │  └────────────────┘ │    dev mode)       │  └─────────────────┘   │
  └─────────────────────┘                    │                         │
                                             │  block.txtpb  (prefix   │
                                             │                dataset) │
                                             └─────────────────────────┘
```

**Key insight**: In dev-signed builds, iOS skips Apple's OHTTP relay and queries the
PIR server directly. This means no Apple approval is needed for development/personal use.
The full homomorphic encryption stack still runs -- the server still never sees the
plaintext phone number.

---

## Phase 0 -- Server Bootstrap

### Clone and understand Apple's reference implementation

- [ ] Clone `https://github.com/apple/pir-service-example`
- [ ] Clone `https://github.com/apple/swift-homomorphic-encryption`
- [ ] Read the reference server structure: understand `PIRService`, `PIRProcessDatabase`, Privacy Pass token issuance
- [ ] Read the data format: `input.txtpb` (Protocol Buffer text format) for phone number entries
- [ ] Build the reference server locally (`swift build -c release`) -- requires Swift 6.0+
- [ ] Run it locally and hit `/config` to verify it serves PIR parameters

### Understand the two PIR use cases

- [ ] The server serves two separate databases:
  - `"block"` -- phone numbers to silently block (our primary use case)
  - `"identity"` -- caller name/label to display (nice-to-have: show "Demarchage" label)
- [ ] Each use case has its own shards, config, and file stem in `config.json`

---

## Phase 1 -- French Spam Number Database

### ARCEP NPV prefix dataset

- [x] Create `input.txtpb` containing French commercial call prefixes to block
- [ ] The ARCEP-designated prefixes for "demarchage telephonique" (NPV ranges):

  **Metropolitan France (12 prefixes, 4-digit):**

  | Local prefix | E.164 range | Numbers |
  |-------------|-------------|---------|
  | 0162 | +33162000000 to +33162999999 | 1,000,000 |
  | 0163 | +33163000000 to +33163999999 | 1,000,000 |
  | 0270 | +33270000000 to +33270999999 | 1,000,000 |
  | 0271 | +33271000000 to +33271999999 | 1,000,000 |
  | 0377 | +33377000000 to +33377999999 | 1,000,000 |
  | 0378 | +33378000000 to +33378999999 | 1,000,000 |
  | 0424 | +33424000000 to +33424999999 | 1,000,000 |
  | 0425 | +33425000000 to +33425999999 | 1,000,000 |
  | 0568 | +33568000000 to +33568999999 | 1,000,000 |
  | 0569 | +33569000000 to +33569999999 | 1,000,000 |
  | 0948 | +33948000000 to +33948999999 | 1,000,000 |
  | 0949 | +33949000000 to +33949999999 | 1,000,000 |

  **Overseas (5 prefixes, 5-digit):**

  | Local prefix | E.164 range | Numbers |
  |-------------|-------------|---------|
  | 09475 | +339475000000 to +33947599999 | 100,000 |
  | 09476 | +339476000000 to +33947699999 | 100,000 |
  | 09477 | +339477000000 to +33947799999 | 100,000 |
  | 09478 | +339478000000 to +33947899999 | 100,000 |
  | 09479 | +339479000000 to +33947999999 | 100,000 |

  **Total: ~12,500,000 numbers**

- [x] Write a Swift script (or extend `PIRProcessDatabase`) to **expand** prefixes into individual E.164 numbers for the txtpb file. PIR databases are key-value stores -- each phone number is a key, the value is the block/identity metadata
- [x] For the `"block"` use case: each number maps to a simple "block" flag
- [x] For the `"identity"` use case (optional V1): each number maps to a label like "Demarchage commercial"
- [ ] Run `PIRProcessDatabase` on the generated txtpb to produce the binary shard files
- [ ] Measure: how large are the processed shards? How long does preprocessing take for 12.5M entries?

### Database generation tooling

- [x] Create a `generate-db` Swift script/target in the server project that:
  1. Takes a list of French prefixes as input (JSON or CLI args)
  2. Expands each prefix to the full E.164 number range
  3. Writes the `input.txtpb` in the format expected by `PIRProcessDatabase`
  4. Runs `PIRProcessDatabase` to produce optimized shards
- [x] This script runs at build/deploy time, not at runtime
- [x] Make it easy to add/remove prefixes and regenerate

---

## Phase 2 -- Server Configuration & Auth

### Privacy Pass token setup

- [x] Configure `config.json` with user tiers
- [x] Create a hardcoded `userTierToken` for personal use (shared among your devices)
- [x] The token issuer validates this token and issues Privacy Pass tokens
- [x] For dev use, a single tier with a single static token is sufficient
- [ ] Document how to add a new user (buddy): add their token to the config, redeploy

### Server config.json structure

- [x] Define the config with:
  ```
  - users: [{ "tier": "tier1", "tokens": ["<your-shared-secret>"] }]
  - usecases:
    - { "name": "block", "fileStem": "data/block", "shardCount": 10 }
    - { "name": "identity", "fileStem": "data/identity", "shardCount": 10 }
  ```
- [ ] Shard count depends on database size -- follow reference impl guidance
- [ ] Test: request a Privacy Pass token with a valid `userTierToken` -> success
- [ ] Test: request with an invalid token -> rejection

### TLS / HTTPS

- [ ] The PIR service endpoint must be HTTPS (iOS requires App Transport Security)
- [ ] Clever Cloud provides TLS termination on custom domains -- use this
- [ ] Alternatively, for local dev, use a self-signed cert + ATS exception in the app's Info.plist

---

## Phase 3 -- Deploy to Clever Cloud

### Containerized Swift server

- [x] Create a `Dockerfile` for the PIR server:
  - Base image: `swift:6.0` (or later)
  - Build stage: `swift build -c release`
  - Run stage: copy binary + processed database shards
  - Expose the HTTP port (Clever Cloud assigns `$PORT`)
- [x] The server binary must listen on `0.0.0.0:$PORT` (Clever Cloud requirement)
- [x] Include the preprocessed database shards in the image (they're static until you update prefixes)
- [ ] **Performance note**: BFV homomorphic operations are CPU-intensive. Start with a Clever Cloud M instance (2 vCPUs). Monitor and adjust.

### Deployment checklist

- [ ] Create a Clever Cloud Docker application
- [ ] Set environment variables: `PORT` (auto-set by CC), any config paths
- [ ] Deploy and verify `/config` endpoint returns PIR parameters over HTTPS
- [ ] Verify `/queries` responds to a PIR query (test with the reference client or curl)
- [ ] Set up a custom domain with TLS (e.g., `frig-off.cleverapps.io` or custom)

### Database updates

- [ ] To update the blocked prefix list:
  1. Edit the prefix input file
  2. Run `generate-db` to regenerate shards
  3. Rebuild and redeploy the Docker image
  4. The server supports hot-reload via `SIGHUP` -- but on Clever Cloud, a redeploy is simpler
- [ ] For now, prefix updates = redeploy. Future: consider a CI pipeline that regenerates on push.

---

## Phase 4 -- iOS App: Extension

### Xcode project setup

- [ ] Create a new Xcode project `FrigOff` (SwiftUI App, iOS 18.0+, Swift)
- [ ] Add a new target: Live Caller ID Lookup Extension named `FrigOffLookup`
- [ ] The extension uses the **IdentityLookup** framework (not CallKit)
- [ ] Set deployment target to iOS 18.0 on both targets
- [ ] No App Groups needed (the extension doesn't share a local database -- it talks to the server)
- [ ] Bundle IDs: `com.frigoff.app` and `com.frigoff.app.lookup`

### LiveCallerIDLookupProtocol implementation

- [ ] In the extension, conform to `LiveCallerIDLookupProtocol`
- [ ] Provide `LiveCallerIDLookupExtensionConfiguration` with:
  - `serviceURL`: your Clever Cloud server URL (e.g., `https://frig-off.cleverapps.io`)
  - `tokenIssuerURL`: same server (token issuance is part of the same service)
  - `userTierToken`: the hardcoded shared secret as `Data`
- [ ] That's it for the extension -- iOS handles the PIR crypto, OHTTP (skipped in dev), and call blocking automatically

### Key thing to understand

- [ ] The extension is **thin**. It provides configuration, not logic.
- [ ] iOS itself performs: token acquisition, PIR query encryption (BFV), server communication, response decryption, block/identify decision
- [ ] You do NOT implement the homomorphic encryption on the client side -- Apple's system frameworks do it
- [ ] The heavy lifting is all server-side (your PIR service)

### Enabling the extension

- [ ] User must enable the extension in Settings > Phone > Call Blocking & Identification (same as Call Directory extensions)
- [ ] Use `LiveCallerIDLookupManager.shared` to check extension status from the app
- [ ] Call `refreshPIRParameters()` when you know the server database was updated

---

## Phase 5 -- iOS App: UI (SwiftUI)

### Onboarding flow

- [ ] `OnboardingView.swift` -- 3 steps:
  1. **Welcome**: "Frig Off bloque les appels de demarchage en utilisant les prefixes ARCEP"
  2. **Enable**: step-by-step to Settings > Phone > Call Blocking & Identification > enable FrigOff
  3. **Done**: check extension status, show confirmation
- [ ] Store `hasCompletedOnboarding` in `UserDefaults`
- [ ] Allow re-accessing from settings

### Main view: status dashboard

- [ ] `StatusView.swift` -- the primary screen after onboarding:
  - **Extension status indicator**:
    - Green: "Protection active"
    - Red: "Extension desactivee" + tap to see instructions
    - Gray: "Verification..."
  - **Server status indicator**: ping `/config` to confirm server is reachable
  - **Blocked prefix summary**: list the 17 ARCEP prefixes with their zones
  - **Total numbers covered**: "12 500 000 numeros bloques"
- [ ] Use `LiveCallerIDLookupManager.shared` for extension status
- [ ] Simple `URLSession` health check for server status

### Prefix info view

- [ ] `PrefixListView.swift` -- informational list of blocked prefixes:
  - Each row: formatted prefix (e.g., "01 62"), zone label (e.g., "Ile-de-France"), number count
  - Grouped by metropolitan / overseas
  - This is **read-only** in V1 -- prefix changes require server redeployment
  - Future: could add custom prefix management that triggers server-side regeneration

### Settings view

- [ ] `SettingsView.swift`:
  - About: app version, brief explanation of the PIR/homomorphic encryption approach
  - Server URL display (for debugging)
  - "Revoir l'introduction" button
  - "Rafraichir les parametres PIR" button (calls `refreshPIRParameters()`)
  - Link to ARCEP info page

### Error feedback

- [ ] If extension is disabled: persistent banner with instructions
- [ ] If server is unreachable: warning with "Verifier la connexion" message
- [ ] If token is rejected: "Acces refuse" message (shouldn't happen with hardcoded token, but handle it)

---

## Phase 6 -- Testing

### Server tests

- [ ] Unit test: `generate-db` produces valid txtpb for a small prefix set (e.g., single 6-digit prefix = 10K numbers)
- [ ] Unit test: `PIRProcessDatabase` succeeds on generated txtpb
- [ ] Integration test: start server, fetch `/config`, verify response structure
- [ ] Integration test: request Privacy Pass token with valid `userTierToken` -> token issued
- [ ] Integration test: request with invalid token -> rejected
- [ ] Load test: measure PIR query latency with the full 12.5M entry database

### iOS tests

- [ ] Unit test: extension provides correct `serviceURL`, `tokenIssuerURL`, `userTierToken`
- [ ] UI test: onboarding flow completion
- [ ] UI test: status view shows server reachable/unreachable states

### End-to-end testing on device

- [ ] **Must test on a real device** -- Live Caller ID Lookup does not work in the Simulator
- [ ] Install dev-signed build via Xcode
- [ ] Enable extension in Settings > Phone > Call Blocking & Identification
- [ ] Have someone call from a number in a blocked range
- [ ] Verify the call is blocked / labeled
- [ ] Test with a number NOT in the blocked range -- verify it rings normally

---

## Constraints & Gotchas

### Protocol constraints

- **PIR database is static**: it's preprocessed into binary shards at build time. Adding a prefix = regenerate + redeploy. No runtime updates.
- **BFV is CPU-heavy**: each PIR query requires homomorphic computation over the full database shard. Monitor server CPU on Clever Cloud.
- **Dev builds skip OHTTP relay**: queries go directly to your server over HTTPS. Privacy is reduced (server sees client IP) but the homomorphic encryption layer still protects the queried number.
- **Numbers in the PIR database are exact**: just like Call Directory, there's no prefix/wildcard matching. Prefixes must be expanded into individual numbers at database generation time.

### iOS constraints

- **iOS 18.0+ only**: Live Caller ID Lookup is not available on iOS 17 or earlier
- **Extension must be manually enabled**: no API to enable programmatically
- **Distribution requires Apple approval**: the managed entitlement + OHTTP relay access. Not needed for dev builds.
- **refreshPIRParameters()**: call this from the app when you know the server database changed (after a redeploy). iOS caches PIR config.

### Clever Cloud constraints

- **Swift 6.0+ in Docker**: use the official `swift:6.0` Docker image
- **Port binding**: server must listen on `0.0.0.0:$PORT` (CC sets `$PORT`)
- **CPU**: homomorphic encryption is compute-bound. Start with M size (2 vCPUs), benchmark, scale if needed.
- **Disk**: preprocessed shards for 12.5M entries -- measure size, ensure it fits in the instance storage
- **No SIGHUP**: for database updates, redeploy the container rather than hot-reloading

### French telephony

- **E.164 format**: `+33` + 9 digits. In the PIR database, store as the full E.164 string or numeric representation (check what format `LiveCallerIDLookup` expects -- likely E.164 with country code)
- **ARCEP prefix list may evolve**: new prefixes could be added. The `generate-db` tooling should make updates trivial.
- **06/07 commercial calls are already illegal**: no need to block these ranges
- **Some legitimate calls may come from 09xx**: document this risk for users

---

## Future Enhancements (Out of Scope for V1)

- [ ] **Identity labels**: populate the `"identity"` use case so blocked calls show "Demarchage commercial" instead of just being silently blocked
- [ ] **Remote prefix config**: instead of hardcoding prefixes in the build, fetch a prefix list from a simple JSON endpoint and regenerate shards in CI
- [ ] **Apple distribution**: apply for the managed entitlement and OHTTP relay access to ship on the App Store
- [ ] **Custom prefix management**: let users request additional prefixes via the app, triggering server-side regeneration
- [ ] **Community-sourced numbers**: accept user reports of spam numbers and add them to the database
- [ ] **Monitoring dashboard**: simple web UI showing server health, query volume, database stats
- [ ] **Multi-country support**: extend beyond French prefixes
