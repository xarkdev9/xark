To build a "planet-scale" platform (1 million to 1 billion users) that genuinely competes with the engineering marvels of WhatsApp, Telegram, and Signal, you must completely abandon the traditional "CRUD web app" mindset. 

Because your app is **End-to-End Encrypted (E2EE)** and heavily features real-time collaborative algorithms, the client device is effectively your server. The backend must be treated merely as a dumb, high-speed relay and storage pipe.

Here is your master engineering playbook. It ignores timelines and focuses purely on **expert-level execution**. This is the definitive, 42-step technical blueprint to make this app the next big thing in messaging.

---

### PHASE 1: Military-Grade Cryptography & E2EE (The Signal Standard)
*If the cryptography drops state, corrupts, or leaks metadata, the app dies. These are the non-negotiable foundations.*

*   [ ] **CRYPTO-01: Build the Native X3DH Responder.** Write the missing `fe2ee` Dart logic to natively accept an Initial Message from a peer, calculate the shared secret via 4-DH (validating the One-Time Pre-Key), and initialize the receiving Double Ratchet chain.
*   [ ] **CRYPTO-02: Hardware-Backed Key Storage.** Move `IdentityKeyPair` and `SenderKeys` out of standard standard device storage/RAM. Bind them directly to the iOS Secure Enclave and Android Keystore using `flutter_secure_storage`.
*   [ ] **CRYPTO-03: Headless Background Push Decryption.** Standard Firebase Cloud Messaging (FCM) will show encrypted gibberish on the lock screen. Implement iOS `NotificationServiceExtension` and an Android `BroadcastReceiver`. When a silent push arrives, wake a headless Dart isolate, decrypt the payload using the Secure Enclave, and render the plaintext local notification.
*   [ ] **CRYPTO-04: O(1) Sender Key Distribution Engine.** Stop generating pairwise encryptions for every user on every group message (which melts the DB at scale). Build a local caching layer tracking `acknowledged_sk_distributions`. Only attach the heavy Sender Key payload to a message when a new device joins or a key epoch rotates.
*   [ ] **CRYPTO-05: Cross-Isolate Mutex Locks.** Implement OS-level Mutexes in Dart and the Web Locks API in the browser to guarantee that simultaneous foreground UI actions and background sync workers never consume the same Double Ratchet chain index (which permanently bricks the chat).
*   [ ] **CRYPTO-06: Signal's Sesame Protocol (Multi-Device).** Treat every user device (Phone, iPad, Web) as a distinct cryptographic entity. Implement fan-out encryption to a user's linked devices so chat histories sync seamlessly without sharing root keys across networks.
*   [ ] **CRYPTO-07: Streaming AEAD Media Encryption.** Do not load 100MB 4K videos into device RAM. Implement chunked, streaming AES-256-GCM encryption/decryption that reads from disk and writes directly to the network in 64KB blocks to prevent Out-Of-Memory (OOM) crashes on older Androids.
*   [ ] **CRYPTO-08: Post-Quantum Cryptography (PQXDH).** Future-proof against "Harvest Now, Decrypt Later" quantum computing attacks. Bundle the NIST-approved Kyber-1024 Key Encapsulation Mechanism (KEM) alongside your existing X25519 DH keys.

### PHASE 2: Offline-First Mobile Architecture (The WhatsApp Engine)
*A planet-scale app must open in 50 milliseconds and work perfectly inside a concrete subway tunnel with zero internet.*

*   [ ] **MOBILE-01: Pure Local-First UI (Drift).** The mobile UI must **never** `await` a network call to render a screen. Build a normalized SQLite schema using `drift` in Flutter. The Galaxy page, Space lists, and Chat feeds must render entirely from the local disk in <16ms.
*   [ ] **MOBILE-02: Watermark-Based Gap Sync.** When the app regains connection, it tracks a `last_sync_watermark`. It queries the server for `messages WHERE created_at > watermark`, feeds the blobs into a background decryption queue, and silently patches the local Drift tables.
*   [ ] **MOBILE-03: Optimistic UI & Persistent Outbox.** Every user action (send, vote, lock) writes to a local SQLite `outbox` table first. The UI updates instantly. A background worker drains the outbox to the server with exponential backoff (2s, 4s, 8s, 16s) if the network fails.
*   [ ] **MOBILE-04: CRDT-Based Consensus Engine.** Replace synchronous server-side RPC locks with Conflict-Free Replicated Data Types (CRDTs) like Automerge or Yjs. This allows two offline users on an airplane to vote simultaneously, mathematically merging their states without conflicts when they reconnect.
*   [ ] **MOBILE-05: Resumable Background Media Uploads.** Use OS-level background task schedulers (`WorkManager` / `BGTaskScheduler`) to upload encrypted media chunks even if the user force-closes the app.
*   [ ] **MOBILE-06: Background Sync Coordinator.** Build an isolate that listens to Supabase Realtime, calculates diffs, writes to Drift, and streams reactive updates to the UI via Riverpod `watch` streams.

### PHASE 3: Planet-Scale Backend Infrastructure (The Relay)
*When you hit 100,000 concurrent users, serverless Next.js functions and Postgres connections will bottleneck. This is how you swap the engines mid-flight.*

*   [ ] **BACKEND-01: Atomic PostgreSQL E2EE Transactions.** Wrap the `/api/message` route's 4-step database inserts (membership check, message insert, ciphertexts insert, SK distribution) into a single PostgreSQL RPC function with `BEGIN/COMMIT` to prevent ghost messages during Vercel cold-start crashes.
*   [ ] **BACKEND-02: Supavisor Connection Pooling.** Switch all serverless database connections to use Supabase's port 6543 (Supavisor). Vercel functions spin up thousands of micro-connections; without pooling, your DB will exhaust memory instantly under load.
*   [ ] **BACKEND-03: Global Edge Rate Limiting.** Strip the in-memory Postgres rate limiter. Implement `@upstash/ratelimit` globally at the Next.js Edge to protect the DB from DDoS and brute-force key-fetching attacks across all serverless instances.
*   [ ] **BACKEND-04: Edge-Cache Public Key Bundles.** Public key bundles are immutable once uploaded. Serve `/api/keys/fetch` from a global Edge CDN (Cloudflare or Vercel Edge Config) to eliminate massive DB read loads when users start new chats.
*   [ ] **BACKEND-05: Partition the `message_ciphertexts` Table.** Because E2EE fans out (1 message in a 10-person group = 10 ciphertexts), this table will hit 1 billion rows rapidly. Implement PostgreSQL Native Partitioning, splitting it by `created_at` (monthly) to maintain sub-millisecond index scans.
*   [ ] **BACKEND-06: Decouple the WebSocket Gateway.** Eventually, Supabase Realtime will limit out. Deploy a dedicated edge tier of Erlang/Elixir (BEAM) or Go servers explicitly built to hold millions of persistent, lightweight WebSocket connections, mapping them via Redis.
*   [ ] **BACKEND-07: The Transient Message Queue.** Implement a Redis or ScyllaDB transient queue. Messages for offline users sit here. The millisecond the user's device sends a "Delivered" ACK, the encrypted blob is hard-deleted from your servers to save petabytes of permanent storage.
*   [ ] **BACKEND-08: Strangler Fig API Extraction.** For the absolute hottest paths (`/api/message`), extract them from Next.js into high-performance Rust or Go microservices. Route traffic via an API Gateway, scaling from 1% to 100% with zero downtime.

### PHASE 4: World-Class UI/UX Polish (The Apple Standard)
*Users do not care about your cryptography; they care about how the app feels. It must rival the fluidity of iMessage and Telegram.*

*   [ ] **UX-01: Frame-Perfect Keyboard Intrusion.** Standard Flutter UI shifts jankily when the OS keyboard opens. Implement custom `WindowInsets` handling so the message input box is physically attached to the top of the keyboard pixel-for-pixel as it slides up at 120hz.
*   [ ] **UX-02: Virtualized Reverse-Scrolling Chat Trees.** Implement a custom `CustomScrollView` with `SliverList(reverse: true)` that pre-renders off-screen chat bubbles, re-uses widget trees, and calculates dynamic heights instantly, allowing smooth scrolling through 100,000+ local messages without dropping a frame.
*   [ ] **UX-03: Gesture-Driven Spring Physics.** Replace all linear Flutter animations with parameterized Spring Physics (mass, stiffness, damping). Swiping a message to reply, or dragging an `ActionCard`, must feel weighty, tactile, and snap back with realistic momentum.
*   [ ] **UX-04: BlurHash Injection.** Calculate a tiny base64 "BlurHash" string on the client *before* encrypting an image. Send it in the unencrypted metadata. The UI instantly shows a beautiful blurred placeholder while the heavy encrypted payload downloads in the background.
*   [ ] **UX-05: E2EE-Safe Link Previews.** You cannot send URLs to a server to scrape metadata (it breaks E2EE). When a user types a URL, their device blindly calls `/api/proxy-scrape`, downloads the OpenGraph image/title, encrypts it locally, and sends it as part of the E2EE payload.
*   [ ] **UX-06: Interactive Lock-Screen Notifications.** Allow users to vote on a decision directly from the OS notification banner. The background isolate decrypts the choices, shows "Love it" / "Not for me" buttons, registers the vote via background network request, and updates local Drift.
*   [ ] **UX-07: Ephemeral Real-Time Typing Indicators.** Never write typing indicators to Postgres. Use Realtime `Presence` channels to transmit transient "User is typing..." signals. Render these with fluid fade-in/fade-out animations that auto-clear after 5 seconds.

### PHASE 5: The Algorithmic & AI Moat (The Brains)
*Your decision engine and AI (@hello) are your moat. They must run fast, accurately, and cost-efficiently.*

*   [ ] **ALGO-01: Strict Type-Safe Porting of Algorithms.** Translate the TS `algo` package (Heart-Sort, State Machine, Settlement Math) to Dart using the `freezed` package. This enforces compile-time safety, replacing TS string unions with exhaustive sealed classes.
*   [ ] **ALGO-02: 1:1 Unit Test Replication.** You **must** port all 198 TS Jest tests to Dart `flutter_test` in the exact same PR. Financial settlement math (Venmo splits) and consensus thresholds (0.8 agreement) must pass identical test vectors across Web and Mobile.
*   [ ] **ALGO-03: Streaming AI Responses (SSE).** Do not hold HTTP requests open for 50 seconds while Apify/Gemini run. Implement Server-Sent Events (SSE) to stream the `@hello` AI text chunks directly to the Flutter client, showing real-time "typing".
*   [ ] **ALGO-04: Async AI Worker Queue.** Move the `@hello` AI orchestrator off the synchronous hot-path. The API should return `202 Accepted` instantly, push the task to Temporal.io or Inngest, and let background workers handle the heavy scraping.
*   [ ] **ALGO-05: On-Device Small Language Models (SLMs).** Deploy quantized open-source SLMs (like Llama-3-8B-Mobile) via CoreML/NNAPI directly to the user's phone. Run constraint detection (diet/budget) locally and instantly, saving millions in server-side LLM API costs.
*   [ ] **ALGO-06: Taste Graph Mathematical Intersection.** Enhance the AI prompt generation. When @hello is queried, mathematically intersect the structured JSON taste profiles of *only the active space members*, applying strict `user_constraints` filters before hitting the LLM.

### PHASE 6: Security, Anti-Abuse & Observability (Zero Trust)
*At scale, you will be targeted by state-level actors, spammers, and malicious users. Assume breach.*

*   [ ] **SEC-01: Purge and Rotate All Secrets.** Scrub `.env.local` from your Git history using `git filter-repo`. Rotate Supabase Service Role, Firebase, and Gemini keys immediately. Move to Vercel Vault or AWS Secrets Manager.
*   [ ] **SEC-02: Zero-Trust RPC Lockdown.** Run `REVOKE EXECUTE FROM PUBLIC` on all sensitive RPCs (`insert_system_message`, `get_push_tokens`). Grant execution access *only* via strict RLS wrappers to the `service_role` or `authenticated` role.
*   [ ] **SEC-03: Cryptographic Message Franking (Spam Reporting).** Because the app is E2EE, you cannot read spam. Implement Message Franking: when a user reports a message, the client securely un-wraps that specific message's encryption key and sends it to the server along with the ciphertext, allowing moderators to decrypt *only* the reported message.
*   [ ] **SEC-04: Client-Side E2EE Observability.** Server metrics look fine if a message decrypt fails (the server just delivered a blob). Implement Sentry strictly to catch *client-side* Double Ratchet exceptions, Decryption failures, and OS-level Out-of-Memory errors.
*   [ ] **SEC-05: Private Contact Discovery (Zero-Knowledge).** Never upload raw address books to find friends. Use truncated hash prefix matching (like Signal's SGX approach) or Private Set Intersection (PSI) so users can find contacts without you storing their social graph. 
*   [ ] **SEC-06: Blind Storage Security Rules.** Configure Firebase Storage rules so that E2EE encrypted media blobs can only be downloaded by authenticated users who are cryptographically verified members of the corresponding `space_id`.