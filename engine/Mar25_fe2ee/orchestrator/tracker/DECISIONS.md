# E2EE Chat Engine — Decision & Change Log

**Purpose:** Every architectural decision, deviation from spec, assumption, and bug fix made during the overnight build is logged here. Review this file in the morning before reviewing code.

**Updated by:** Each agent appends to this file after completing its step.

---

## How to Read This File

- **DECISION**: A choice was made between two or more valid approaches
- **DEVIATION**: The agent could not follow the spec exactly and chose an alternative
- **ASSUMPTION**: The spec was ambiguous — the agent assumed an interpretation
- **BUG_FIX**: A bug was found in a previous agent's output and fixed
- **SKIPPED**: A feature or requirement was intentionally skipped (with reason)

---

## Log

### Step 00 — Discovery Agent (complete)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DECISION | Use React's custom HKDF info strings | React uses `'XarkE2EE-x3dh'`, `'XarkE2EE-ratchet'`, `'XarkE2EE-header-secret'`, `'XarkE2EE-header-key'` instead of Signal's standard strings. Flutter must match for interop. | Agent 03 crypto |
| 2 | DECISION | XChaCha20-Poly1305 for messages, AES-256-GCM for files | React uses two different ciphers. Messages use libsodium XChaCha20, files use Web Crypto AES-GCM. Flutter must implement both. | Agent 03, Agent 09 |
| 3 | DECISION | Header encryption (non-standard) | React encrypts ratchet headers — Signal spec sends them in cleartext. Flutter must do the same or sessions won't interop. | Agent 03 |
| 4 | DECISION | Messages via HTTP POST, not WebSocket | React POSTs to /api/message. Supabase Realtime only delivers notifications. Flutter transport layer should match. | Agent 06 |
| 5 | ASSUMPTION | Cross-platform interop required | Assumed Flutter engine must decrypt messages sent by React web app. All wire formats and HKDF strings must match exactly. Flagged as open question. | All agents |
| 6 | DEVIATION | Thumbnails: inline in React, separate upload in spec | React embeds base64 thumbnails inline. CLAUDE.md says separate encrypted upload. Recommended: follow CLAUDE.md spec but support inline for backwards compat. | Agent 09 |
| 7 | SKIPPED | Multi-device, contact discovery, profile encryption | Not implemented in React. Deferred to Phase 2 in CLAUDE.md. Agents should not depend on these. | Phase 2 |

**Duration:** — | **Tests:** N/A | **Warnings:** 5 open questions in CODEBASE_CONTEXT.md §8

<!-- AGENTS: Append entries below this line. Do NOT modify existing entries. -->
<!-- Format:
### Step {NN} — {Agent Name} ({STATUS})

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DECISION | ... | ... | ... |

**Duration:** X min | **Tests:** N/N passed | **Warnings:** ...
-->

### Step 01 — Scaffold (pending)
> Not started

### Step 02 — Domain Models (pending)
> Not started

### Step 03 — Crypto Layer (pending)
> Not started

### Step 04 — Crypto Tests (pending)
> Not started

### Step 05 — Persistence Layer (pending)
> Not started

### Step 06 — Transport Layer (pending)
> Not started

### Step 07 — Sync Engine (pending)
> Not started

### Step 08 — 1:1 Messaging (pending)
> Not started

### Step 09 — Media Pipeline (pending)
> Not started

### Step 10 — Public API (pending)
> Not started

### Step 11 — Integration Tests (pending)
> Not started

### Step 12 — Validation (pending)
> Not started

---

## Morning Review Checklist

- [ ] Read every DECISION — do you agree with the tradeoff?
- [ ] Read every DEVIATION — is the alternative acceptable or does it need a redo?
- [ ] Read every ASSUMPTION — was the assumption correct?
- [ ] Read every BUG_FIX — is the root cause understood?
- [ ] Read every SKIPPED — is it OK to ship Phase 1 without this?
- [ ] Check TRACKER.md for any FAILED steps
- [ ] Run `flutter test` to confirm all tests still pass
- [ ] Run `dart analyze --fatal-warnings` to confirm no new warnings
