# Three-Tier Hybrid Brain — Design Spec

**Date**: 2026-03-15
**Status**: Approved
**Scope**: Client-side local intelligence (Tier 1 + Tier 2) + Cloud orchestrator optimizations (Tier 3)

---

## 1. Problem Statement

Every `@xark` command — including simple admin actions like "set dates to june 1-5" and recall questions like "what hotel did nina mention?" — currently traverses the full server pipeline: E2EE encryption → network round-trip → Gemini API call → response. This produces:

- **Unnecessary latency**: 7-50s for commands that could resolve in <1ms locally
- **Unnecessary cost**: Gemini API tokens burned on deterministic admin operations
- **E2EE blind spot**: The server cannot search encrypted message history. Recall questions like "what was that sushi place?" produce hallucinated or confused responses because the cloud orchestrator has zero visibility into Layer 2 chat content.
- **No offline capability**: Users cannot organize local app state without a network connection

## 2. Architecture Overview

Three client-side tiers sit in front of the existing server pipeline. Every `@xark` message hits Tier 1 first, then Tier 2, then Tier 3. First match wins.

```
User types "@xark ..."
        │
        ▼
┌─── TIER 1: Fast-Path Router ───┐
│ Deterministic regex matching    │
│ Admin commands + state queries  │
│ <1ms, zero AI, zero network     │
│ Mutates Layer 3 + space_ledger  │
│ UI: interactive system pills    │
└──────────┬──────────────────────┘
           │ no match
           ▼
┌─── TIER 2: E2EE Memory Engine ──┐
│ isRecallQuestion() detector      │
│ Web Worker: search local index   │
│   High-tier: semantic (MiniLM)   │
│   Low-tier: lexical (FlexSearch) │
│ Encrypted blob at rest per space │
│ UI: actionable context card      │
│ Fallback: coaching whisper       │
└──────────┬───────────────────────┘
           │ no match / not recall
           ▼
┌─── TIER 3: Cloud Orchestrator ──┐
│ Existing E2EE → /api/message    │
│ or legacy → /api/xark           │
│ Gemini intent + Apify/Search    │
│ Heavy lifting: flights, hotels  │
│ Streaming synthesis + caching   │
└─────────────────────────────────┘
```

**Integration point**: `sendMessage()` in `src/app/space/[id]/page.tsx:291`. The interceptor runs at the top of this function, before E2EE encryption or any network call.

**Non-`@xark` messages** skip all three tiers entirely and go straight to the existing chat flow (broadcast + persist + optional E2EE).

## 3. Tier 1 — Fast-Path Router

**Module**: `src/lib/local-agent.ts`

### 3.1 Command Vocabulary (v1)

| Category | Example Commands | Execution |
|---|---|---|
| Date management | "set dates to june 1-5", "change dates", "push dates back a week" | Parse dates → POST `/api/local-action` (upserts `spaces.metadata` + `space_dates`, writes `space_ledger`) → Realtime syncs |
| Space admin | "rename space to Miami 2026", "rename this to ..." | POST `/api/local-action` (updates `spaces.title`, writes `space_ledger`) → Realtime |
| State queries | "who hasn't voted?", "what's the status?" | Read `decision_items` from local state (already fetched) → render popover with aggregate counts. No persistence. |
| Navigation | "show decide", "go to itinerary", "switch to memories" | Call `setView()` directly — pure UI, no DB, no ledger |

### 3.2 Pattern Matching

Strict regex with capture groups. No NLP library for v1 — keeps bundle at zero additional KB. compromise.js (~200KB) reserved for v2 if regex coverage proves insufficient.

### 3.3 The `space_ledger` Table

New Layer 3 table (unencrypted — admin actions mutate shared state that is already unencrypted).

```sql
create table space_ledger (
  id uuid primary key default gen_random_uuid(),
  space_id text not null references spaces(id),
  actor_id text not null,
  actor_name text,
  action text not null,           -- 'update_dates', 'rename_space', 'revert_update_dates', etc.
  payload jsonb default '{}',     -- { start_date, end_date } or { new_title }
  previous jsonb default '{}',    -- snapshot of old value (enables Undo)
  revert_target_id uuid,          -- links revert entries to the original (null for non-reverts)
  created_at timestamptz default now()
);

create index idx_ledger_space_created
  on space_ledger(space_id, created_at desc);

alter table space_ledger enable row level security;

create policy "members_read_ledger" on space_ledger
  for select using (space_id = any(auth_user_space_ids()));

create policy "members_write_ledger" on space_ledger
  for insert with check (
    space_id = any(auth_user_space_ids())
    and actor_id = auth.jwt()->>'sub'
  );

alter publication supabase_realtime add table space_ledger;

-- Guard: ensure auth_user_space_ids() is STABLE for RLS performance
alter function auth_user_space_ids() stable;
```

The `previous` column stores the pre-mutation state, making Undo a simple "restore previous + write a new revert ledger entry with `revert_target_id` linking to the original."

### 3.3a Server Route for Mutations (`/api/local-action`)

Tier 1 mutations (dates, rename) cannot execute client-side because:
- `spaces` table UPDATE RLS is owner-only (`owner_id = auth.jwt()->>'sub'`)
- `space_dates` table write policy is `service_role` only

Solution: A lightweight server route `/api/local-action` that accepts the mutation payload, validates the JWT, and executes via `supabaseAdmin` (service role, bypasses RLS). This preserves the security model while keeping the client-side latency benefit (the client still does the regex parsing and intent detection locally — only the DB write goes through the server).

```typescript
// /api/local-action/route.ts
// POST { action, spaceId, payload, previous }
// Validates JWT, checks space membership, executes mutation + ledger write atomically
// For date mutations: upserts BOTH spaces.metadata AND space_dates
```

Date mutations must write to `space_dates` (not just `spaces.metadata`) because downstream systems depend on it: `purge_expired_xark_messages()` RPC, Tier 2 lifecycle retention, `computeSpaceState()`.

### 3.4 Interactive System Pills

Ledger events are interleaved chronologically with chat messages in the timeline via Realtime subscription on `space_ledger`. Rendered as centered, muted pills — not chat bubbles:

```
        🗓️ ram updated dates to [june 1-5] · undo
```

Structure: contextual icon → actor → verb → [tappable payload] → undo.

- Icon: contextual per action type (🗓️ dates, ✏️ rename, etc.)
- Actor + verb: `text.timestamp` size, `ink.tertiary` color
- Tappable payload: `[june 1-5]` in `colors.cyan`, larger tap target. Can eventually open a date picker or edit modal.
- Undo: `ink.tertiary`, fires a revert mutation via `/api/local-action` (restore `previous` → new ledger entry with action `revert_*` and `revert_target_id` linking to the original entry)

### 3.5 Key Contract

```typescript
interface LocalCommand {
  pattern: RegExp;
  execute: (match: RegExpMatchArray, context: LocalContext) => LocalResult;
}

interface LocalContext {
  spaceId: string;
  userId: string;
  userName: string;
  spaceItems: SpaceStateItem[];  // already fetched in Space page
  setView: (view: ViewMode) => void;
  supabaseToken: string | null;  // JWT for /api/local-action calls
}

interface LocalResult {
  handled: true;
  ledgerEntry?: LedgerEntry;   // persisted, broadcast to group
  uiAction?: () => void;       // local-only UI mutation
  whisper?: string;             // local-only feedback to executor
}

interface LedgerEntry {
  space_id: string;
  actor_id: string;
  actor_name: string;
  action: string;
  payload: Record<string, unknown>;
  previous: Record<string, unknown>;
  revert_target_id?: string;  // UUID of the entry being reverted (for Undo linkage)
}
```

If `tryLocalAgent()` returns `{ handled: true }`, `sendMessage()` short-circuits — no E2EE, no network, no thinking indicator. The text evaporates from the input box and is never sent as a chat message.

## 4. Tier 2 — E2EE Memory Engine

### 4.1 Algorithmic Degradation

Device tier (from `useDeviceTier.ts`) determines which search engine the Web Worker loads:

| Device Tier | Search Engine | Library | Size | Capability |
|---|---|---|---|---|
| High | Semantic | transformers.js + all-MiniLM-L6-v2 (quantized ONNX) | ~22MB (cached) | Understands context: "where are we staying?" finds "I booked the Marriott" |
| Low | Lexical | FlexSearch or MiniSearch | ~15KB | Keyword/fuzzy match: "hotel" finds messages containing "hotel" |

Unified interface: the router logic (`isRecallQuestion`), the UI (context card), and the coaching whisper all stay the same. Only the Worker's internal search engine swaps.

### 4.2 Web Worker Lifecycle

**Module**: `src/workers/memory-worker.ts`

The Worker manages the entire search index lifecycle. The main thread never touches embeddings or index data directly.

**Message protocol** (main thread ↔ Worker):

| Direction | Message | Purpose |
|---|---|---|
| Main → Worker | `{ type: 'INIT', spaceId, encryptedBlob?, deviceTier }` | Load/decrypt index, choose search engine |
| Main → Worker | `{ type: 'INDEX_MESSAGE', message }` | Add message to in-memory index |
| Main → Worker | `{ type: 'SEARCH', query }` | Execute search against in-memory index |
| Worker → Main | `{ type: 'READY', watermark? }` | Index loaded, reports `lastIndexedMessageId` |
| Worker → Main | `{ type: 'RESULTS', matches }` | Search results |
| Worker → Main | `{ type: 'PERSIST', spaceId, blob }` | Encrypted blob for IndexedDB write |

**Lifecycle steps**:

1. **Space opened**: Main thread sends `INIT` with encrypted blob from IndexedDB. Worker decrypts blob using key derived from KeyStore via HKDF → loads index into RAM → posts `READY` with delta sync watermark (`lastIndexedMessageId`).
2. **Delta sync**: Main thread checks watermark, only sends messages newer than `lastIndexedMessageId` to Worker via `INDEX_MESSAGE`. Prevents re-indexing 1000 messages on every app open.
3. **Message decrypted** (live): Main thread sends `INDEX_MESSAGE`. Worker updates in-memory index instantly (searchable immediately). Persistence is debounced.
4. **Persistence debounce**: Worker sets a 3-second debounce timer on disk writes. Only encrypts and posts `PERSIST` once chat traffic settles. Prevents I/O thrashing during active conversations (10 messages in 5 seconds = 1 disk write, not 10).
5. **Recall query**: Main thread sends `SEARCH`. Worker runs against in-memory index → posts `RESULTS`.
6. **Space closed / tab closed**: Worker destroyed, RAM cleared. No plaintext survives.

### 4.3 Encrypted Blob Storage (Ephemeral RAM Index)

- One XChaCha20-Poly1305 encrypted blob per `space_id` in IndexedDB (`xark-memory-{spaceId}`)
- Encryption key derived from user's identity key via HKDF (already in KeyStore). Uses `crypto_secretbox_easy` / `crypto_secretbox_open_easy` from libsodium (consistent with existing `primitives.ts` — no AES-GCM, the entire crypto stack is XChaCha20-Poly1305)
- Blob contains: serialized index + message metadata (id, sender, timestamp, content snippet) + `lastIndexedMessageId` watermark
- At rest: single block of cryptographic noise. No plaintext, no inverted index, no embeddings visible.
- In RAM: decrypted and searchable only while Worker is alive
- On tab close: Worker destroyed → RAM cleared → plaintext vanishes

### 4.4 Retention: Lifecycle + Hard Cap

- **Active until space `end_date` passes**: Index stays alive while the trip is being planned. The day after `end_date`, the client auto-deletes the encrypted blob for that space, recovering storage.
- **Settled spaces**: Blob deleted on next app load. The Memories tab is the recall surface for settled trips.
- **Hard cap**: 1000 messages per space. Oldest messages evicted (FIFO) when cap hit. Guarantees predictable RAM and decrypt time.
- **No `end_date`** (open-ended spaces): Rolling 1000-message window only.

### 4.5 Recall Detection

```typescript
const RECALL_PATTERNS = [
  /what was that/i,
  /who said/i,
  /who mentioned/i,
  /remember when/i,
  /what did .+ (say|send|link|share|suggest|recommend)/i,
  /find .+ message/i,
  /when did .+ (say|send|mention)/i,
  /what .+ (link|place|hotel|restaurant|spot)/i,
  /search for/i,
  /look up/i,
];

function isRecallQuestion(text: string): boolean {
  const cleaned = text.replace(/@xark\s*/i, '').trim();
  return RECALL_PATTERNS.some(p => p.test(cleaned));
}
```

### 4.6 Tier-Aware Coaching Whisper

When `isRecallQuestion` matches but search returns zero results, the whisper copy adapts to the active search engine:

- **Lexical fail**: "couldn't find that exactly. local memory is keyword-only for now. try specific words like 'hotel' or 'marriott'."
- **Semantic fail**: "couldn't find anything matching that in our recent chat history."

Styled with `text.hint`, `ink.tertiary`. Dismisses on tap or after 5 seconds. Displayed in the context card area above ChatInput.

### 4.7 Actionable Context Card

When search returns results, a dismissible card slides up above ChatInput (same position as "replying to" preview).

**Content**:
- Matched message content (truncated to 2 lines)
- Sender name + relative timestamp (`text.timestamp`, `ink.secondary`)

**Actions**:
- **Jump to Message**: Scrolls chat to the original message, highlights with a brief cyan pulse animation
- **Quote to Group**: Loads the matched message into the composer as reply state. User can type a follow-up and send via standard E2EE. Bridges private recall → group consensus.

Dismissible via swipe-down or X tap. Zero timeline pollution — no ghost messages, no local-only bubbles.

### 4.8 Feeding the Index

Two existing decrypt sites in `space/[id]/page.tsx` feed the Worker:

1. **Batch on load** (line ~128): After E2EE messages are batch-decrypted, post each to Worker. But only messages newer than the Worker's watermark (delta sync).
2. **Realtime** (line ~237): After broadcast message is decrypted inline, post to Worker via `INDEX_MESSAGE`.

Both paths already produce plaintext — we add a single `postMessage` call to the Worker after each successful decrypt.

## 5. Tier 3 — Cloud Orchestrator Optimizations

The existing `sendMessage()` flow (E2EE → `/api/message` or legacy → `/api/xark` → Gemini) is unchanged. Messages only reach Tier 3 if they pass through Tier 1 (not admin) and Tier 2 (not recall, or recall returned no results).

### 5.1 Streaming Synthesis

Replace `generateContent` with `generateContentStream` for the final synthesis step only (intent parsing stays non-streaming — it returns structured JSON).

```
Intent Parse (JSON, non-streaming, ~2s)
        │
        ▼
Tool Execution (Apify/Gemini Search, 5-40s)
        │
        ▼
Synthesis (STREAMING → chunks via broadcast)
   "pulled" → "pulled 8 solid" → "pulled 8 solid brunch spots..."
```

**Server-side chunk batching**: Accumulate stream output and flush every ~50ms or ~10 tokens (whichever comes first). Broadcast via `supabaseAdmin.channel().send()` with event type `xark_stream_chunk`:

```typescript
{ type: 'broadcast', event: 'xark_stream_chunk', payload: {
  messageId: string,
  chunk: string,
  seq: number,    // monotonic sequence number for ordering
  done: boolean
}}
```

Client assembles chunks in `seq` order (discards out-of-order arrivals until their turn), accumulates into the @xark message content in-place until `done: true`. Reduces WebSocket frame overhead by ~90% vs per-character broadcasting.

**Important**: Streaming delivery is Realtime-channel-only (not HTTP response streaming). The `/api/message` route returns its HTTP response immediately (fire-and-forget pattern) and then `orchestrateAndUpdate()` broadcasts stream chunks asynchronously via the Realtime channel. Do not attempt `ReadableStream` / `NextResponse` streaming — the HTTP connection is already closed by the time synthesis begins.

### 5.2 Prompt Split + Conditional Context Caching

Split `buildIntentPrompt()` into:
- `buildStaticPrompt()`: Voice rules, boundaries, tool definitions, routing examples (~800 tokens, stable across all invocations)
- `buildDynamicPrompt(input)`: Space title, grounding context, recent messages, current date, user request (variable per call)

**Context Caching** activates dynamically. Gemini's Context Caching API requires a minimum of 32,768 tokens. For most spaces, the combined payload is well under this threshold.

```typescript
const totalEstimate = estimateTokens(staticPrompt + dynamicPrompt);

if (totalEstimate > 32_000 && cachedContentRef) {
  // Bundle static + grounding + old history into cache
  // Send only newest request + 2-3 recent messages as dynamic
  result = await model.generateContent({
    cachedContent: cachedContentRef.name,
    contents: [{ role: 'user', parts: [{ text: recentDynamicOnly }] }],
  });
} else {
  // Standard path — concatenate and send
  result = await model.generateContent({
    contents: [{ role: 'user', parts: [{ text: staticPrompt + dynamicPrompt }] }],
  });
}
```

Token estimation: rough heuristic at ~4 characters per token. Cache TTL: 3600s (covers a planning session).

### 5.3 Model Selection Lock

Locked to `gemini-2.5-flash` (or `gemini-3.0-flash` when available). Flash variants are optimized for high-frequency, low-latency agentic routing and structured JSON output. Add a guard:

```typescript
if (modelName.includes("pro")) {
  console.warn("[@xark] pro model detected — flash recommended for routing latency");
}
```

### 5.4 Multi-Action Parallel Execution

Extend the intent JSON schema to support an array of actions:

```typescript
// Single action (existing, backward compatible):
{ action: "search", tool: "hotel", params: {...} }

// Multi-action (new):
{ actions: [
    { action: "search", tool: "hotel", params: {...} },
    { action: "search", tool: "flight", params: {...} }
  ]
}
```

When `actions` is an array, fire all tool calls concurrently with per-tool timeouts via `Promise.allSettled`:

```typescript
const toolCalls = actions.map(a =>
  withTimeout(executeTool(a.tool, a.params), TOOL_TIMEOUT_MS)
);

const outcomes = await Promise.allSettled(toolCalls);

const succeeded: { tool: string; results: any[] }[] = [];
const timedOut: string[] = [];

outcomes.forEach((outcome, i) => {
  if (outcome.status === 'fulfilled') {
    succeeded.push({ tool: actions[i].tool, results: outcome.value });
  } else {
    timedOut.push(actions[i].tool);
  }
});
```

Synthesis prompt receives timeout context so the LLM can gracefully note missing data: "pulled the flights, but hotel search timed out. want me to try again?"

## 6. sendMessage() Integration

The complete routing logic in `space/[id]/page.tsx`:

```typescript
async function sendMessage() {
  const txt = input.trim();
  if (!txt || isThinking) return;

  const hasXark = txt.toLowerCase().includes('@xark');

  // ── TIER 1: Fast-Path Router ──
  if (hasXark) {
    const localResult = tryLocalAgent(txt, spaceId, localContext);
    if (localResult.handled) {
      setInput('');
      if (localResult.ledgerEntry) persistLedger(localResult.ledgerEntry);
      if (localResult.uiAction) localResult.uiAction();
      if (localResult.whisper) showWhisper(localResult.whisper);
      return;  // done. no network.
    }

    // ── TIER 2: E2EE Memory Engine ──
    if (isRecallQuestion(txt)) {
      const results = await searchLocalMemory(txt, spaceId);
      if (results.length > 0) {
        setInput('');
        showContextCard(results[0]);
        return;  // done. no network.
      }
      // Zero results — show tier-aware coaching whisper, preserve input for rephrasing
      showRecallWhisper(getDeviceTier());
      // NOTE: do NOT clear input here — user needs their original query text
      // to rephrase with better keywords. Input clears only on successful match.
      return;  // STRICT HALT: cloud is E2EE-blind, don't fall through
    }
  }

  // ── TIER 3: Cloud Orchestrator (existing flow unchanged) ──
  // ... E2EE encrypt → /api/message or legacy → /api/xark ...
}
```

**Critical**: When Tier 2 matches a recall question but returns zero results, we show the coaching whisper and **stop**. We do not fall through to Tier 3. The cloud orchestrator is E2EE-blind and would produce a hallucinated response.

## 7. New Files

| File | Purpose |
|---|---|
| `src/lib/local-agent.ts` | Tier 1 fast-path router. `tryLocalAgent()`, command registry, regex patterns |
| `src/app/api/local-action/route.ts` | Tier 1 mutation endpoint. JWT-validated, supabaseAdmin writes. Atomic: mutation + ledger entry. Upserts `space_dates` for date commands. |
| `src/lib/local-recall.ts` | Tier 2 recall detection. `isRecallQuestion()`, `searchLocalMemory()` wrapper communicating with Worker |
| `src/workers/memory-worker.ts` | Web Worker. In-memory search index, encrypted blob lifecycle, debounced persistence, delta sync watermark |
| `src/hooks/useLocalMemory.ts` | React hook. Initializes Worker on space open, postMessage/onmessage bridge, exposes `search()` and `indexMessage()` |
| `src/components/os/ContextCard.tsx` | Actionable context card. Jump to Message + Quote to Group |
| `src/components/os/LedgerPill.tsx` | Interactive system pill for space_ledger events. Icon + actor + verb + [tappable payload] + undo |
| `supabase/migrations/016_hybrid_brain.sql` | `space_ledger` table, RLS, Realtime publication, indexes |

## 8. Modified Files

| File | Change |
|---|---|
| `src/app/space/[id]/page.tsx` | Tier 1/2/3 routing in `sendMessage()`, Worker init via `useLocalMemory`, ledger Realtime subscription, context card state, feed decrypted messages to Worker |
| `src/components/os/XarkChat.tsx` | Interleave ledger pills in timeline, streaming chunk accumulation for @xark messages |
| `src/lib/intelligence/orchestrator.ts` | `buildStaticPrompt()` / `buildDynamicPrompt()` split, streaming synthesis via `generateContentStream`, multi-action support, `Promise.allSettled` with per-tool timeouts, conditional context caching |
| `src/app/api/message/route.ts` | Stream chunk broadcast (`xark_stream_chunk` event), chunk batching (50ms / 10 tokens) |
| `src/app/api/xark/route.ts` | Same streaming + caching changes |
| `src/lib/intelligence/tool-registry.ts` | Multi-action schema documentation |

## 9. Build Sequence

Phased delivery, each phase independently shippable:

### Phase 1 — Tier 1: Fast-Path Router (1 session)
- `local-agent.ts` with command registry (dates, rename, state queries, navigation)
- `/api/local-action` server route (JWT-validated, supabaseAdmin mutations, atomic ledger write)
- `space_ledger` table + migration 016 (includes `STABLE` guard on `auth_user_space_ids()`)
- `LedgerPill.tsx` component (with `revert_target_id` for Undo linkage)
- Ledger Realtime subscription in Space page
- Wire `tryLocalAgent()` into `sendMessage()` as first gate
- Date mutations upsert both `spaces.metadata` AND `space_dates` (downstream: purge TTL, Tier 2 retention, computeSpaceState)
- **Ships**: Admin commands resolve in <1ms. Audit trail visible to all group members.

### Phase 2 — Tier 2: Lexical Memory (1 session)
- `memory-worker.ts` with FlexSearch/MiniSearch (all devices get lexical first)
- Encrypted blob lifecycle (XChaCha20-Poly1305 via libsodium `crypto_secretbox`, debounced persistence, delta sync watermark)
- `useLocalMemory.ts` hook
- `local-recall.ts` with `isRecallQuestion()` detection
- `ContextCard.tsx` with Jump to Message + Quote to Group
- Feed decrypted messages to Worker from batch and Realtime paths
- Tier-aware coaching whisper (lexical vs semantic copy)
- Lifecycle retention (space `end_date` cleanup, 1000-message hard cap)
- **Ships**: Keyword recall works on all devices. Index encrypted at rest. True zero-knowledge.

### Phase 3 — Tier 2 Upgrade: Semantic Search (1 session)
- transformers.js integration in Worker (high-tier devices only)
- all-MiniLM-L6-v2 quantized ONNX model loading + ServiceWorker caching
- Embedding generation pipeline alongside lexical index
- Cosine similarity search for semantic queries
- Algorithmic degradation gate via `useDeviceTier`
- **Ships**: High-tier devices get contextual recall ("where are we staying?" → "I booked the Marriott"). Low-tier unchanged.

### Phase 4 — Tier 3: Cloud Optimizations (1 session)
- Streaming synthesis (`generateContentStream` + batched chunk broadcast at 50ms/10 tokens)
- `buildStaticPrompt()` / `buildDynamicPrompt()` split
- Conditional context caching (activates when estimated payload exceeds 33K tokens — buffered above 32,768 API minimum)
- Multi-action intent schema + `Promise.allSettled` with per-tool timeouts
- Flash model guard
- **Ships**: Perceived latency drops dramatically for cloud queries. Multi-tool requests execute concurrently.

## 10. Security Considerations

- **Tier 1**: `space_ledger` is Layer 3 (unencrypted). Admin actions mutate shared state that is already unencrypted (space metadata). No E2EE violation. RLS enforces `actor_id = auth.jwt()->>'sub'` to prevent spoofing.
- **Tier 2**: The local index is encrypted at rest (XChaCha20-Poly1305 blob in IndexedDB, consistent with the rest of the crypto stack). Plaintext exists only in Worker RAM while the app is active. Tab close = Worker death = RAM cleared. No plaintext survives on disk. Key derived from identity key via HKDF.
- **Tier 2 recall**: Search results appear only on the querying user's device (actionable context card). They are never broadcast or persisted. "Quote to Group" re-enters the standard E2EE send path.
- **Tier 3**: No changes to E2EE guarantees. Streaming synthesis is still server-side Gemini output — same trust boundary as existing flow.
- **Embedding security**: On high-tier devices, embeddings are stored inside the encrypted blob alongside the lexical index. They are never exposed at rest. Research shows embeddings can be approximately inverted (Vec2Text), but they never leave the encrypted blob boundary.

## 11. Implementation Edge Cases

### 11.1 Tier 1 API Security: Membership Verification

`/api/local-action` uses `supabaseAdmin` (service role, bypasses RLS). Because this gives god-mode DB access, the route **must** verify space membership before executing any mutation:

```typescript
// BEFORE any mutation:
const { data: member } = await supabaseAdmin
  .from('space_members')
  .select('id')
  .eq('space_id', spaceId)
  .eq('user_id', jwtSub)
  .single();

if (!member) return NextResponse.json({ error: 'not a member' }, { status: 403 });
```

This is the equivalent of RLS enforcement at the application layer. Without it, any authenticated user could mutate any space.

### 11.2 Tier 2 Memory Guard: Per-Message Truncation

The 1000-message hard cap controls message count, but not message size. Users occasionally paste massive text walls, URLs, or base64 data. Without a size guard, a few oversized messages could bloat Worker RAM on low-tier devices.

**Fix**: Truncate message text to 2000 characters before sending to the Worker via `INDEX_MESSAGE`. This keeps the index focused on searchable content while bounding per-message memory at ~4KB (2000 chars × 2 bytes UTF-16).

```typescript
// In useLocalMemory.ts, before postMessage to Worker:
const truncated = message.content.slice(0, 2000);
worker.postMessage({ type: 'INDEX_MESSAGE', message: { ...message, content: truncated } });
```

### 11.3 Context Caching Threshold Buffer

The Gemini Context Caching API rejects payloads under 32,768 tokens. The client-side token estimator uses a ~4 chars/token heuristic, which is inexact. An estimate of 32,100 could evaluate to 31,900 actual tokens, causing an API rejection.

**Fix**: Use a buffered trigger threshold of 33,000 estimated tokens (not 32,000). This absorbs estimation error and ensures the actual token count clears the API minimum.

```typescript
const CACHE_TRIGGER_THRESHOLD = 33_000; // buffered above 32,768 API minimum

if (totalEstimate > CACHE_TRIGGER_THRESHOLD && cachedContentRef) {
  // Safe to create/use cache
}
```
