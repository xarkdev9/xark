To build the "next big thing" in messaging—an app that rivals the speed of WhatsApp and the security of Signal—hand this exact 50-task checklist to your engineering team.

Phase 1: PostgreSQL Hardening & Database Primitives (The Fortress)
[ ] 1. Client-Generated UUIDv7: Implement UUIDv7 generation in Dart. Use this as the primary key in local SQLite and the idempotency key for backend RPCs to survive network retries.

[ ] 2. Idempotent Message RPC: Rewrite send_e2ee_message to use ON CONFLICT (idempotency_key) DO NOTHING. Drop the server-side ID generation.

[ ] 3. Partition Unique Constraints: Fix the message_ciphertexts migration. PostgreSQL requires the partition key to be included: UNIQUE (message_id, recipient_id, recipient_device_id, created_at).

[ ] 4. UUIDv7 Partition Pruning: Write a Postgres helper to extract the timestamp from the UUIDv7 message_id. Inject AND created_at = extract_time_from_uuidv7(p_message_id) into all ciphertext queries to guarantee sub-millisecond single-partition index scans (avoiding CPU-melting full table scans).

[ ] 5. Eradicate Unread Count Deadlocks: Remove the synchronous UPDATE unread_counts from the send_e2ee_message RPC. Row-level locks on a hot path will cause massive deadlocks in group chats.

[ ] 6. Asynchronous Unread Counters: Calculate unread counts locally on the Flutter client by querying Drift for messages newer than the last_read_watermark.

[ ] 7. Sequence Scoping: Scope the server_seq to the group_id (e.g., MAX(server_seq) + 1 WHERE group_id = p_group_id). Global auto-incrementing sequences bottleneck the entire database.

[ ] 8. Cryptographic Tombstoning: Add message_type = 'tombstone'. When a user deletes a message, overwrite the type and wipe the ciphertexts, but keep the server_seq intact so offline devices can sync the deletion gap.

[ ] 9. TCP Connection Pooling (postgres.js): Drop the Supabase JS client (which uses HTTP) for the /api/message hot-path. Connect directly to Supavisor (Port 6543) via TCP using postgres.js to strip 30–50ms of HTTP latency per message.

[ ] 10. Cursor-Based Pagination: Update the MessageGateway interface from sinceSeq: number to cursor: string. This decouples the API from Postgres sequences, allowing future extraction to DynamoDB or ScyllaDB.

Phase 2: Edge Infrastructure & API Gateway (The Shield)
[ ] 11. True Edge Rate Limiting: Move @upstash/ratelimit out of API routes and into Next.js middleware.ts. Malicious traffic must be blocked at the Vercel Edge (<5ms) before spinning up a billed serverless function.

[ ] 12. Token Bucket Outbox Limits: Change the /api/message rate limit to a Token Bucket algorithm with high burst capacity (e.g., 200). A strict sliding window will falsely block users whose offline outboxes sync a burst of messages after a flight.

[ ] 13. Rate Limiter Fail-Open: Wrap Upstash Redis calls in a 1000ms timeout try/catch. If Redis goes down, log to Sentry and fail open (allow the message). Do not let a rate-limiter outage take down core messaging.

[ ] 14. Device Attestation (AppCheck): IP-based rate limiting (auth:{ip}) is useless against SMS toll fraud. Implement Firebase AppCheck (Play Integrity / DeviceCheck) on /api/phone-auth to mathematically prove requests come from untampered physical phones.

[ ] 15. JWT Replay Protection: Add a jti (JWT ID) check to critical mutation routes, stored in Redis with a short TTL, to prevent token replay attacks.

[ ] 16. Edge Cache with SETNX: For Key Bundles, use a 5-minute TTL in Redis and use SETNX (Set if Not Exists) to prevent race conditions where a stale key overwrites a fresh key during concurrent fetches.

[ ] 17. The "X-Bypass-Cache" Escape Hatch: If the Flutter client fails to decrypt a message due to a bad signature, it must retry the key fetch with an X-Bypass-Cache: true HTTP header to force a direct Postgres read and self-heal the Redis cache.

Phase 3: Cryptography & Identity (The Vault)
[ ] 18. Sender Key Request (NACK) Protocol: The server's sk_acknowledgments table cannot be trusted if a user reinstalls the app (losing local keys). Implement a silent SenderKeyRequest payload that automatically fires when a device receives a Sender Key it cannot decrypt.

[ ] 19. Sender Key Response Handler: Upon receiving a NACK, the sender's device silently replies with a 1-to-1 encrypted message containing only the missing SK distribution.

[ ] 20. Local-Only SK Distribution Checks: The client's SQLite (Drift) database must be the absolute source of truth for SK ACKs. Do not await a network call to Postgres to check ACKs before encrypting. Offline messaging requires offline encryption.

[ ] 21. Implicit SK ACKs: If Alice sends a message, and Bob replies to the group, Bob's reply mathematically proves he has the Sender Key. Alice's device should implicitly mark Bob as "ACKed" in Drift without requiring an explicit ACK payload.

[ ] 22. Hardware-Backed Root Keys: Move Identity Keys out of standard device storage. Bind them exclusively to the iOS Secure Enclave and Android Keystore using flutter_secure_storage.

[ ] 23. Multi-Device Sesame Protocol: Implement fan-out encryption so a user's iPhone and Web App act as distinct cryptographic devices. This allows seamless history sync without sharing private keys across networks.

[ ] 24. Post-Quantum KEM (Kyber): Future-proof against "Harvest Now, Decrypt Later" quantum attacks by integrating the NIST-approved Kyber-1024 Key Encapsulation Mechanism alongside existing X25519 DH keys.

[ ] 25. WebLocks Deadlock Protection: In the Next.js client, wrap navigator.locks.request in an AbortController with a 5-second timeout. If a browser tab crashes mid-encryption, the timeout forcefully releases the Web Lock.

Phase 4: Offline-First Mobile Engine (The Engine)
[ ] 26. Drift-Driven UI: The Flutter UI must never await a network call. All components must render purely from local Drift SQLite streams (watch()) with 0ms delay. The network syncs the DB; the DB drives the UI.

[ ] 27. Strict Outbox Sequencing: Ensure background workers drain the local outbox to the server strictly serially for the same group_id. Concurrent outbox sending will scramble Double Ratchet chain indices.

[ ] 28. Watermark Gap Sync: Track last_received_server_seq. Upon app foregrounding, fetch messages > watermark, dump them into the local DB, and let Riverpod reactively update the UI.

[ ] 29. Dart Crypto Isolate NameServer: Extract cryptography into a background isolate. Register it via IsolateNameServer so headless background push notifications can find it and pass decryption requests without booting the UI.

[ ] 30. Zero-Copy Memory (TransferableTypedData): Require the use of TransferableTypedData when passing large media Uint8List payloads to the Crypto Isolate. Standard passing duplicates RAM, causing Out-Of-Memory (OOM) crashes on 4K videos.

[ ] 31. Isolate Watchdog & Respawn: Wrap SendPort requests in a 10-second timeout. If the isolate OOMs or crashes due to an FFI panic, the main thread must kill it, respawn it, reload Drift ratchet state, and retry.

[ ] 32. Headless Push Decryption: Standard FCM shows encrypted gibberish on the lock screen. Implement iOS NotificationServiceExtension and Android BroadcastReceiver to wake the headless isolate, decrypt the E2EE payload, and show plaintext local notifications.

[ ] 33. Realtime Delivery Receipts: Pipe "Delivered" and "Read" ticks exclusively through Supabase Presence/Broadcast channels. The database should never process millions of receipt rows.

[ ] 34. Background Media Uploads: Use WorkManager / BGTaskScheduler to ensure encrypted media chunks continue uploading even if the user force-quits the app.

[ ] 35. Streaming AES-GCM: Do not load large video files into RAM. Implement chunked AES-256-GCM encryption that reads from disk and writes directly to the network in 64KB chunks.

Phase 5: World-Class UI/UX Polish (The Apple Standard)
[ ] 36. Frame-Perfect Keyboard Intrusion: Implement custom WindowInsets handling. The chat input must be physically bound to the OS keyboard pixel-for-pixel as it slides up at 120hz, avoiding standard Flutter jank.

[ ] 37. Virtualized Reverse Scroll: Build a custom SliverList(reverse: true) that recycles widget trees and calculates dynamic heights instantly, allowing smooth 120fps scrolling through 100,000+ local messages.

[ ] 38. Parameterized Spring Physics: Replace all linear Flutter animations (Curves.easeOut) with Spring Physics (mass, stiffness, damping) so swiping a message feels tactile, weighty, and snaps back with realistic momentum.

[ ] 39. BlurHash E2EE Injection: Calculate a base64 BlurHash of an image before encrypting it. Send it in the plaintext envelope metadata to instantly show a beautiful placeholder while the encrypted payload downloads.

[ ] 40. Client-Side Link Unfurling: E2EE apps cannot let servers scrape links. The client must call a blind proxy (/api/proxy-scrape), download the OpenGraph data, encrypt it locally, and send it as part of the E2EE payload.

[ ] 41. Interactive Lock-Screen Actions: Allow users to vote on a decision directly from the OS notification banner. The background isolate decrypts the choices, registers the vote, and updates local Drift.

[ ] 42. Ephemeral Typing Indicators: Render typing indicators via Realtime broadcast. They must auto-clear after 5 seconds to prevent "ghost typing" if a user's network drops.

Phase 6: AI, Intelligence, & Anti-Abuse (The Moat)
[ ] 43. Server-Sent Events (SSE) AI: Stream @xark AI responses via SSE to show real-time typing in the UI. Do not hold HTTP connections open for 40 seconds.

[ ] 44. Async AI Worker Queue: Move heavy Apify scraping tasks to an async queue (Inngest or Temporal). Return a 202 Accepted to the client instantly.

[ ] 45. On-Device SLMs (Apple Neural Engine): Deploy quantized open-source SLMs (e.g., Llama-3-8B-Mobile) directly to the phone via CoreML/NNAPI to detect constraints (diet/budget) instantly and privately, saving massive Gemini API costs.

[ ] 46. Taste Graph Mathematical Intersection: Before hitting the LLM, mathematically intersect the JSON taste profiles of only the active space members, applying strict constraints before generating prompts.

[ ] 47. Cryptographic Message Franking: Implement a reporting system where a user securely unwraps the encryption key for one specific spam message and sends it to the moderation server, preserving E2EE for the rest of the chat.

[ ] 48. Client-Side E2EE Observability: Integrate Sentry strictly to catch client-side Double Ratchet decryption exceptions. Server HTTP 200s are blind to E2EE failures.

[ ] 49. Private Contact Discovery (PSI): Use Private Set Intersection or Hash Enclaves so users can find friends' phone numbers without you storing their social graph in plaintext.

[ ] 50. Blind Storage Security Rules: Configure Firebase Storage rules to mathematically prove the downloader's JWT sub belongs to the space_id of the encrypted blob they are trying to access.