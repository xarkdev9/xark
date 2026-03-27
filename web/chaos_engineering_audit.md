# XARK OS: Distributed Systems & Chaos Engineering Audit

**Target Scope**: E2EE Cryptographic State Machine, Supabase Realtime Concurrency
**Perspective**: Chaos Engineering & High-Load Network Simulation

---

## 1. THE MELTDOWN VECTOR (P0/P1)
Your architecture relies on Supabase Realtime Broadcast channels + Vercel edge functions. When exposed to a "Thundering Herd" of 500 users jumping into a space, the infrastructure tears itself apart across multiple axes.

### P0 — The Edge Function Connection Pool Collapse
**Location:** [src/app/api/message/route.ts](file:///Users/ramchitturi/xark9/src/app/api/message/route.ts) & [src/lib/supabase-admin.ts](file:///Users/ramchitturi/xark9/src/lib/supabase-admin.ts)
**The Meltdown:**
Next.js API routes deploy to Vercel/AWS Lambda as isolated, ephemeral edge functions. When 500 users simultaneously send a message, Vercel spins up 500 independent Lambda instances. Each instance initializes its own `supabaseAdmin` client and requests a direct Postgres connection. 
Standard Postgres handles ~100 concurrent connections. The 500 Lambda instances instantly exhaust the Postgres connection pool, causing a massive `FATAL: remaining connection slots are reserved` cascade. Every subsequent `/api/*` call 503s. 
*Note: This specific meltdown happens because you are missing a PgBouncer/Supavisor transaction-pooling URL in your `SUPABASE_SERVICE_ROLE_KEY` setup.*

### P1 — The Payload Bloat (Non-Issue, Good Design)
**Location:** [src/lib/crypto/encryption-service.ts](file:///Users/ramchitturi/xark9/src/lib/crypto/encryption-service.ts) (Lines 260-320)
**The Verdict:** Your Sender Key distribution code is actually resilient to OOM crashes. You correctly chunk the symmetric encryption loops (`const CHUNK_SIZE = 10;`) and explicitly yield to the browser's Macrotask queue (`await new Promise(r => setTimeout(r, 0));`). Even for 500 users, the 200KB base64 array comfortably fits inside Vercel's 4.5MB POST payload limit without freezing the DOM. 

---

## 2. CRYPTOGRAPHIC DESYNC RISKS (P1)
Your cryptographic primitives are textbook, and your skipped-key out-of-order handling is technically correct ([src/lib/crypto/double-ratchet.ts](file:///Users/ramchitturi/xark9/src/lib/crypto/double-ratchet.ts)). However, your application layer implementation permanently destroys the state under high concurrency.

### P1 — The Decryption Race Condition (State Overwrite)
**Location:** [src/lib/crypto/encryption-service.ts](file:///Users/ramchitturi/xark9/src/lib/crypto/encryption-service.ts) ([decryptMessage](file:///Users/ramchitturi/xark9/src/lib/crypto/encryption-service.ts#702-853) Lines 700-850)
**The Desync:**
You correctly implemented [withEncryptLock()](file:///Users/ramchitturi/xark9/src/lib/crypto/encryption-service.ts#51-65) to prevent race conditions when *sending* messages. You completely failed to implement a mutex lock when *receiving* messages.

When 50 incoming messages arrive instantly via Supabase Realtime Broadcast (`src/lib/messages.ts:152`), the browser fires the `onMessage` event 50 times in the exact same JS Tick/Macrotask stream. This triggers 50 parallel asynchronous executions of [decryptMessage()](file:///Users/ramchitturi/xark9/src/lib/crypto/encryption-service.ts#702-853).

1. All 50 threads call `await keyStore.getSenderKey(...)` and read the *exact same* baseline cryptographic state from IndexedDB into memory.
2. All 50 threads call [senderKeyDecrypt(...)](file:///Users/ramchitturi/xark9/src/lib/crypto/sender-keys.ts#56-115), which advances the in-memory Ratchet Chain.
3. All 50 threads attempt to write their divergent, newly-advanced Ratchet States back to IndexedDB via `await keyStore.saveSenderKey(...)`.

**The Consequence:** The last asynchronous thread to finish writing "wins". The intermediate 49 chain keys are permanently overwritten and lost. When the next mathematically sequential message arrives, the client no longer possesses the correct chain key to derive the AES Message Key. The Double Ratchet is irreversibly bricked. The client will forever display `[invalid message]` or `[decryption pending]`.

---

## 3. THE SCALING CEILING
This codebase cannot safely exceed **1 Message Per Second (MPS) per receiving client** without encountering the Cryptographic Desync race condition. If standard group chat behavior (e.g., 5 people typing "lol" simultaneously) occurs, the clients will brick their Ratchets. 

From an infrastructure perspective, the hard ceiling is your Supabase Postgres connection pool. Without Supavisor bridging Vercel to Postgres, you cannot exceed **~80-100 concurrent writers** before the database strictly denies connections.

---

## 4. THE INTERROGATION
*(Technical Repercussions You Must Address)*
1. **The Decryption Queue:** Will you implement an asynchronous sequential queue (e.g., a `p-queue` or another `withDecryptLock` mutex) wrapper around [decryptMessage](file:///Users/ramchitturi/xark9/src/lib/crypto/encryption-service.ts#702-853) so that Ratchet advance operations block each other?
2. **Connection Pooling Strategy:** Are you using Supabase IPv4 connection pooling (Supavisor Session mode `port 6543`) for your Next.js API environment variables, or are you utilizing the direct `port 5432` URL?
3. **Broadcast Delivery Guarantees:** Supabase Broadcast uses standard WebSockets (`self: false`). It does not guarantee at-least-once delivery. If a user's Wi-Fi drops for 2 seconds, they miss the Broadcast. Your code relies on paginated REST queries to fill the gap, but do you have an active reconciliation loop that syncs missing Ciphertexts, or do missed Broadcasts remain permanently hidden until a hard refresh?
