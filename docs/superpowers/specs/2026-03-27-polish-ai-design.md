# Spec 4+5: "Polish" (UX) + "Moat" (AI & Anti-Abuse)

**Date:** 2026-03-27
**Scope:** Phase 5 (tasks 36-42) + Phase 6 (tasks 43-50) from crypto.md
**Platform:** Flutter app (UI), Engine (Dart), Web (Next.js), Native (iOS/Android)

---

## Phase 5: World-Class UI/UX Polish

### 36. Frame-Perfect Keyboard Intrusion
Custom `WindowInsets` handling so the chat input is physically bound to the keyboard at 120hz. No standard Flutter jank.

### 37. Virtualized Reverse Scroll
Custom `SliverList(reverse: true)` with widget recycling for smooth 120fps scrolling through 100k+ messages.

### 38. Parameterized Spring Physics
Replace all `Curves.easeOut` with `SpringSimulation(mass, stiffness, damping)` for tactile, weighty animations.

### 39. BlurHash E2EE Injection
Calculate base64 BlurHash before encrypting images. Send in plaintext envelope metadata as instant placeholder.

### 40. Client-Side Link Unfurling
Client calls `/api/proxy-scrape`, downloads OG data, encrypts locally, sends as E2EE payload. Server never sees URLs.

### 41. Interactive Lock-Screen Actions
Vote on decisions from iOS/Android notification actions. Background isolate decrypts choices, registers vote, updates Drift.

### 42. Ephemeral Typing Indicators
Typing indicators via Realtime Broadcast (not DB). Auto-clear after 5 seconds to prevent ghost typing.

---

## Phase 6: AI, Intelligence & Anti-Abuse

### 43. SSE AI Streaming
Stream @hello AI responses via Server-Sent Events for real-time typing in UI.

### 44. Async AI Worker Queue
Move heavy Apify scraping to async queue. Return 202 Accepted instantly.

### 45. On-Device SLMs
Deploy quantized SLMs via CoreML/NNAPI for local constraint detection (diet/budget).

### 46. Taste Graph Intersection
Mathematically intersect JSON taste profiles of active group members before hitting LLM.

### 47. Cryptographic Message Franking
Reporting system where user unwraps one message's key for moderation, preserving E2EE for rest.

### 48. Client-Side E2EE Observability
Sentry for client-side Double Ratchet exceptions. Server HTTP 200s are blind to E2EE failures.

### 49. Private Contact Discovery (PSI)
Truncated SHA-256 hash prefix matching for phone contact lookup without exposing social graph.

### 50. Blind Storage Security Rules
Firebase Storage rules that verify JWT sub belongs to the group_id of the encrypted blob.
