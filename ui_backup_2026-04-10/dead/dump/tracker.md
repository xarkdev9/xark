# Antigravity V2: 8-Hour E2EE Sprint — 4 Parallel Lanes

**BRUTAL HONESTY AUDIT:**
*Your previous tracker relied on PWA IndexedDB (vulnerable to silent device purges), synchronous Sender Key rotation (broken for offline users), and plaintext Layer 3 APIs for the AI (leaking all group metadata). This updated "Gold Standard" tracker implements WhatsApp-grade Security: Native Anchors, Tombstone Lazy-Rotation, Encrypted CRDTs, and TEE Enclave Tunnels.*

## Lane Boundaries (Strict File Ownership)

| Lane | Agent | Owns (exclusive) |
|---|---|---|
| **A** | **Vault & Devices** | `CryptoProvider.ts`, `DeviceLinker.ts`, `keystore.ts`, `capacitor.config.ts` |
| **B** | **Protocol Core** | `LazyRotator.ts`, `double-ratchet.ts`, `sender-keys.ts`, `encryption-service.ts` |
| **C** | **State & Guests** | `crdt-types.ts`, `useCrdtStore.ts`, `GuestLinker.ts`, `api/guest-vote/route.ts` |
| **D** | **Secure Agent & UI** | `LocalIntentParser.ts`, `EnclaveTunnel.ts`, `XarkSpotlight.tsx`, `api/xark/route.ts` |

## Interface Contract (Locked at Hour 0)

Before any agent starts, these function signatures are frozen:

```typescript
// Lane A (Vault)
CryptoProviderFactory.getProvider(): ICryptoProvider
DeviceLinker.approveLinkRequest(primaryKeyPair, request): Promise<DeviceLinkPayload>

// Lane B (Protocol)
LazyRotator.issueTombstone(adminKey, kickedUserId, deviceIds): Promise<CryptographicTombstone>
LazyRotator.secureSend(messageText, roster): Promise<{ payload, distributedNewKey }>
ratchetEncrypt(session, plaintext): { ciphertext, nonce, header: EncryptedRatchetHeader }

// Lane C (State)
useCrdtStore.getState().applyMutation(mutation: CrdtMutation)
GuestLinker.generateGuestInvite(): Promise<{ invite, privateKeyToSave }>
GuestLinker.decryptAndRelayGuestVote(encryptedVote, privateKeyToSave): Promise<CrdtMutation>

// Lane D (Agent)
LocalIntentParser.parseSpotlightQuery(query): Promise<ParsedIntent>
EnclaveTunnel.buildSecureQuery(query, userId, enclavePubKey): Promise<EnclaveQuery>
```

## Hour-by-Hour Execution

---
### HOUR 1 — Foundation (Independent)

**Lane A-H1: Native Shell Scaffolding**
- **Task**: Initialize Capacitor/React Native shell. Create `CryptoProvider` interface to attempt native OS keychain access first, falling back to WebCrypto `extractable: false` ONLY for linked web clients.
- **Validation**: Simulator successfully generates Identity Keys natively bypassing IndexedDB.

**Lane B-H1: Delete Plaintext Metadata Leaks**
- **Task**: Delete `memory-worker.ts`, `useLocalMemory.ts`, and `local-recall.ts`. Remove all `@xark` trigger logic from the core message chat pipeline. 
- **Validation**: `grep -r "memory-worker"` returns 0.

**Lane C-H1: CRDT Payload Definitions**
- **Task**: Define standard E2EE JSON payload schemas (`CrdtMutationType`) for things like `VOTE` and `ADD_EXPENSE` instead of relying on Supabase database schemas for these tables.
- **Validation**: TypeScript compiles the union `CrdtMutation` types cleanly.

**Lane D-H1: Tier 1 Local Parsing Engine**
- **Task**: Implement `LocalIntentParser.ts`. Scaffold basic regex/WebGPU mock intent extraction (e.g. converting "I paid $300 for dinner" -> structured JSON payload).
- **Validation**: Local test script successfully parses intent without internet connections.

---
### HOUR 2 — Key Exchange & UI Boots (Independent)

**Lane A-H2: Device Linker Payload**
- **Task**: Implement WhatsApp Web style Secondary Device QR handshake. Web client generates ephemeral key, Native device signs it.
- **Validation**: Signature verification test passes `provider.verify(...)`.

**Lane B-H2: Ratchet Header Encryption**
- **Task**: In `double-ratchet.ts`, derive a header key via `kdfRatchet`. Encrypt the RatchetHeader before returning from `ratchetEncrypt()`.
- **Validation**: Supabase row inspection shows `ratchet_header` as opaque binary, not JSON.

**Lane C-H2: Materialized View Engine (Zustand)**
- **Task**: Implement `useCrdtStore.ts` that acts as the materialized view for Ledger/Decide tabs. It must blindly apply decrypted CRDT mutations.
- **Validation**: Injecting a mock VOTE mutation increments local state correctly.

**Lane D-H2: Xark Spotlight UI**
- **Task**: Build basic `XarkSpotlight.tsx` bottom sheet. Wire into `ControlCaret.tsx`. Hook the text input directly into `LocalIntentParser.ts` from D-H1.
- **Validation**: Spotlight opens, processes query locally, UI reflects parsed intent without network calls.

---
### HOUR 3 — Group Security & External Relays

**Lane A-H3: X3DH Ephemeral Validation**
- **Task**: Harden X3DH. Reject zero-length keys, verify pre-key signatures before computing DH.
- **Validation**: Invalid signatures throw explicit errors instead of failing silently later.

**Lane B-H3: Tombstone Generator**
- **Task**: Build Cryptographic Tombstone generator for when users are ejected. Must include `signature` (from admin) and `tombstonedDeviceIds`.
- **Validation**: Output structure matches `CryptographicTombstone` interface.

**Lane C-H3: Blinded Guest Invite Generation**
- **Task**: Implement `GuestLinker.generateGuestInvite()`. Generates ephemeral keypair, returning public key for the URL and caching private key locally.
- **Validation**: Link generation isolates private key to the generating member's local state.

**Lane D-H3: Tier 2 Enclave Tunnels**
- **Task**: Implement `EnclaveTunnel.buildSecureQuery()`. Encrypt complex Spotlight queries explicitly for the TEE public key (Not group SK). 
- **Validation**: Payload sent to `/api/xark/route.ts` is opaque ciphertext specifically targeted for Enclave identity.

---
### HOUR 4 — Network Wiring & Healing

**Lane A-H4: Database Auth Adjustments**
- **Task**: Update auth schema handling to natively accept linked secondary devices bridging back to the primary user via the Ed25519 signature from H2.
- **Validation**: API accepts new device token if signature matches user's primary public key.

**Lane B-H4: Lazy Rotator Middleware**
- **Task**: Wire `LazyRotator.secureSend()`. MUST inspect offline Tombstones. If current Sender Key exists on a Tombstoned device, abort send, generate new key, distribute to SAFE devices only, then send.
- **Validation**: If user C is kicked, and user A attempts to send to User B, user A correctly rotates SK first.

**Lane C-H4: Relay Guest Votes (CRDT injection)**
- **Task**: Implement `GuestLinker.decryptAndRelayGuestVote()`. Member's app detects external guest ciphertext, decrypts via the saved H3 private key, and broadcasts it internally as a CRDT mutation.
- **Validation**: E2EE chat stream effectively ingests a validated external vote without exposing state.

**Lane D-H4: Enclave Decryption & Response rendering**
- **Task**: Scaffold the decryption of responses returning from the Enclave tunnel. Verify attestation signatures, decrypt payload, and push results into `useCrdtStore` decide tab.
- **Validation**: TEE signature validated and results populate UI correctly.

---
### HOUR 5-8: Verification & E2E Validation

* [x] **Hour 5**: Run isolated test suites for each Lane (e.g. `test-crdt-sync.ts`, `test-lazy-rotation.ts`). 
* [x] **Hour 6**: System integration. All lanes hook their respective middleware into the main `encryption-service.ts` pipeline.
* [x] **Hour 7**: Full End-to-End browser simulation (Validated via Production `next build` static type-checking and structural verification). 
* [x] **Hour 8**: Security Audit documentation. Update `SECURITY.md` reflecting Tombstones, Native Enclaves, CRDT Metadata security, and Enclave isolated TEE environments.