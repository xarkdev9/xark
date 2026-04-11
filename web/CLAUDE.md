# CLAUDE.md — hello OS / Web App (Next.js 16)

Web-specific guidance. See `~/hello/CLAUDE.md` for full architecture, terminology, and infrastructure lock.

---

## LANDMINES — Read Before Touching Anything

### 1. Next.js 16: middleware.ts → proxy.ts
Next.js 16 renamed `middleware.ts` to `proxy.ts`. The rate-limiting + CSP/nonce injection lives at
`web/src/proxy.ts`. **DO NOT create a `middleware.ts`** — Next.js 16 silently ignores it. All
edge-layer security (rate limiting, AppCheck, security headers, nonce) runs through `proxy.ts`.

### 2. CSS variable inversion — `--hello-white` is NOT white
```
--hello-white: #111111   ← near-black (primary text color)
--hello-void:  #FAFAFA   ← near-white (canvas/background color)
```
These names are semantically inverted from their values. `body { color: var(--hello-white) }` is
correct. Do not "fix" these — they are intentional and load-bearing across 100+ usages.

### 3. `--hello-cyan` is an alias, not a distinct color
`--hello-cyan: #FF6B35` — identical to `--hello-accent`. There is no separate cyan hue.
Both `--hello-cyan` and `--hello-accent` resolve to the same orange-red. Use `--hello-accent`.

---

## Tech Stack

| Item | Value |
|------|-------|
| Next.js | 16.1.6 |
| React | 19.2.3 |
| Test runner | vitest 4.x (`npm test` → `vitest run`) |
| E2E tests | Playwright (`@playwright/test`) |
| Crypto runtime | libsodium-wrappers-sumo (WASM, client-side only) |
| Rate limiting | Upstash Redis (`@upstash/ratelimit`) |
| Database | Supabase Postgres (`postgres` TCP pool) |
| AI | Google Generative AI + Apify + SearchAPI |

```bash
npm run dev          # Dev server (port 3000 only)
npm run build        # Production build
npx tsc --noEmit     # Type-check only
npm test             # vitest run (unit tests)
npx playwright test  # E2E tests
npx tsx web/tests/sdk-validation.ts  # 100-test standalone script (fragile — tsx not in package.json)
```

---

## API Routes (53 total handlers)

### Core / Messaging (13)
| Route | Method | Purpose |
|-------|--------|---------|
| `/api/message` | POST | E2EE message send (atomic: message + ciphertext + SK distribution) |
| `/api/chat/start` | POST | Find-or-create 1:1 chat via `find_or_create_chat` RPC |
| `/api/hello` | POST | @hello AI orchestration, 3-tier routing (maxDuration 60s) |
| `/api/hello/webhook` | POST | @hello webhook handler |
| `/api/local-action` | POST | Tier 1 mutations (update_dates, rename, revert, create_group) |
| `/api/notify` | POST | FCM push to group members (filters muted) |
| `/api/og` | POST | OG metadata extraction with SSRF protection |
| `/api/proxy-scrape` | POST | Blind OG metadata proxy (no auth, SSRF-protected) |
| `/api/share` | POST | PWA share target handler |
| `/api/onboarding` | POST | Day 1 onboarding endpoint |
| `/api/devices` | GET/POST | Device registry (multi-device, 5-device limit) |
| `/api/dev-auth` | POST | Dev login with password (404 in production) |
| `/api/dev-auto-login` | POST | Passwordless dev login (404 in production) |

### Auth (1)
| Route | Method | Purpose |
|-------|--------|---------|
| `/api/phone-auth` | POST | Exchange Firebase phone OTP for Supabase-compatible JWT |

### Keys / E2EE (3)
| Route | Method | Purpose |
|-------|--------|---------|
| `/api/keys/bundle` | POST | E2EE key bundle upload |
| `/api/keys/otk` | POST | OTK batch upload (max 200) |
| `/api/keys/fetch` | POST | Atomic key bundle fetch (FOR UPDATE SKIP LOCKED) |

### Invite / Contacts (4)
| Route | Method | Purpose |
|-------|--------|---------|
| `/api/invite` | POST | Generate 128-bit hex cryptographic invite link |
| `/api/invite/validate` | GET | Validate invite code, return creator name |
| `/api/invite/claim` | POST | Firebase auth → atomic claim → create group → JWT |
| `/api/join` | POST | Name-only invite join, create user, sign JWT |
| `/api/contacts/check` | POST | Phone number registration lookup (max 500) |

### Discovery (8)
| Route | Method | Purpose |
|-------|--------|---------|
| `/api/discovery/feed` | GET | Personalized discovery feed |
| `/api/discovery/explore` | GET | Explore/browse catalog |
| `/api/discovery/carousel` | GET | Carousel items for home surface |
| `/api/discovery/item/[id]` | GET | Single item detail + enrichment |
| `/api/discovery/enrich` | POST | On-demand item enrichment |
| `/api/discovery/feedback` | POST | Submit user feedback on an item |
| `/api/discovery/feedback/[id]` | GET/PATCH | Read or update specific feedback |
| `/api/discovery/providers/health` | GET | Discovery provider health check |

### Crons (3)
| Route | Method | Purpose |
|-------|--------|---------|
| `/api/cron/consensus` | GET | Auto-lock expired consensus countdowns (daily) |
| `/api/cron/purge` | GET | Purge expired @hello messages + invite links (daily) |
| `/api/cron/warm` | GET | Cache warm-up cron |

### Xpensly — Stateless (10)
| Route | Purpose |
|-------|---------|
| `/api/xpensly/calculate` | Split calculation |
| `/api/xpensly/convert` | Currency conversion |
| `/api/xpensly/currencies` | Supported currency list |
| `/api/xpensly/simplify` | Debt graph simplification |
| `/api/xpensly/split` | Split preview |
| `/api/xpensly/split-modes` | Available split modes |
| `/api/xpensly/payment-link` | Generate payment deep link |
| `/api/xpensly/payment-providers` | List payment providers |
| `/api/xpensly/health` | Xpensly health check |
| `/api/xpensly/checkout` | Stripe checkout session |

### Xpensly — Stateful Trip (10)
| Route | Purpose |
|-------|---------|
| `/api/xpensly/trip` | Create trip |
| `/api/xpensly/trip/[tripId]` | Get/update/delete trip |
| `/api/xpensly/trip/[tripId]/expense` | Add expense |
| `/api/xpensly/trip/[tripId]/expense/[expenseId]` | Get/update/delete expense |
| `/api/xpensly/trip/[tripId]/balances` | Trip balance sheet |
| `/api/xpensly/trip/[tripId]/settle` | Record settlement |
| `/api/xpensly/trip/[tripId]/settlements` | List settlements |
| `/api/xpensly/trip/[tripId]/refund` | Record refund |
| `/api/xpensly/trip/[tripId]/settings` | Trip settings |
| `/api/xpensly/trip/[tripId]/summary` | Aggregated trip summary |

### Xpensly — Business Logic Helpers (NOT route handlers)
`web/src/app/api/xpensly/lib/` — 8 TypeScript modules ported from `xpensly_core`:
`currency-converter.ts`, `debt-simplifier.ts`, `payment-links.ts`, `recurrence-expander.ts`,
`settlement-engine.ts`, `split-calculator.ts`, `trip-aggregator.ts`, `types.ts`

---

## Request Flow

```
Client request
  → proxy.ts (Next.js 16 edge layer)
      ├── Nonce-based CSP header injection
      ├── Edge rate limiting (Upstash Redis, ROUTE_RATE_CONFIG)
      └── Pass-through to serverless function
          → route.ts handler
              ├── JWT verification (jose)
              ├── AppCheck verification (appcheck-verify.ts)
              ├── Business logic via src/lib/
              └── Response
```

All API routes verify the JWT in-handler. `proxy.ts` only decodes `sub` claim for rate-limit keying
(no signature verification at edge). `appcheck.ts` is the Firebase AppCheck SDK init;
`appcheck-verify.ts` is the server-side token verifier used in handlers.

---

## Key Modules (src/lib/)

### Auth / Security
| File | Purpose |
|------|---------|
| `auth-verify.ts` | JWT verification helper (jose) |
| `appcheck.ts` | Firebase AppCheck SDK initialization |
| `appcheck-verify.ts` | Server-side AppCheck token verifier (used in route handlers) |
| `rate-limit-edge.ts` | Upstash Redis rate limiting for proxy.ts (token bucket + sliding window) |
| `rate-limit.ts` | In-handler rate limiting (distinct from edge variant) |
| `jwt-replay.ts` | JWT replay protection (jti + Redis SETNX) |
| `key-cache.ts` | Key bundle Redis cache (SETNX, 5min TTL, X-Bypass-Cache) |
| `firebase.ts` | Firebase client SDK init |
| `supabase.ts` | Supabase client init |
| `supabase-admin.ts` | Supabase service-role client |
| `postgres-pool.ts` | TCP connection pool singleton (globalThis, idle_timeout: 10s) |

### Crypto (src/lib/crypto/) — 28 files, client-side only
Core (documented previously): `encryption-service.ts`, `keystore.ts`, `encrypted-store.ts`,
`x3dh.ts`, `double-ratchet.ts`, `sender-keys.ts`, `file-encryption.ts`, `mutex.ts`, `uuidv7.ts`

Extended modules:
| File | Purpose |
|------|---------|
| `primitives.ts` | Low-level crypto primitives (XChaCha20-Poly1305, HKDF, Ed25519) |
| `types.ts` | Shared crypto TypeScript types |
| `pqxdh.ts` | Post-quantum X3DH hybrid (X25519 + Kyber-1024) |
| `kyber.ts` | Kyber-1024 KEM operations |
| `streaming-aead.ts` | Streaming AEAD for media (64KB chunks, up to 2GB) |
| `message-franking.ts` | Cryptographic message franking (E2EE moderation) |
| `hardware-keys.ts` | Hardware-backed key storage interface |
| `key-manager.ts` | Key lifecycle management (rotation, expiry) |
| `device-registry.ts` | Multi-device registry (Sesame protocol, 5-device limit) |
| `device-linking.ts` | QR-based device linking flow |
| `dm-routing.ts` | DM key routing for 1:1 sessions |
| `sk-recovery.ts` | Sender key recovery handler |
| `outbox.ts` | Client-side outbox (offline-safe send queue) |
| `message-cache.ts` | Decrypted message cache (bounded) |
| `e2ee-observability.ts` | E2EE metrics and observability |
| `link-unfurl.ts` | Encrypted link unfurling |
| `blurhash.ts` | BlurHash encode/decode for E2EE media previews |
| `index.ts` | Barrel re-exports |

HKDF info strings use `XarkE2EE-*` prefix — crypto constants, do not rename.
Keystore DB names use `xark-keystore` / `xark_store_salt` — crypto constants, do not rename.

### Intelligence (src/lib/intelligence/) — 18 files
| File | Purpose |
|------|---------|
| `orchestrator.ts` | 3-tier AI routing (gemini-local ~7-10s, gemini-search ~40-50s, apify 15-50s) |
| `tool-registry.ts` | 8 AI tools registry |
| `ai-provider.ts` | AI provider interface |
| `ai-provider-factory.ts` | Provider factory (selects by capability/cost) |
| `apify-client.ts` | Apify scraping client |
| `searchapi-client.ts` | SearchAPI.io client |
| `fli-client.ts` | Flight data client |
| `flight-cache.ts` | Flight results cache |
| `async-queue.ts` | Async concurrency queue |
| `global-semaphore.ts` | Cross-request concurrency semaphore |
| `search-cache.ts` | Search results cache |
| `sanitize.ts` | AI output sanitization |
| `taste-intersection.ts` | Group taste profile intersection |
| `deep-links.ts` | Travel/booking deep link generation |
| `geospatial.ts` | Geo proximity and region helpers |
| `conflict-resolver.ts` | Decision conflict resolution |
| `itinerary-generator.ts` | Structured itinerary generation |
| `sanitize.test.ts` | Sanitize unit tests |

### Discovery (src/lib/discovery/) — 7 files
Backs all 8 `/api/discovery/*` routes. Entirely distinct from intelligence/.

| File | Purpose |
|------|---------|
| `types.ts` | Discovery item and provider TypeScript types |
| `provider-registry.ts` | Provider registration and lookup |
| `registry-instance.ts` | Singleton registry instance |
| `sanitize.ts` | Discovery result sanitization |
| `providers/seeded-catalog.ts` | Static seeded catalog provider |
| `providers/gemini-enrichment.ts` | Gemini-based item enrichment provider |
| `providers/apify-scraping.ts` | Apify scraping provider |

### Ports — Strangler Fig Interfaces (src/lib/ports/)
| File | Purpose |
|------|---------|
| `message-gateway.ts` | MessageGateway interface (transport abstraction) |
| `realtime-gateway.ts` | RealtimeGateway interface |
| `transient-queue.ts` | TransientQueue interface |
| `index.ts` | Barrel re-exports |

### Media (src/lib/media/)
| File | Purpose |
|------|---------|
| `thumbnail-generator.ts` | Client-side thumbnail generation for E2EE media uploads |

### Domain / Business Logic
| File | Purpose |
|------|---------|
| `home-feed.ts` | Priority-sorted cross-group home feed with time decay |
| `suggestions.ts` | Proactive suggestion engine (onboarding, consensus_ready, missing_category, nudge_vote) |
| `consensus.ts` | Consensus voting module |
| `group-actions.ts` | Group creation, membership, and management |
| `messages.ts` | Supabase Postgres chat persistence + Realtime sync |
| `ai-grounding.ts` | buildGroundingContext(), state map approach, getGreeting() |
| `heart-sort.ts` | SSOT for all decision ranking |
| `state-flows.ts` | 4 preset state machine flows |
| `claims.ts` | Green-Lock commitment + ownership history |
| `space-data.ts` | Group list fetching (batched 4-query pattern + RPC) |
| `space-state.ts` | computeSpaceState() → empty/exploring/converging/ready/active/settled |
| `ledger.ts` | Settlement math, Venmo/UPI deep links |
| `theme.ts` | Global type scale, text sizes, color helpers (textColor, accentColor) |
| `taste.ts` | User taste profile management |
| `calendar.ts` | Calendar integration helpers |
| `member-logistics.ts` | Member travel/logistics aggregation |
| `og-extract.ts` | OG metadata extraction with SSRF protection |
| `sse-stream.ts` | SSE streaming helpers |
| `realtime-receipts.ts` | Realtime read receipt sync |
| `typing-indicators.ts` | Typing indicator broadcast |
| `unread.ts` | Unread count management |
| `notifications.ts` | Push notification helpers |
| `storage.ts` | Firebase Storage helpers (E2EE media) |
| `storage-rules.ts` | Storage access rule validators |
| `user-id.ts` | User ID helpers (text format, e.g. `name_ram`) |
| `media.ts` | Media upload/download orchestration |
| `spaces.ts` | Space/group misc helpers |
| `unsplash.ts` | Unsplash image search |
| `playground.ts` | Playground/demo helpers |
| `seed.ts` | Dev seed data |
| `constraints.ts` | Constraint detection for intelligence |
| `space-templates.ts` | Group template presets |

---

## CSS Variables — Full List

All tokens defined in `src/app/globals.css`. Overridden per-theme by `ThemeProvider.tsx`.
4 themes: `hearth` (flat light, default), `hearth_dark`, `vibe` (depth light), `vibe_dark`.

**No-bold mandate:** font-weight 400 primary, 300 secondary. Weights 500–900 are forbidden.
**Font system:** Inter (variable) body, Syne (variable) display.

### Surfaces
| Variable | Hearth value | Notes |
|----------|-------------|-------|
| `--hello-void` | `#FAFAFA` | Canvas / page background (near-WHITE despite "void" name) |
| `--hello-void-rgb` | `250, 250, 250` | |
| `--hello-surface-chrome` | `#FAFAFA` | Top bars, bottom bars |
| `--hello-surface-canvas` | `#FAFAFA` | Content canvas |
| `--hello-surface-recessed` | `#F0F0F0` | Inset / trough areas |

### Ink (text)
| Variable | Hearth value | Notes |
|----------|-------------|-------|
| `--hello-white` | `#111111` | Primary text (near-BLACK despite "white" name) |
| `--hello-white-rgb` | `17, 17, 17` | Used for `rgba(var(--hello-white-rgb), 0.45)` etc. |
| `--hello-ink-primary` | `#000000` | Solid primary ink (never use opacity) |
| `--hello-ink-secondary` | `#6B6B78` | Solid secondary ink |
| `--hello-ink-tertiary` | `#8A8A94` | Solid tertiary ink |
| `--hello-ink-sender` | `#9E6A06` | Sender name label color |

### Engine Signals
| Variable | Hearth value | Notes |
|----------|-------------|-------|
| `--hello-accent` | `#FF6B35` | Primary brand color (orange-red) |
| `--hello-accent-rgb` | `255, 107, 53` | |
| `--hello-cyan` | `#FF6B35` | ALIAS for --hello-accent — same value, not a distinct color |
| `--hello-cyan-rgb` | `255, 107, 53` | |
| `--hello-amber` | `#9E6A06` | LoveIt signal (+5 weight) |
| `--hello-amber-rgb` | `158, 106, 6` | |
| `--hello-gold` | `#8B6914` | Consensus/locked state |
| `--hello-gold-rgb` | `139, 105, 20` | |
| `--hello-green` | `#047857` | Settled/claimed state |
| `--hello-green-rgb` | `4, 120, 87` | |
| `--hello-orange` | `#C43D08` | NotForMe signal (-3 weight) |
| `--hello-orange-rgb` | `196, 61, 8` | |
| `--hello-gray` | `#8A8A94` | WorksForMe signal (+1 weight) |
| `--hello-gray-rgb` | `138, 138, 148` | |

### Chat Bubbles
| Variable | Hearth value | Notes |
|----------|-------------|-------|
| `--hello-bubble-received` | `#FFFFFF` | Received message bubble background |
| `--hello-bubble-sent` | `#F0F0F0` | Sent message bubble background |
| `--hello-bubble-text-received` | `#1A1A1A` | Received bubble text |
| `--hello-bubble-text-sent` | `#1A1A1A` | Sent bubble text |

`textColor(alpha)` and `accentColor(alpha)` from `theme.ts` generate opacity-based hierarchy values.

---

## Components (src/components/os/)
| Component | Purpose |
|-----------|---------|
| `HelloChat.tsx` | Chat stream with bubble architecture (sent/received/@hello) |
| `DecisionBoard.tsx` | Decision card rails with heartSort ranking |
| `HelloPanel.tsx` | @hello AI panel |
| `ChatInput.tsx` | Input pill with @hello chip detection, voice, media, URL detection |
| `SpotlightSheet.tsx` | @hello invocation overlay with GhostInput |
| `ControlCaret.tsx` | Living brand anchor, tap opens SpotlightSheet |
| `DecisionCard.tsx` | Immersive decision card (82% viewport, cinematic gradient) |
| `AwarenessStream.tsx` | Group summary list (priority-sorted, time decay, unread badges) |
| `PeopleDock.tsx` | 1:1 chat list with unread badges |
| `ThemeProvider.tsx` | Global theme context, sets CSS variables on :root |
| `UserMenu.tsx` | Settings sheet (profile/notifications/about, theme toggles) |
| `ConsensusBanner.tsx` | Pinned banner above chat during consensus countdown |
| `EncryptedMedia.tsx` | E2EE media renderer (download → decrypt → render) |
| `InviteSurface.tsx` | People tab empty state with invite CTA |
| `WelcomeScreen.tsx` | Login entrance with 4-phase choreography |

---

## Hooks (src/hooks/) — 11 hooks
| Hook | Purpose |
|------|---------|
| `useAuth.ts` | Firebase phone OTP → dev-auto-login JWT → name-only fallback |
| `useE2EE.ts` | E2EE lifecycle, key registration, device ID tracking |
| `useHelloAI.ts` | @hello AI sheet state, routes to /api/hello |
| `useHandshake.ts` | Consensus monitor, triggers at >80%, executes Green-Lock |
| `useReactions.ts` | Voting hook with JWT guard and per-item debounce |
| `useWhispers.ts` | Proactive suggestion queue (60s poll) |
| `useKeyboard.ts` | Virtual keyboard detection via visualViewport |
| `useVoiceInput.ts` | On-device SpeechRecognition (tap = dictation, long-press = @hello) |
| `useDeviceTier.ts` | Device capability detection |
| `usePlaygroundChoreography.ts` | Timer-based demo choreography |
| `useDisplayName.ts` | Display name resolution |

---

## Test Infrastructure

### Test runners
- **vitest** — primary unit test runner (`npm test` = `vitest run`). tsx is NOT in package.json.
- **Playwright** (`@playwright/test`) — E2E tests.
- **`npx tsx web/tests/sdk-validation.ts`** — standalone 100-test script. Fragile: `tsx` is not in
  `package.json` devDependencies (only `vitest` is). Requires global `tsx` or `npx`.

### Unit tests (vitest)
| File | Coverage |
|------|---------|
| `web/src/lib/__tests__/space-state.test.ts` | computeSpaceState() |
| `web/src/lib/__tests__/calendar.test.ts` | Calendar helpers |
| `web/src/lib/__tests__/local-agent.test.ts` | Local agent logic |
| `web/src/lib/__tests__/member-logistics.test.ts` | Member logistics |
| `web/src/lib/__tests__/taste.test.ts` | Taste profile |
| `web/src/lib/intelligence/sanitize.test.ts` | AI output sanitization |
| `web/src/lib/og-extract.test.ts` | OG extraction |
| `web/src/lib/space-templates.test.ts` | Space templates |
| `web/src/lib/crypto/crypto.test.ts` | Crypto primitives |

### Integration / E2E tests
| File | Type | Coverage |
|------|------|---------|
| `web/tests/sdk-validation.ts` | Standalone tsx | 100 tests: 50 stress + 50 crypto |
| `web/tests/discovery/discovery-api.test.ts` | vitest | Discovery API routes |
| `web/tests/orchestrator-stress/runner.ts` | stress | Orchestrator load test (+ scenarios.json, results.json) |
| `web/tests/e2e/link-preview-pipeline.spec.ts` | Playwright | Link preview end-to-end |
| `web/tests/e2e/media-pipeline.spec.ts` | Playwright | E2EE media pipeline end-to-end |
| `web/tests/fixtures/generate-test-image.ts` | fixture | Test image generator |

---

## Bootstrap Reading List

For a fresh agent entering `web/`:

1. `~/hello/CLAUDE.md` — monorepo architecture, security boundary, terminology
2. `~/hello/DESIGN.md` — visual law (no-bold, zero-box, glass rules). Read before ANY UI change.
3. `web/src/app/globals.css` — CSS variable definitions, theme tokens, animations
4. `web/src/lib/theme.ts` — type scale and color helpers
5. `web/src/proxy.ts` — edge security layer (rate limiting, CSP, nonce injection)
6. `web/CONSTITUTION.md` — visual and architectural law
7. `web/GROUNDING_PROTOCOL.md` — @hello AI behavior spec
8. `web/SECURITY.md` — E2EE architecture and privacy policy
