Phase 1: Cryptographic Bedrock (The Keys)
Goal: Establish non-extractable identity keys and fix OTK exhaustion.

Task 1.1: WebCrypto Migration (Fixes P0-1 & BUG 2)

Action: Rewrite identity key generation using crypto.subtle.generateKey (extractable: false). Update getDeviceId() to a 0-999999 range.

Validation: In DevTools -> IndexedDB, identity_key MUST be an opaque CryptoKey object, not a base64 string. Exporting it via console must throw a DOMException.

Task 1.2: OTK Lifecycle Management (Fixes BUG 3 & BUG 19)

Action: Update fetch_key_bundle. Client MUST call keyStore.deleteOneTimePreKey() immediately after consuming an OTK. replenishOTKsIfNeeded() must query the server via /api/keys/otk.

Validation: Establish a 1:1 session. The consumed OTK must vanish from local IndexedDB.

Task 1.3: Fix X3DH Ephemeral Key (Fixes FATAL BUG 11 & BUG 13)

Action: In x3dhInitiate(), capture ephemeralKey, embed it in headerJson.x3dh.ephemeralKey. Pass signedPreKeyId. Responder must read the ephemeral key from the header to calculate the shared secret.

Validation: Console log the derived sharedSecret on Sender and Receiver. They MUST be identical byte arrays.

Phase 2: Point-to-Point (1:1) E2EE
Goal: Secure private routing and header metadata.

Task 2.1: Deterministic 1:1 Routing

Action: Replace plaintext names with deterministic UUIDs: dm_${[myId, peerId].sort().join('_')}.

Validation: Two users open a 1:1 chat. Both clients mathematically generate the exact same space_id without network calls.

Task 2.2: Ratchet Header Encryption (Fixes P1-1)

Action: Encrypt the X3DH metadata and Ratchet public keys inside the header using a secondary symmetric key derived from the root chain.

Validation: Inspect message_ciphertexts in Supabase. The ratchet_header must be ciphertext, not plaintext identity keys.

Task 2.3: Fix Ciphertext Device Matching (Fixes BUG 7 & 8)

Action: Change recipient matching logic in fetchCiphertexts() to an AND statement: recipient_id === resolvedUserId && recipient_device_id === e2ee.deviceId.

Validation: Send a message to a user with multiple devices. The client must only attempt to decrypt the row matching its exact device_id.

Phase 3: Group E2EE (Sender Keys)
Goal: Scalable group encryption with strict forward secrecy.

Task 3.1: Remove Private Key from Distribution (Fixes FATAL BUG 15)

Action: Modify serializeSenderKey() to explicitly exclude signingKey.privateKey. Update deserialization to function with the public key only.

Validation: Intercept the /api/message payload. The serialized key MUST NOT contain the private Ed25519 signing key.

Task 3.2: Implement Skipped-Key Dictionary (Fixes BUG 16)

Action: Add a skipped-key cache to sender-keys.ts to handle out-of-order network arrivals.

Validation: Delay the receipt of Message 3 until after Message 4 arrives. The client must decrypt 4, cache the key, and successfully decrypt 3 when it arrives.

Task 3.3: Enforced Sender Key Rotation

Action: Bind to space_members Realtime table. If a member leaves/is removed, forcefully clear the active Sender Key and distribute a new one.

Validation: User C leaves group. User A sends message. User C's client MUST fail to decrypt it.

Phase 4: Network Synchronization & Async Races
Goal: Ensure UI states don't block cryptographic setup.

Task 4.1: JWT & Key Registration Race (Fixes BUG 1)

Action: In useE2EE.ts, verify getSupabaseToken() !== null before registerKeys(). Add a 1s retry loop.

Validation: Hard-refresh on a slow network. Registration must use the authenticated JWT without silent RLS failures.

Task 4.2: Broadcast vs. DB Write Race (Fixes BUG 5 & 20)

Action: In distributeSenderKey(), wait for /api/message 200 OK before broadcasting sender_key_dist over Realtime.

Validation: DB insert completes before broadcast fires. Online recipients process keys instantly without refreshing.

Task 4.3: sender_key_dist Pagination Blindspot (Fixes BUG 6 & 9)

Action: Execute a dedicated fetchMessages query for message_type = 'sender_key_dist' (NO LIMIT) before fetching the 50 E2EE messages.

Validation: Open a space with 100+ messages. Client successfully finds the Sender Key distribution and decrypts recent history.

Phase 5: Out-of-Band AI (Xark Spotlight)
Goal: Implement AI planning outside the E2EE boundary.

Task 5.1: Xark Spotlight UI & Routing

Action: Build the global XarkSpotlight.tsx command bar triggered by the bottom anchor. Remove ALL @xark listener logic from the standard chat composer.

Validation: Type "@xark" in the normal chat box; it should behave like regular text. Open the Spotlight to trigger AI prompts.

Task 5.2: Asynchronous State Mutation

Action: Connect Spotlight to a simplified /api/xark endpoint that exclusively returns structured JSON to mutate Layer 3 state (e.g., adding cards to the Possibility Horizon).

Validation: Query the Spotlight for "sushi spots". The chat timeline remains unpolluted. Decision cards silently populate in the "Decide" tab.