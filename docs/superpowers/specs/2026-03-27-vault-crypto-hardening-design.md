# Spec 2: "Vault" — Full Crypto Hardening

**Date:** 2026-03-27
**Scope:** Protocol hardening, hardware key storage, streaming media encryption, post-quantum key exchange, multi-device (Sesame), background push decryption
**Platform:** Web (Next.js) + Engine (Flutter/Dart) + Native iOS (Swift) + Native Android (Kotlin)
**Target:** Production-ready for 10k+ users. All 6 crypto items. No items deferred.
**Depends on:** Fortress spec (atomic RPC, partitioning, pooling, rate limiting, key cache, SK distribution, mutexes, ports)

---

## Decisions Already Made

- Hybrid X25519 + Kyber-1024 (PQXDH) — Signal/WhatsApp approach, X25519 safety net
- Streaming AEAD for files up to 2GB — WhatsApp parity (photos, video, docs, voice notes)
- Full Sesame multi-device on both web + engine — up to 5 devices per user
- Server-authoritative model (from Fortress)
- Pure Dart `cryptography` package for engine crypto; `libsodium-wrappers-sumo` for web
- FFI acceptable for Kyber if pure Dart/WASM unavailable

---

## 1. X3DH Responder Hardening (CRYPTO-01)

### Current State

Engine has working X3DH (`engine/lib/src/crypto/x3dh/x3dh.dart`, 213 lines, 289 lines of tests). Both initiator and responder roles implemented. Web has equivalent in `web/src/lib/crypto/x3dh.ts`.

### What's Missing

Edge case handling and integration testing:

1. **Expired/missing OTK handling:** When server returns no OTK (all consumed), X3DH must fall back to 3-DH (skip DH4). Current code may crash instead of gracefully degrading.
2. **Signature verification failure:** If the signed pre-key signature doesn't verify against the identity key, must abort with clear error (potential MITM). Currently may produce a bad shared secret silently.
3. **Key mismatch recovery:** If a session establishment fails (wrong keys returned by server due to stale cache), the client must invalidate the cached key bundle (X-Bypass-Cache from Fortress) and retry once.
4. **Stale signed pre-key:** If the signed pre-key is older than 7 days, warn but proceed (Signal behavior). Log to observer.
5. **Integration tests:** Full round-trip test: client A uploads keys → client B fetches bundle → client B initiates X3DH → client A processes initial message → bidirectional Double Ratchet established.

### Changes

**Engine:**
- `engine/lib/src/crypto/x3dh/x3dh.dart` — add explicit error types: `OtkExhaustedException`, `SignatureVerificationFailed`, `KeyMismatchError`
- `engine/test/crypto/x3dh_test.dart` — add edge case tests (no OTK, bad signature, stale SPK)
- `engine/test/integration/x3dh_integration_test.dart` — full round-trip with mock server

**Web:**
- `web/src/lib/crypto/x3dh.ts` — mirror same edge case handling
- `web/src/lib/crypto/crypto.test.ts` — add matching tests

---

## 2. Hardware-Backed Key Storage (CRYPTO-02)

### Problem

Identity keys currently stored via `flutter_secure_storage` which uses the platform keychain, but doesn't enforce hardware-backed storage. On iOS, keys could be in the software keychain (extractable). On Android, keys could be in encrypted shared preferences (extractable via root).

### Solution

Bind identity keys exclusively to hardware security modules:

**iOS (Secure Enclave):**
- Generate Ed25519 identity key inside the Secure Enclave via `SecKeyCreateRandomKey` with `kSecAttrTokenIDSecureEnclave`
- The private key NEVER leaves the enclave — all signing operations happen inside it
- Limitation: Secure Enclave supports P-256 (secp256r1) natively, NOT Ed25519. Options:
  - Use P-256 for iOS identity keys (different curve than Android/web)
  - OR: Generate a wrapping key in the Secure Enclave, use it to encrypt/decrypt the Ed25519 key in software
  - **Decision: Wrapping key approach** — keeps Ed25519 across all platforms, Secure Enclave protects the wrapping key

**Android (Keystore):**
- Generate AES-256 wrapping key in Android Keystore via `KeyGenParameterSpec.Builder` with `setIsStrongBoxBacked(true)` (StrongBox) falling back to TEE
- Ed25519 identity key encrypted with the wrapping key, stored in `flutter_secure_storage`
- Decryption requires biometric/PIN (via `setUserAuthenticationRequired(true)`)

**Web:**
- Use `crypto.subtle.generateKey()` with `extractable: false` for the wrapping key
- Store in IndexedDB (already encrypted via `encrypted-store.ts`)
- WebAuthn PRF for biometric-gated key derivation (future enhancement, not in this spec)

### Changes

**Engine:**
- `engine/lib/src/crypto/keys/hardware_key_store.dart` — new file, platform-specific key wrapping
- `engine/lib/src/crypto/keys/key_store_impl.dart` — delegate to hardware store for identity keys
- `engine/ios/Classes/SecureEnclavePlugin.swift` — native Swift plugin for Secure Enclave wrapping key
- `engine/android/src/main/kotlin/HardwareKeyStorePlugin.kt` — native Kotlin plugin for Keystore wrapping key

**Web:**
- `web/src/lib/crypto/hardware-keys.ts` — WebCrypto non-extractable wrapping key

---

## 3. Background Push Decryption (CRYPTO-03)

### Problem

When a push notification arrives and the app is backgrounded/killed, the user sees "New Message" instead of the actual message content. The server push payload contains only `{ recipientDeviceId, encryptedPayload }` — no sender name, no preview (E2EE).

### Solution

Platform-native background decryption:

**iOS — Notification Service Extension (NSE):**
- Create `app/ios/NotificationServiceExtension/` with Swift code
- NSE wakes on mutable-content push, has 30 seconds to modify the notification
- Access ratchet state via shared App Group keychain (`group.com.hello.app`)
- Decrypt the payload using the crypto isolate's persisted state (Drift DB in shared container)
- Mutate `UNNotificationContent` with sender name + message preview
- Fall back to "New Message" if decryption fails (missing session, timeout)

**Android — FirebaseMessagingService:**
- Create `app/android/app/src/main/kotlin/.../HelloMessagingService.kt`
- Override `onMessageReceived()` for data-only messages
- Decrypt in a background coroutine using the same Drift DB
- Post a local notification with plaintext content via `NotificationCompat.Builder`
- Fall back to "New Message" if decryption fails

**Web — Service Worker Enhancement:**
- Modify `web/public/firebase-messaging-sw.js`
- On push event, fetch encrypted payload from server
- Decrypt using cached keys from IndexedDB (same keystore as main thread)
- Show `Notification` with plaintext content
- Limitation: Service Worker cannot use Web Locks API — use a dedicated in-worker mutex

### Shared Architecture

All three platforms follow the same flow:
```
Silent push arrives → wake background handler → load ratchet state from DB
→ decrypt payload → show plaintext notification → persist updated ratchet state
```

The server push payload format:
```json
{
  "recipientDeviceId": 1,
  "messageId": "uuid-v7",
  "groupId": "group_123",
  "encryptedPayload": "base64...",
  "ratchetHeader": "base64..."
}
```

### Changes

**Engine/App:**
- `app/ios/NotificationServiceExtension/NotificationService.swift` — new, iOS NSE
- `app/ios/NotificationServiceExtension/Info.plist` — NSE configuration
- `app/ios/Runner/Runner.entitlements` — add App Group entitlement
- `app/android/app/src/main/kotlin/.../HelloMessagingService.kt` — new, Android service
- `app/android/app/src/main/AndroidManifest.xml` — register service
- `engine/lib/src/notifications/push_decryptor.dart` — shared Dart decryption logic (called from native via method channel or headless isolate)

**Web:**
- `web/public/firebase-messaging-sw.js` — enhance with E2EE decrypt logic

---

## 4. Sesame Multi-Device Protocol (CRYPTO-06)

### Architecture

Every user has up to 5 linked devices. Each device is a distinct cryptographic entity with its own:
- Identity Key Pair (Ed25519 + X25519)
- Signed Pre-Key (rotated every 7 days)
- One-Time Pre-Keys (100 per device)
- Ratchet sessions (per peer device)

### Server-Side Device Registry

New table: `user_devices`
```sql
CREATE TABLE user_devices (
  user_id TEXT NOT NULL,
  device_id INTEGER NOT NULL,
  device_name TEXT,
  platform TEXT NOT NULL, -- 'ios' | 'android' | 'web'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_active_at TIMESTAMPTZ,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, device_id)
);
```

### Message Fan-Out

When Alice sends a message to Bob, she encrypts it separately for each of Bob's devices:
1. Fetch Bob's device list: `SELECT device_id FROM user_devices WHERE user_id = 'bob'`
2. For each device: fetch key bundle, establish/reuse ratchet session, encrypt
3. Send N ciphertexts (one per device) via the atomic `send_e2ee_message` RPC

The `message_ciphertexts` table already supports this — it has `(recipient_id, recipient_device_id)` columns.

### Device Linking Protocol

To link a new device (e.g., user adds their iPad):
1. **Primary device** generates a QR code containing: `{ userId, linkingSecret, serverUrl }`
2. **New device** scans QR, authenticates with server, registers its key bundle
3. **Primary device** verifies the new device's identity key fingerprint
4. **Primary device** encrypts and transfers message history to the new device via a temporary secure channel (E2EE using the linking secret as a pre-shared key)
5. **Server** adds the new device to `user_devices`

### Device Unlinking

When a device is removed:
1. Delete device from `user_devices`
2. Delete all key bundles and OTKs for that device
3. Rotate Sender Keys for all groups the user is in (forces redistribution)
4. Other devices notified via Realtime broadcast

### Changes

**Database:**
- `web/supabase/migrations/XXXXXX_user_devices.sql` — device registry table + RLS
- `web/supabase/migrations/XXXXXX_device_linking.sql` — linking state table for QR flow

**Engine:**
- `engine/lib/src/devices/device_registry.dart` — device CRUD, fan-out logic
- `engine/lib/src/devices/device_linking.dart` — QR generation, scanning, history transfer
- `engine/lib/src/crypto/keys/key_store_impl.dart` — per-device key isolation
- `engine/lib/src/transport/supabase_client.dart` — fan-out message send (N devices per recipient)

**Web:**
- `web/src/lib/crypto/device-registry.ts` — device management
- `web/src/lib/crypto/device-linking.ts` — linking flow (QR display for primary, scan for new)
- `web/src/lib/crypto/encryption-service.ts` — fan-out encrypt per recipient device

**API:**
- `web/src/app/api/devices/route.ts` — device registration, listing, removal
- `web/src/app/api/devices/link/route.ts` — device linking handshake

---

## 5. Streaming AEAD Media Encryption (CRYPTO-07)

### Problem

Current media encryption loads entire files into memory for AES-256-GCM. A 500MB video = 500MB in RAM = OOM on most phones.

### Solution

Chunked streaming encryption with 64KB blocks:

**Encryption (sender):**
1. Generate one-time AES-256 key + 96-bit base nonce
2. Read file in 64KB chunks from disk
3. Each chunk encrypted with AES-256-GCM using nonce = `base_nonce XOR chunk_index`
4. Each chunk produces: `ciphertext(64KB) + auth_tag(16 bytes)`
5. Write encrypted chunks directly to upload stream (never holds full file in memory)
6. Final chunk: `{ aesKey, baseNonce, totalChunks, sha256Hash }` sent via Double Ratchet

**Decryption (receiver):**
1. Receive key material via Double Ratchet message
2. Download encrypted file in chunks
3. Decrypt each chunk, verify auth tag, write to disk
4. After all chunks: verify SHA-256 hash of assembled plaintext file

**Wire format per chunk:**
```
[4 bytes: chunk_index (big-endian)] [64KB: ciphertext] [16 bytes: GCM auth tag]
```

**Last chunk:** May be smaller than 64KB. Total file size derived from `totalChunks * 64KB + lastChunkSize`.

### Changes

**Engine:**
- `engine/lib/src/crypto/media/streaming_aead.dart` — new, chunked encrypt/decrypt
- `engine/lib/src/crypto/media/media_crypto.dart` — delegate to streaming for files > 1MB
- `engine/test/crypto/streaming_aead_test.dart` — test with various file sizes (0B, 1B, 64KB, 1MB, 100MB simulated)

**Web:**
- `web/src/lib/crypto/streaming-aead.ts` — new, Web Streams API for chunked processing
- `web/src/lib/crypto/file-encryption.ts` — delegate to streaming for files > 1MB

---

## 6. Post-Quantum PQXDH (CRYPTO-08)

### Protocol: Hybrid X25519 + Kyber-1024

Following Signal's PQXDH specification:

**Key bundle changes:**
Each device now uploads:
- Identity Key (Ed25519, unchanged)
- Signed Pre-Key (X25519, unchanged)
- **Signed Kyber Pre-Key** (Kyber-1024 encapsulation key, signed with Identity Key) — NEW
- One-Time Pre-Keys (X25519, unchanged)
- **One-Time Kyber Pre-Keys** (Kyber-1024, consumed atomically) — NEW

**Key agreement (initiator):**
1. Standard X3DH produces `dh_secret` (4 DH operations)
2. Kyber encapsulation with peer's Kyber pre-key produces `kem_secret` + `kem_ciphertext`
3. Combined: `shared_secret = HKDF(dh_secret || kem_secret, info="XarkE2EE-pqxdh")`
4. Initial message includes `kem_ciphertext` alongside the X3DH ephemeral key

**Key agreement (responder):**
1. Standard X3DH reconstruction produces `dh_secret`
2. Kyber decapsulation with own Kyber pre-key + received `kem_ciphertext` produces `kem_secret`
3. Combined: `shared_secret = HKDF(dh_secret || kem_secret, info="XarkE2EE-pqxdh")`

**Backward compatibility:**
- If a peer doesn't have Kyber pre-keys (old client), fall back to standard X3DH
- The `key_bundles` table gets nullable `kyber_pre_key` and `kyber_pre_key_sig` columns
- OTK table gets nullable `kyber_otk` column

### Library Strategy

**Dart (engine):** Use `pqcrypto` FFI package wrapping liboqs, OR pure-Dart Kyber if available. Fall back to `cryptography` package if it adds Kyber support.

**Web:** Use `pqc-kem` npm package (WASM-compiled Kyber-1024), OR `crystals-kyber` JS implementation.

If no suitable pure implementation exists at implementation time, use a WASM build of the reference C implementation.

### Changes

**Database:**
- `web/supabase/migrations/XXXXXX_pqxdh_key_columns.sql` — add kyber columns to key_bundles and one_time_pre_keys

**Engine:**
- `engine/lib/src/crypto/pqxdh/kyber.dart` — Kyber-1024 KEM wrapper (encapsulate/decapsulate)
- `engine/lib/src/crypto/pqxdh/pqxdh.dart` — hybrid X3DH + Kyber key agreement
- `engine/lib/src/crypto/keys/key_types.dart` — add KyberKeyPair, KyberPreKey types
- `engine/lib/src/crypto/keys/key_store_impl.dart` — store Kyber pre-keys
- `engine/lib/src/crypto/x3dh/x3dh.dart` — integrate PQXDH as upgrade path

**Web:**
- `web/src/lib/crypto/kyber.ts` — Kyber-1024 KEM wrapper
- `web/src/lib/crypto/pqxdh.ts` — hybrid key agreement
- `web/src/lib/crypto/x3dh.ts` — integrate PQXDH
- `web/src/lib/crypto/key-manager.ts` — generate/upload Kyber pre-keys

---

## Build Order & Parallelism

```
PARALLEL GROUP 1 (independent):
  Task A: X3DH Hardening (CRYPTO-01) — engine + web
  Task B: Streaming AEAD (CRYPTO-07) — engine + web
  Task C: Hardware Key Storage (CRYPTO-02) — engine + native

PARALLEL GROUP 2 (after Group 1):
  Task D: PQXDH Hybrid (CRYPTO-08) — depends on X3DH hardening
  Task E: Sesame Multi-Device (CRYPTO-06) — depends on hardware keys

PARALLEL GROUP 3 (after Group 2):
  Task F: Background Push Decrypt (CRYPTO-03) — depends on Sesame (needs device registry)
```

---

## Success Criteria

| Metric | Target |
|--------|--------|
| X3DH edge cases covered | All 5 (no OTK, bad sig, key mismatch, stale SPK, round-trip) |
| Identity key extraction from device | Impossible (hardware-bound wrapping key) |
| Push notification shows plaintext | < 500ms end-to-end on backgrounded app |
| Device linking completes | < 30 seconds including history transfer |
| 500MB video encrypt (streaming) | < 10 seconds, < 10MB peak RAM |
| PQXDH key agreement | < 100ms on mid-range device |
| Backward compat (no Kyber peer) | Transparent fallback to X3DH |
| Max linked devices | 5 per user |
