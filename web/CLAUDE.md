# CLAUDE.md — hello OS / Web App (Next.js)

Web-specific guidance. See `~/hello/CLAUDE.md` for the full architecture overview, terminology, and infrastructure lock.

## Commands
```bash
npm run dev          # Next.js dev server (port 3000 only)
npm run build        # Production build
npx tsc --noEmit     # Type-check without emitting
```

## API Routes (23 endpoints)
| Route | Method | Purpose |
|-------|--------|---------|
| `/api/hello` | POST | @hello AI orchestration, 3-tier routing (maxDuration 60s) |
| `/api/hello/webhook` | POST | @hello webhook handler |
| `/api/message` | POST | E2EE message send (atomic: message + ciphertext + SK distribution) |
| `/api/chat/start` | POST | Find-or-create 1:1 chat via `find_or_create_chat` RPC |
| `/api/contacts/check` | POST | Phone number registration lookup (max 500) |
| `/api/phone-auth` | POST | Exchange Firebase phone OTP for Supabase-compatible JWT |
| `/api/keys/bundle` | POST | E2EE key bundle upload |
| `/api/keys/otk` | POST | OTK batch upload (max 200) |
| `/api/keys/fetch` | POST | Atomic key bundle fetch (FOR UPDATE SKIP LOCKED) |
| `/api/invite` | POST | Generate 128-bit hex cryptographic invite link |
| `/api/invite/validate` | GET | Validate invite code, return creator name |
| `/api/invite/claim` | POST | Firebase auth -> atomic claim -> create group -> JWT |
| `/api/join` | POST | Name-only invite join, create user, sign JWT |
| `/api/local-action` | POST | Tier 1 mutations (update_dates, rename, revert, create_group) |
| `/api/notify` | POST | FCM push to group members (filters muted) |
| `/api/og` | POST | OG metadata extraction with SSRF protection |
| `/api/onboarding` | POST | Day 1 onboarding endpoint |
| `/api/proxy-scrape` | POST | Blind OG metadata proxy (no auth, SSRF-protected) |
| `/api/share` | POST | PWA share target handler |
| `/api/dev-auth` | POST | Dev login with password (404 in production) |
| `/api/dev-auto-login` | POST | Passwordless dev login (404 in production) |
| `/api/cron/consensus` | GET | Auto-lock expired consensus countdowns (daily) |
| `/api/cron/purge` | GET | Purge expired @hello messages + invite links (daily) |

## Key Modules (src/lib/)
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
| `space-state.ts` | computeSpaceState() -> empty/exploring/converging/ready/active/settled |
| `ledger.ts` | Settlement math, venmo/upi deep links |
| `theme.ts` | Global type scale, text sizes, color helpers (textColor, accentColor) |
| `intelligence/` | orchestrator.ts (3-tier), tool-registry.ts (8 tools), apify-client.ts, sanitize.ts |
| `crypto/` | Full E2EE module (see Crypto section below) |

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
| `ThemeProvider.tsx` | Global theme context, sets 20+ CSS variables on :root |
| `UserMenu.tsx` | Settings sheet (profile/notifications/about, theme toggles) |
| `ConsensusBanner.tsx` | Pinned banner above chat during consensus countdown |
| `EncryptedMedia.tsx` | E2EE media renderer (download -> decrypt -> render) |
| `InviteSurface.tsx` | People tab empty state with invite CTA |
| `WelcomeScreen.tsx` | Login entrance with 4-phase choreography |

## Hooks (src/hooks/) — 11 hooks
| Hook | Purpose |
|------|---------|
| `useAuth.ts` | Firebase phone OTP -> dev-auto-login JWT -> name-only fallback |
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

## Crypto Module (src/lib/crypto/)
Client-side only. The headless engine implementation lives in `~/hello/engine/`. Web has its own React-side crypto:
- `CryptoProvider.tsx` — React context for E2EE lifecycle
- `encryption-service.ts` — encryptForDM() (Double Ratchet), encryptForGroup() (Sender Keys), decryptMessage()
- `keystore.ts` — IndexedDB-backed persistent key storage (encrypted at rest via `encrypted-store.ts`)
- `x3dh.ts` — X3DH key agreement
- `double-ratchet.ts` — Double Ratchet with bounded skipped-key dictionary
- `sender-keys.ts` — Sender Key generation, encrypt/decrypt, Ed25519 signing
- `file-encryption.ts` — AES-256-GCM file encrypt/decrypt for E2EE media
- HKDF info strings use `XarkE2EE-*` prefix (crypto constants, do not rename)
- Keystore DB names use `xark-keystore` / `xark_store_salt` (crypto constants, do not rename)

## Theme System
4 themes: hearth (flat light, default), hearth_dark, vibe (depth light), vibe_dark.
- **No-bold mandate:** font-weight 400 primary, 300 secondary. 500-900 forbidden.
- **CSS variables** (`--hello-*` prefix) defined in `src/app/globals.css`:
  - Colors: `--hello-accent`, `--hello-white`, `--hello-void`
  - Engine signals: `--hello-amber`, `--hello-gold`, `--hello-green`, `--hello-orange`, `--hello-gray`
  - Ink system: `--hello-ink-primary`, `--hello-ink-secondary`, `--hello-ink-tertiary`
  - Surfaces: `--hello-surface-chrome`, `--hello-surface-canvas`, `--hello-surface-recessed`
  - Bubbles: `--hello-bubble-sent`, `--hello-bubble-received`
- `textColor(alpha)` and `accentColor(alpha)` from `theme.ts` for opacity-based hierarchy.
- Font system: Inter (variable) body, Syne (variable) display.

## Bootstrap
Before working on web/ code, read:
1. `~/hello/CLAUDE.md` — monorepo architecture and constraints
2. `src/app/globals.css` — CSS variable definitions and theme tokens
3. `src/lib/theme.ts` — type scale and color helpers
4. `CONSTITUTION.md` — visual and architectural law
5. `GROUNDING_PROTOCOL.md` — @hello AI behavior spec
6. `SECURITY.md` — E2EE architecture and privacy policy
