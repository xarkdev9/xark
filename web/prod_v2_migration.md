# Xark OS — Production v2 Migration Plan

**Date**: 2026-03-17
**From**: PRD v1 (pre-launch, local dev)
**To**: Production v2 (public launch, first 100 users)
**Codebase**: /Users/ramchitturi/xark9

---

## 1. EXISTING ARCHITECTURE (What We Have Today)

### 1.1 Tech Stack (Locked)

| Layer | Technology | Status |
|-------|-----------|--------|
| Frontend | Next.js 16.1.6 + React 19 + TypeScript 5 + Framer Motion 12 | Production-ready |
| Database | Supabase Postgres + RLS + Realtime | Production-ready |
| Auth | Firebase Phone OTP + dev-auto-login fallback | Production-ready |
| Storage | Firebase Storage (photos, hero images, key backups) | Production-ready |
| Push | Firebase Cloud Messaging (FCM) | Production-ready |
| AI | Gemini 2.5 Flash + Apify Actors | Production-ready |
| Hosting | Vercel (Next.js) | Deployed at xark.vercel.app |
| Photos | Pexels API (free, 200/hr) + Unsplash fallback | Configured |

### 1.2 Core Services (9 domains, loosely coupled)

| Service | Status | Key Files |
|---------|--------|-----------|
| **Auth** | Working | useAuth.ts, /api/phone-auth, /api/dev-auto-login, /api/join |
| **Space** | Working | spaces.ts, space-data.ts, space-state.ts |
| **Intelligence** | Working (but embedded in chat) | orchestrator.ts, tool-registry.ts, apify-client.ts |
| **Decision Engine** | Working | heart-sort.ts, PossibilityHorizon.tsx, DecisionCard.tsx |
| **Messaging** | Working | messages.ts, XarkChat.tsx, ChatInput.tsx |
| **Media** | Working | media.ts, storage.ts, unsplash.ts |
| **Notification** | Working | notifications.ts, /api/notify, sw.js |
| **Settlement** | Working | ledger.ts, ClaimSheet.tsx, PurchaseSheet.tsx |
| **Itinerary** | Working | ItineraryView.tsx, MemoriesView.tsx |

### 1.3 UI Components (Current State)

| Component | Status | Description |
|-----------|--------|-------------|
| Login page | Complete | Cinematic video background, phase-based choreography, 4 Pexels videos |
| WelcomeScreen | Complete | Transparent overlay, phase animation (spark→collision→reveal→idle) |
| Galaxy page | Complete | 3 tabs (people/plans/memories), tab-aware dream input, contact reveal, swipe |
| Space page | Complete | discuss/decide/itinerary/memories views, swipe, share options sheet |
| PossibilityHorizon | Complete | Immersive snap-scroll cards, 10-hero pool, editorial headers |
| DecisionCard | Complete | 82%×50dvh, full-bleed photo, 56px score, cinematic gradient |
| XarkChat | Complete | WhatsApp-precision spacing (16px/400/1.35), typing indicator, inline invite |
| ChatInput | Complete | Magnetic Input, gradient floor, @xark cyan detection, typewriter placeholder |
| ControlCaret | Complete | "xark" brand anchor, breathing 0.7→0.9, neon glow |
| UserMenu | Complete | 4-view drill-down, theme toggles, notifications |
| Avatar | Complete | surface.recessed background, letter fallback |
| Ghost Playground | Complete | 4 sandbox spaces, choreography engine, diegetic whispers |
| PlaygroundSpace | Complete | Mock reactions, mock @xark, swipe, no Supabase |

### 1.4 Design System

| Token | Current Value | Notes |
|-------|--------------|-------|
| Brand color | #FF6B35 (Action Orange) | Brand anchor, vibe_dark accent, love signal |
| Surface system | chrome/canvas/recessed (3-tone) | Depth without borders |
| Typography | text.subtitle: 16px/400/1.35 | WhatsApp parity |
| Zero-Box | No borders, no cards, no containers | Constitutional law |
| No-Bold | Weight 300/400 only | Constitutional law |
| Themes | 4 (hearth, hearth_dark, vibe, vibe_dark) | All via CSS variables |

### 1.5 E2EE (Current State — BROKEN, DISABLED)

| Component | Status | Issue |
|-----------|--------|-------|
| Signal Protocol (Double Ratchet + Sender Keys) | Implemented | Multiple P0/P1 vulnerabilities |
| IndexedDB KeyStore | Implemented | **P0: Private keys in plaintext** |
| Memory Worker | Implemented | **P0: Decrypted messages persisted unencrypted** |
| X3DH Key Agreement | Implemented | 3 DH (OTK skipped in SK distribution) |
| Sender Key Rotation | NOT implemented | Claimed in SECURITY.md but deferred |
| Safety Number Verification | NOT implemented | v3 roadmap |
| Key Transparency Log | NOT implemented | v3 roadmap |
| Sealed Sender | NOT implemented | v3 roadmap |
| E2EE toggle | **Forced OFF** | `useE2EE(null)` in Space page |

### 1.6 Database Migrations (Applied)

| Migration | Status | Contents |
|-----------|--------|----------|
| 001-013 | Applied | Core schema, RLS, RPCs, indexes, daily use features |
| 014 | Applied | E2EE tables (key_bundles, OTKs, ciphertexts, constraints) |
| 015 | Applied | E2EE wiring (RPCs, indexes) |
| 017 | Needs running | space_ledger (Tier 1 admin audit) |
| 018 | Needs running | invite token 16 bytes |
| 019 | Needs running | unread counts (last_read_at, RPCs) |

### 1.7 Parked/Incomplete Features

| Feature | Status | Why Parked |
|---------|--------|------------|
| Tier 1 Local Agent | Code exists, untested | Browser debugging needed |
| Tier 2 Memory Worker | Code exists | P0-2 vulnerability, to be deleted |
| LedgerPill (interactive pills) | Code exists | Depends on Tier 1 |
| ContextCard (recall results) | Code exists | Depends on Tier 2 |
| E2EE | Code exists, disabled | Multiple audit failures |
| Backup/Restore UI | Not built | Depends on E2EE fix |
| Device Linking (QR) | Not built | v2 roadmap |

---

## 2. WHAT NEEDS TO MIGRATE (v1 → v2)

### 2.1 Architecture Migration: @xark OUT of Chat

**The biggest structural change.** Currently @xark is embedded in the chat pipeline — creating E2EE complexity, dual message paths, and latency in the chat experience.

**Current (v1):**
```
Chat → detect @xark → split: E2EE path + plaintext @xark path
  → two message types (e2ee, e2ee_xark)
  → server processes @xark command
  → results injected back into chat + Decide tab
  → Memory Worker indexes plaintext
  → 3-layer architecture required
```

**Target (v2):**
```
Chat → pure E2EE messaging (one path, one type)
  → no @xark detection, no AI triggers
  → no plaintext leak, no Memory Worker

Xark Spotlight → global command bar from brand anchor
  → user types query → selects space → results placed in Decide tab
  → completely separate from chat
  → unencrypted by nature (Layer 3 only)
  → no E2EE complexity
```

**What gets deleted:**
- `message_type: 'e2ee_xark'`
- `@xark` detection in `sendMessage()`
- `message_type_override` field in `/api/message`
- Memory Worker (`src/workers/memory-worker.ts`) — **solves P0-2**
- `useLocalMemory.ts` hook
- `local-recall.ts` (Tier 2 recall)
- `InlineCardPreview.tsx` in chat
- "thinking..." indicator in chat
- `@xark` cyan text detection in ChatInput
- Three-tier routing in chat flow

**What gets built:**
- `XarkSpotlight.tsx` — global command bar triggered by brand anchor tap
- Simplified `/api/xark` — returns structured JSON only (no chat message writes)
- Space picker in Spotlight — "which space?"
- Ledger commands — "@xark I paid $320 for dinner" parsed in Spotlight

### 2.2 E2EE Migration (master_plan.md Phases 1-4)

| Phase | Goal | Key Tasks |
|-------|------|-----------|
| **Phase 1: Crypto Bedrock** | Non-extractable keys, OTK lifecycle | WebCrypto migration (P0-1 fix), OTK cleanup, X3DH ephemeral key fix |
| **Phase 2: 1:1 E2EE** | Secure private routing | Deterministic 1:1 routing, ratchet header encryption (P1-1 fix), device matching |
| **Phase 3: Group E2EE** | Sender Keys with forward secrecy | Remove private key from distribution (BUG 15), skipped-key dictionary, **enforced SK rotation on leave (P1-3 fix)** |
| **Phase 4: Network Sync** | Race condition fixes | JWT race, broadcast vs DB write race, SK distribution pagination |

### 2.3 Guest Mode (Trojan Horse — Existential Priority)

**Not in master_plan.md. Must be added.**

| Component | Description |
|-----------|-------------|
| `/invite/[token]` public route | Server-rendered, zero auth, <1s load |
| Anonymous voting | Session token in cookie, no account required |
| Real-time consensus | Supabase Realtime subscription (already exists) |
| Download wall at 80% | "Locked. Download Xark to claim and split." |
| Rich link preview | OG tags for WhatsApp/iMessage unfurl |

### 2.4 Settlement Upgrade (Natural Language)

| Current | Target |
|---------|--------|
| 5-tap PurchaseSheet (tap item → claim → tap again → enter amount → confirm) | "I paid $320 for nobu" in Spotlight → parsed → ledger updated → 1 tap confirm |
| Manual amount entry | @xark parses amount + item from natural language |
| No reminders | @xark sends witty settlement reminders via push |

### 2.5 Security Hardening (From Audit)

| Item | Priority | Status |
|------|----------|--------|
| IndexedDB encryption (WebCrypto) | P0 | In master_plan Phase 1 |
| Delete Memory Worker | P0 | Part of Spotlight migration |
| Ratchet header encryption | P1 | In master_plan Phase 2 |
| Always consume OTK in SK distribution | P1 | Needs adding to Phase 3 |
| SK rotation on member leave | P1 | In master_plan Phase 3 |
| Remove message_type_override | P1 | Part of Spotlight migration |
| Recipient-side SK identity verification | P1 | Needs adding to Phase 3 |
| Safety number verification UI | P2 | Post-launch |
| Key transparency log | P3 | v3 roadmap |
| Sealed sender | P3 | v3 roadmap |

### 2.6 Pending Migrations

| Migration | Contents | Priority |
|-----------|----------|----------|
| 017 | space_ledger table | Run before Tier 1 testing |
| 018 | invite token 16 bytes | Run before launch |
| 019 | unread counts | Run before launch |
| 020 (new) | Guest mode tables (anonymous_votes, guest_sessions) | Build with Guest Mode |

---

## 3. WHAT'S PENDING (Checklist)

### 3.1 Must Have for Launch (P0)

- [ ] **Xark Spotlight** — extract @xark from chat into global command bar
- [ ] **Delete Memory Worker** — removes P0-2 vulnerability
- [ ] **Guest Mode web view** — `/invite/[token]` zero-auth public page
- [ ] **WebCrypto key migration** — non-extractable identity keys (P0-1)
- [ ] **Run migrations 017-019** on production Supabase
- [ ] **Upstash Redis rate limiter** — replace in-memory (doesn't work on Vercel serverless)
- [ ] **Test voting end-to-end** — react → score update → consensus → lock
- [ ] **Test Ghost Playground** — all 4 space choreographies in browser
- [ ] **Remove debug banner** from Space page (still has green monospace overlay)

### 3.2 Must Have for Security Claims (P1)

- [ ] E2EE Phase 1-4 (master_plan.md) — complete and re-enable
- [ ] Ratchet header encryption
- [ ] OTK consumption in SK distribution
- [ ] SK rotation on member leave
- [ ] Remove message_type_override from API
- [ ] Recipient-side SK identity verification
- [ ] Update SECURITY.md to reflect actual implementation (remove false claims)

### 3.3 Should Have for Launch (P2)

- [ ] Natural language ledger — "@xark I paid $320" in Spotlight
- [ ] Settlement push reminders — witty @xark nudges
- [ ] Signed pre-key rotation (30-day cycle)
- [ ] @xark streaming responses (reduce perceived latency)
- [ ] Increase MAX_SKIP to 2000 (Signal standard)

### 3.4 Nice to Have (P3)

- [ ] Safety number verification UI
- [ ] Key transparency log
- [ ] Sealed sender
- [ ] Native shell (iOS/Android) with OS keychain
- [ ] Cross-trip memory (@xark remembers preferences)
- [ ] Calendar integration
- [ ] Multi-tool @xark calls ("find flights AND hotels")

---

## 4. FINAL GOAL: PRODUCTION v2

### 4.1 Architecture (Target State)

```
┌──────────────────────────────────────────────────────────┐
│                      CLIENT (PWA)                         │
│                                                           │
│  ┌────────────────┐  ┌───────────────┐  ┌──────────────┐│
│  │   CHAT (E2EE)  │  │ XARK SPOTLIGHT│  │ GUEST VIEW   ││
│  │                │  │  (Layer 3)    │  │ (zero-auth)  ││
│  │ Pure messaging │  │              │  │              ││
│  │ No AI, no @xark│  │ "find sushi" │  │ Vote on cards││
│  │ Signal Protocol│  │  → space?    │  │ See consensus││
│  │ Forward secrecy│  │  → results   │  │ Download wall││
│  │ WebCrypto keys │  │  → Decide tab│  │ at 80% lock  ││
│  │                │  │              │  │              ││
│  │ "I paid $320"  │  │              │  │              ││
│  │  → ledger      │  │              │  │              ││
│  └───────┬────────┘  └──────┬───────┘  └──────┬───────┘│
│          │                  │                  │         │
│     Layer 2              Layer 3           Layer 3       │
│   (encrypted)          (plaintext)       (public)       │
│          │                  │                  │         │
│  POST /api/message   POST /api/xark    GET /invite/[t] │
│  (ciphertext only)   (structured JSON)  (SSR, no auth)  │
└──────────┼──────────────────┼──────────────────┼────────┘
           │                  │                  │
      ═════╪══════════════════╪══════════════════╪═════
           │                  │                  │
┌──────────┼──────────────────┼──────────────────┼────────┐
│     Supabase           Gemini/Apify       Supabase      │
│  messages (cipher)     AI responses     anonymous_votes  │
│  key_bundles           → decision_items  guest_sessions  │
│  ciphertexts           → settlement      → Realtime     │
│                        → no chat access                  │
└─────────────────────────────────────────────────────────┘
```

### 4.2 User Experience (Target)

| Flow | Experience |
|------|-----------|
| **New user opens app** | Ghost Playground → 4 sandbox spaces → discovers voting, @xark, settlement, memories |
| **User creates a plan** | Dream input → space created → Xark Spotlight → "find hotels in tahoe" → cards appear in Decide |
| **User invites friends** | Inline "invite someone →" → WhatsApp/SMS share → friend taps link → Guest View → votes immediately → download wall at lock |
| **Group decides** | Heart-sort ranking → 80% consensus → gold burst → lock → claim → purchase → settlement |
| **User pays** | Spotlight: "I paid $320 for the hotel" → parsed → ledger → "you owe kai $80" → Venmo link |
| **After the trip** | Memories tab → photo scrapbook → settlement cleared → "all settled up" |

### 4.3 Security Posture (Target)

| Property | v1 (Current) | v2 (Target) |
|----------|-------------|-------------|
| Key storage | Plaintext IndexedDB | WebCrypto non-extractable CryptoKey |
| Message storage (client) | Plaintext in Memory Worker | No client-side plaintext persistence |
| Message storage (server) | Ciphertext only | Ciphertext only (unchanged) |
| @xark in chat | Plaintext leak via @xark trigger | Zero — Spotlight is separate pipeline |
| SK rotation on leave | Not implemented | Enforced |
| Ratchet headers | Plaintext base64 | Encrypted with shared secret |
| OTK in SK distribution | Skipped (3 DH) | Always consumed (4 DH) |
| Rate limiting | In-memory (broken on serverless) | Upstash Redis |

### 4.4 What v2 Does NOT Include (Explicit Scope Cut)

- No native app (stays PWA)
- No in-app payment processing (deep links only)
- No large groups (15+ members)
- No video memories (photos only)
- No calendar integration
- No sealed sender (v3)
- No key transparency (v3)
- No multi-device sync (single device per user in v2)

---

## 5. EXECUTION SEQUENCE

| Week | Phase | Deliverable |
|------|-------|-------------|
| **Week 1** | Spotlight + Cleanup | Build XarkSpotlight.tsx, delete Memory Worker, remove @xark from chat, simplify /api/message |
| **Week 2** | Crypto Bedrock | WebCrypto migration (P0-1), OTK lifecycle, X3DH ephemeral fix |
| **Week 3** | E2EE Phases 2-3 | 1:1 routing, header encryption, SK rotation, device matching |
| **Week 4** | Guest Mode | /invite/[token] public page, anonymous voting, download wall, rich link preview |
| **Week 5** | Polish + Security | E2EE Phase 4 (races), Upstash Redis, run migrations, remove debug banner, stress test 10-15 users |
| **Week 6** | Launch | Ghost Playground tested, Guest Mode tested, 4-6 person group tested, "dinner tonight" wedge marketed |

### The North Star

**"Start with dinner. Earn the trip."**

Xark v2 launches targeting weekly dinner decisions for groups of 4-6. Not bachelorette parties. Not 15-person trips. Four friends on a Friday night who can't agree on where to eat. One of them opens Xark Spotlight, types "sushi near downtown," sends a link to the WhatsApp group. Friends tap the link, vote in the browser, the restaurant locks at 80%. Done. Table booked.

That's the product. Everything else is architecture in service of that 30-second moment.
