# apr4_status.md — Machine-Readable Codebase Truth Table

> **Date:** 2026-04-04 | **Reviewer:** Claude Opus 4.6 | **Format:** JSON for AI agent consumption
> **Scope:** All 8 B2B modules, 240+ files audited, every TODO/stub/hardcoded value with exact line numbers

```json
{
  "audit_meta": {
    "date": "2026-04-04",
    "reviewer": "Claude Opus 4.6 (1M context)",
    "total_files_audited": 243,
    "total_todos_found": 30,
    "total_stubs_found": 24,
    "total_hardcoded_values": 47
  },

  "verdicts_summary": [
    { "module": "E2EE Crypto Kit", "verdict": "CORE_WORKS", "can_demo": true, "can_sell": false },
    { "module": "Decision Engine", "verdict": "CORE_WORKS", "can_demo": true, "can_sell": false },
    { "module": "Xpensly SDK", "verdict": "CORE_WORKS", "can_demo": true, "can_sell": false },
    { "module": "Sesame Multi-Device", "verdict": "DOES_NOT_WORK", "can_demo": false, "can_sell": false },
    { "module": "AI Intelligence (@hello)", "verdict": "WORKS_E2E", "can_demo": true, "can_sell": true },
    { "module": "Discovery Engine", "verdict": "STUB", "can_demo": false, "can_sell": false },
    { "module": "Offline-First Sync", "verdict": "PARTIALLY_WORKS", "can_demo": false, "can_sell": false },
    { "module": "Consensus/Voting UI", "verdict": "PARTIALLY_WORKS", "can_demo": true, "can_sell": false }
  ],

  "modules": [
    {
      "id": "e2ee-crypto-kit",
      "name": "E2EE Crypto Kit",
      "verdict": "CORE_WORKS",
      "can_demo": true,
      "can_sell": false,
      "reason": "X3DH + Double Ratchet + Sender Keys are real crypto. But crypto isolate echoes plaintext, Kyber is stub, no HSM, no franking impl, media send short-circuits, single device hardcoded.",
      "platforms": ["dart", "web"],
      "files": [
        {
          "path": "engine/lib/src/crypto/x3dh/x3dh.dart",
          "lines": 289,
          "status": "REAL",
          "evidence": "Line 84-97: real Ed25519 verify. Lines 112-139: real X25519 DH via cryptography package. Line 152: HKDF with XarkE2EE-x3dh.",
          "todos": [],
          "stubs": [],
          "hardcoded": [
            "71: _hkdfInfo = 'XarkE2EE-x3dh' (crypto constant, intentional)"
          ],
          "depends_on": ["cryptography package"],
          "test_coverage": "engine/test/crypto_interop_test.dart"
        },
        {
          "path": "engine/lib/src/crypto/ratchet/double_ratchet.dart",
          "lines": 461,
          "status": "REAL",
          "evidence": "Lines 97-98: HMAC-SHA256 chain KDF with 0x01/0x02. Lines 281-288: Xchacha20.poly1305Aead encryption. Lines 335-352: bounded 1000-key skip dict.",
          "todos": [],
          "stubs": [],
          "hardcoded": [
            "20: _ratchetInfo = 'XarkE2EE-ratchet' (crypto constant)",
            "23: _maxSkippedKeys = 1000"
          ],
          "depends_on": ["cryptography package", "x3dh.dart"],
          "test_coverage": "engine/test/ratchet_test.dart"
        },
        {
          "path": "engine/lib/src/crypto/sender_keys/group_cipher.dart",
          "lines": 293,
          "status": "REAL",
          "evidence": "Lines 106-109: real Xchacha20.poly1305Aead. Lines 130-138: real Ed25519 signing. Lines 140-166: wire format nonce(24)+sig(64)+iter(4)+ct+mac(16).",
          "todos": [],
          "stubs": [],
          "hardcoded": [],
          "depends_on": ["cryptography package"],
          "test_coverage": "engine/test/group_cipher_test.dart"
        },
        {
          "path": "engine/lib/src/crypto/pqxdh/pqxdh.dart",
          "lines": 329,
          "status": "PARTIAL",
          "evidence": "Lines 233-309: protocol logic is real (HKDF combination). Lines 54-133: StubKyber uses 32-byte random keys, not Kyber-1024 (1568B). Line 131: decapsulate returns zeros.",
          "todos": [],
          "stubs": [
            "54-133: StubKyber class — 32-byte test keys instead of Kyber-1024",
            "130-131: decapsulate() returns Uint8List(32) zeros",
            "224: default KEM = StubKyber()"
          ],
          "hardcoded": [
            "210: pqxdhHkdfInfo = 'XarkE2EE-pqxdh' (crypto constant)"
          ],
          "depends_on": ["x3dh.dart"],
          "test_coverage": "engine/test/pqxdh_test.dart"
        },
        {
          "path": "engine/lib/src/crypto/media/streaming_aead.dart",
          "lines": 155,
          "status": "REAL",
          "evidence": "Lines 87-88: AesGcm.with256bits(). Lines 66-73: per-chunk nonce XOR. Lines 92-97: real encrypt per chunk.",
          "todos": [],
          "stubs": [],
          "hardcoded": ["16: chunkSize = 65536 (64KB)"],
          "depends_on": ["cryptography package"],
          "test_coverage": "engine/test/streaming_aead_test.dart"
        },
        {
          "path": "engine/lib/src/crypto/media/media_crypto.dart",
          "lines": 144,
          "status": "REAL",
          "evidence": "Line 49-50: files >1MB delegated to streaming AEAD. Lines 53-58: AesGcm.with256bits. Lines 93-97: SHA-256 integrity hash.",
          "todos": [],
          "stubs": [],
          "hardcoded": ["9: _streamingThreshold = 1024 * 1024 (1MB)"],
          "depends_on": ["streaming_aead.dart"],
          "test_coverage": "engine/test/media_crypto_test.dart"
        },
        {
          "path": "engine/lib/src/crypto/keys/key_store_impl.dart",
          "lines": 383,
          "status": "REAL",
          "evidence": "Lines 48-52: Ed25519().newKeyPair(). Lines 69-84: persist with optional hardware wrapping. Lines 145-174: OTK batch generation.",
          "todos": [],
          "stubs": [],
          "hardcoded": [],
          "depends_on": ["flutter_secure_storage", "hardware_key_store.dart"],
          "test_coverage": "engine/test/key_store_test.dart"
        },
        {
          "path": "engine/lib/src/crypto/keys/hardware_key_store.dart",
          "lines": 88,
          "status": "PARTIAL",
          "evidence": "Lines 46-63: wrap/unwrap use real AES-256-GCM. Line 82: isHardwareAvailable() returns false. Line 35: comment says 'In real implementation, load from flutter_secure_storage.'",
          "todos": [],
          "stubs": [
            "35: SoftwareKeyStore generates random in-memory key, not persisted to flutter_secure_storage",
            "82: isHardwareAvailable() hardcoded false — no iOS Secure Enclave or Android StrongBox"
          ],
          "hardcoded": [
            "82: isHardwareAvailable() returns false"
          ],
          "depends_on": [],
          "test_coverage": "engine/test/hardware_key_store_test.dart"
        },
        {
          "path": "engine/lib/src/crypto/keys/database_key_manager.dart",
          "lines": 42,
          "status": "REAL",
          "evidence": "Line 13: key alias 'e2ee_chat_db_key'. Line 33: returns null when secure storage unavailable.",
          "todos": [],
          "stubs": [],
          "hardcoded": [],
          "depends_on": ["flutter_secure_storage"],
          "test_coverage": "NONE"
        },
        {
          "path": "engine/lib/src/crypto/keys/ed25519_to_curve25519.dart",
          "lines": 424,
          "status": "REAL",
          "evidence": "Pure GF(2^255-19) field arithmetic. Matches libsodium crypto_sign_ed25519_pk_to_curve25519.",
          "todos": [],
          "stubs": [],
          "hardcoded": [],
          "depends_on": [],
          "test_coverage": "engine/test/crypto_interop_test.dart"
        },
        {
          "path": "engine/lib/src/crypto/franking/message_franking.dart",
          "lines": 48,
          "status": "INTERFACE_ONLY",
          "evidence": "Lines 4-38: FrankingReport data class. Lines 40-48: MessageFranking abstract class with zero concrete implementation.",
          "todos": [],
          "stubs": [
            "40-48: MessageFranking is abstract — no createReport() implementation exists anywhere"
          ],
          "hardcoded": [],
          "depends_on": [],
          "test_coverage": "NONE"
        },
        {
          "path": "engine/lib/src/crypto/profile/profile_crypto.dart",
          "lines": 73,
          "status": "REAL",
          "evidence": "Lines 35-42: AesGcm.with256bits() with auto-generated nonce. Lines 47-72: decrypt parses iv(12)+ciphertext+mac(16).",
          "todos": [],
          "stubs": [],
          "hardcoded": [],
          "depends_on": ["cryptography package"],
          "test_coverage": "engine/test/profile_crypto_test.dart"
        },
        {
          "path": "engine/lib/src/crypto/crypto_isolate.dart",
          "lines": 359,
          "status": "STUB",
          "evidence": "Lines 285/304/322/340: all 4 crypto operations echo input unchanged. Comment: 'Echo back — full ratchet wiring is Phase 3b'.",
          "todos": [
            "261: // TODO: Wire to Drift DB write when ratchet state caching is implemented"
          ],
          "stubs": [
            "285: EncryptRequest returns plaintext unchanged (echo-back)",
            "304: DecryptRequest returns ciphertext unchanged (echo-back)",
            "322: GroupEncryptRequest returns plaintext unchanged (echo-back)",
            "340: GroupDecryptRequest returns ciphertext unchanged (echo-back)"
          ],
          "hardcoded": [
            "94: _maxRespawns = 3",
            "97: _requestTimeout = Duration(seconds: 10)"
          ],
          "depends_on": [],
          "test_coverage": "NONE"
        },
        {
          "path": "engine/lib/src/domain/use_cases/send_message_use_case.dart",
          "lines": 480,
          "status": "REAL",
          "evidence": "Line 156: DoubleRatchet.encrypt(ratchetState, payloadBytes) — calls REAL crypto. Lines 314-317: GroupCipher.encrypt. Lines 362-419: real X3DH session establishment.",
          "todos": [],
          "stubs": [
            "141: const recipientDeviceId = 1 — hardcoded single device, no fan-out",
            "451: sendMedia() delegates to sendText('[media:${payload.fileName}]') — bypasses real media crypto",
            "463: react() sends reaction as text '[emoji:messageId]' — not structured"
          ],
          "hardcoded": [
            "141: const recipientDeviceId = 1",
            "70: _maxOutboxSize = 500"
          ],
          "depends_on": ["double_ratchet.dart", "group_cipher.dart", "x3dh.dart", "key_store_impl.dart"],
          "test_coverage": "engine/test/send_message_test.dart"
        },
        {
          "path": "engine/lib/src/notifications/push_decryptor.dart",
          "lines": 91,
          "status": "STUB",
          "evidence": "Lines 79-83: always returns PushDecryptResult.fallback with 'Push decryption not yet wired to crypto isolate'.",
          "todos": [
            "72: // TODO: Access the crypto isolate via IsolateNameServer",
            "73: // TODO: If not available, open Drift DB directly and load ratchet state",
            "74: // TODO: Decrypt payload",
            "75: // TODO: Parse plaintext to extract sender name + message preview",
            "76: // TODO: Persist updated ratchet state"
          ],
          "stubs": [
            "79-83: decryptPushPayload() always returns fallback 'You may have new messages'"
          ],
          "hardcoded": [
            "10: senderName: 'Chat' (fallback)",
            "11: messagePreview: 'You may have new messages' (fallback)"
          ],
          "depends_on": [],
          "test_coverage": "NONE"
        },
        {
          "path": "engine/lib/src/devices/device_registry.dart",
          "lines": 53,
          "status": "INTERFACE_ONLY",
          "evidence": "Abstract class DeviceRegistry with 4 method signatures. DeviceInfo data class. Zero implementation.",
          "todos": [],
          "stubs": [],
          "hardcoded": [],
          "depends_on": [],
          "test_coverage": "NONE"
        },
        {
          "path": "engine/lib/src/devices/device_linking.dart",
          "lines": 95,
          "status": "INTERFACE_ONLY",
          "evidence": "Abstract class DeviceLinking with 4 method signatures. LinkingRequest data class. LinkingState enum. Zero implementation.",
          "todos": [],
          "stubs": [],
          "hardcoded": [],
          "depends_on": [],
          "test_coverage": "NONE"
        },
        {
          "path": "engine/lib/src/devices/devices.dart",
          "lines": 8,
          "status": "STUB",
          "evidence": "Line 7: '// TODO(phase2): Implement DeviceRegistry, DeviceLinkingProtocol, and KeyRotationService.'",
          "todos": [
            "7: // TODO(phase2): Implement DeviceRegistry, DeviceLinkingProtocol, and KeyRotationService."
          ],
          "stubs": ["Barrel file with TODO, no re-exports"],
          "hardcoded": [],
          "depends_on": [],
          "test_coverage": "NONE"
        },
        {
          "path": "engine/lib/src/contacts/contacts.dart",
          "lines": 7,
          "status": "STUB",
          "evidence": "Line 7: '// TODO(phase2): Implement ContactDiscovery and ProfileKeyDistributor.'",
          "todos": [
            "7: // TODO(phase2): Implement ContactDiscovery and ProfileKeyDistributor."
          ],
          "stubs": ["Barrel file with TODO, no code"],
          "hardcoded": [],
          "depends_on": [],
          "test_coverage": "NONE"
        },
        {
          "path": "engine/lib/src/media/background_uploader.dart",
          "lines": 237,
          "status": "PARTIAL",
          "evidence": "Queue management, persistence, progress, retry/cancel all real. Encrypt+upload are TODO.",
          "todos": [
            "150: // TODO(MOBILE-05): Wire StreamingAead from crypto/media/streaming_aead.dart.",
            "158-159: // TODO(MOBILE-05): Implement chunked upload with progress tracking."
          ],
          "stubs": [
            "150-159: actual encrypt+upload not wired"
          ],
          "hardcoded": [
            "63: maxConcurrentTasks = 3",
            "66: pollInterval = Duration(seconds: 5)"
          ],
          "depends_on": ["streaming_aead.dart (not wired)"],
          "test_coverage": "NONE"
        },
        {
          "path": "engine/lib/src/auth/app_lock_manager.dart",
          "lines": 34,
          "status": "STUB",
          "evidence": "Line 16: isBiometricAvailable() returns false. Line 29: authenticate() returns true always.",
          "todos": [],
          "stubs": [
            "16: returns false with comment 'Will be wired when local_auth is added'",
            "29: returns true always — biometric gate is non-functional"
          ],
          "hardcoded": [
            "16: isBiometricAvailable() returns false",
            "29: authenticate() returns true"
          ],
          "depends_on": ["local_auth package (not added)"],
          "test_coverage": "NONE"
        },
        {
          "path": "web/src/lib/crypto/encryption-service.ts",
          "lines": 1175,
          "status": "REAL",
          "evidence": "Full encrypt/decrypt pipeline. Lines 175-211: real X3DH session establishment. Lines 585-592: mutex-protected DM encryption. Lines 450-566: SK distribution via ratchet.",
          "todos": [],
          "stubs": [],
          "hardcoded": ["940: spkId = 1 (current signed pre-key ID)"],
          "depends_on": ["double-ratchet.ts", "sender-keys.ts", "x3dh.ts", "keystore.ts", "mutex.ts"],
          "test_coverage": "web/src/lib/__tests__/crypto.test.ts"
        },
        {
          "path": "web/src/lib/crypto/double-ratchet.ts",
          "lines": 246,
          "status": "REAL",
          "evidence": "Lines 71-83: ratchetEncrypt with real aesEncrypt (XChaCha20-Poly1305). Lines 86-98: header encryption via HKDF-derived key. Lines 156-175: DH ratchet step.",
          "todos": [],
          "stubs": [],
          "hardcoded": ["11: MAX_SKIP = 1000", "12: HEADER_KEY_INFO = 'XarkE2EE-header-key'"],
          "depends_on": ["primitives.ts (libsodium)"],
          "test_coverage": "web/src/lib/__tests__/crypto.test.ts"
        },
        {
          "path": "web/src/lib/crypto/sender-keys.ts",
          "lines": 224,
          "status": "REAL",
          "evidence": "Lines 35-36: real chain KDF + aesEncrypt. Lines 49-50: Ed25519 signing. Lines 156-167: distribution excludes private key.",
          "todos": [],
          "stubs": [],
          "hardcoded": ["13: MAX_SK_SKIP = 1000"],
          "depends_on": ["primitives.ts (libsodium)"],
          "test_coverage": "web/src/lib/__tests__/crypto.test.ts"
        },
        {
          "path": "web/src/lib/crypto/x3dh.ts",
          "lines": 133,
          "status": "REAL",
          "evidence": "Lines 54-59: real Ed25519 verify. Lines 63-78: 4 DH computations via libsodium crypto_scalarmult. Line 81: HKDF with XarkE2EE-x3dh.",
          "todos": [],
          "stubs": [],
          "hardcoded": ["8: X3DH_INFO = 'XarkE2EE-x3dh'"],
          "depends_on": ["primitives.ts (libsodium)"],
          "test_coverage": "web/src/lib/__tests__/crypto.test.ts"
        },
        {
          "path": "web/src/lib/crypto/pqxdh.ts",
          "lines": 183,
          "status": "PARTIAL",
          "evidence": "Protocol logic real (lines 117-142). Lines 46-74: StubKyber with random 32-byte keys. Line 71: returns zeros.",
          "todos": [],
          "stubs": [
            "46-74: StubKyber — random bytes, not Kyber-1024",
            "71: encapsulate returns random shared secret (not real KEM)",
            "73: decapsulate returns Uint8Array(32) zeros"
          ],
          "hardcoded": ["8: PQXDH_INFO = 'XarkE2EE-pqxdh'"],
          "depends_on": ["x3dh.ts", "primitives.ts"],
          "test_coverage": "web/src/lib/__tests__/crypto.test.ts"
        },
        {
          "path": "web/src/lib/crypto/keystore.ts",
          "lines": 596,
          "status": "REAL",
          "evidence": "Lines 32-59: IndexedDB xark-keystore v5 with 10+ stores. Lines 309-349: SK persistence encrypted at rest. Lines 354-383: session persistence.",
          "todos": [],
          "stubs": [],
          "hardcoded": ["18: DB_NAME = 'xark-keystore'", "19: DB_VERSION = 5"],
          "depends_on": ["encrypted-store.ts"],
          "test_coverage": "web/src/lib/__tests__/crypto.test.ts"
        },
        {
          "path": "web/src/lib/crypto/primitives.ts",
          "lines": 291,
          "status": "REAL",
          "evidence": "Line 5: import from libsodium-wrappers-sumo (real WASM). Line 27: crypto_sign_keypair. Line 91-93: crypto_aead_xchacha20poly1305_ietf_encrypt.",
          "todos": [],
          "stubs": [],
          "hardcoded": ["186: 3 Argon2id iterations", "187: 67108864 (64MB memory)"],
          "depends_on": ["libsodium-wrappers-sumo"],
          "test_coverage": "web/src/lib/__tests__/crypto.test.ts"
        },
        {
          "path": "web/src/lib/crypto/message-franking.ts",
          "lines": 72,
          "status": "PARTIAL",
          "evidence": "Types real. Lines 48-49: createFrankingReport returns empty strings for messageKey and ciphertext with TODO comments.",
          "todos": [
            "48: messageKey: '', // TODO: Extract from ratchet session",
            "49: ciphertext: '', // TODO: Fetch from message_ciphertexts"
          ],
          "stubs": [
            "43-49: createFrankingReport returns empty key material"
          ],
          "hardcoded": [],
          "depends_on": [],
          "test_coverage": "NONE"
        },
        {
          "path": "web/src/lib/crypto/device-linking.ts",
          "lines": 37,
          "status": "INTERFACE_ONLY",
          "evidence": "Types and JSON encode/decode only. No QR generation, no history transfer, no device verification protocol.",
          "todos": [],
          "stubs": ["No actual linking protocol — just data structures"],
          "hardcoded": [],
          "depends_on": [],
          "test_coverage": "NONE"
        },
        {
          "path": "web/src/lib/crypto/device-registry.ts",
          "lines": 42,
          "status": "REAL",
          "evidence": "Thin Supabase RPC wrappers: registerDevice, getUserDevices, unlinkDevice.",
          "todos": [],
          "stubs": [],
          "hardcoded": [],
          "depends_on": ["supabase-admin.ts"],
          "test_coverage": "NONE"
        },
        {
          "path": "web/src/lib/crypto/outbox.ts",
          "lines": 164,
          "status": "REAL",
          "evidence": "Full offline message queue in IndexedDB. Drain on reconnect/visibility. Retry with attempt tracking (max 5).",
          "todos": [],
          "stubs": [],
          "hardcoded": ["29: DB_NAME = 'hello-outbox'", "96: max 5 retries"],
          "depends_on": [],
          "test_coverage": "NONE"
        },
        {
          "path": "web/src/lib/crypto/sk-recovery.ts",
          "lines": 193,
          "status": "REAL",
          "evidence": "Full P2P Sender Key recovery. Request, wait, notify. Membership + key bundle verification.",
          "todos": [],
          "stubs": [],
          "hardcoded": ["34: 30s dedup timeout", "78: 10s SK wait timeout"],
          "depends_on": ["encryption-service.ts", "keystore.ts"],
          "test_coverage": "NONE"
        },
        {
          "path": "web/src/lib/crypto/mutex.ts",
          "lines": 72,
          "status": "REAL",
          "evidence": "Web Locks API with AbortController 5s timeout. In-tab promise-queue fallback.",
          "todos": [],
          "stubs": [],
          "hardcoded": ["31: timeoutMs = 5000"],
          "depends_on": [],
          "test_coverage": "NONE"
        }
      ],
      "execution_paths": [
        {
          "name": "Send encrypted 1:1 DM (Dart)",
          "steps": [
            "session.sendText(plaintext)",
            "SendMessageUseCase._sendDM():144",
            "_establishSession() fetches PreKeyBundle from server",
            "X3DH.performAsInitiator() — REAL DH computation",
            "DoubleRatchet.initAlice() — REAL ratchet init",
            "DoubleRatchet.encrypt(ratchetState, payloadBytes):156 — REAL XChaCha20-Poly1305",
            "base64 encode → HTTP POST to /api/message"
          ],
          "breaks_at": null,
          "verdict": "WORKS"
        },
        {
          "name": "Send encrypted group message (Dart)",
          "steps": [
            "session.sendText(plaintext)",
            "SendMessageUseCase._sendGroup():296",
            "Distribute SK via DoubleRatchet to each member — REAL",
            "GroupCipher.encrypt(groupId, userId, payloadBytes):314 — REAL Ed25519+XChaCha20",
            "base64 encode → HTTP POST to /api/message"
          ],
          "breaks_at": "141: recipientDeviceId hardcoded to 1 — only device 1 receives ciphertext",
          "verdict": "WORKS for single device, FAILS for multi-device"
        },
        {
          "name": "Send encrypted DM (Web)",
          "steps": [
            "encryptForSanctuary(spaceId, plaintext)",
            "acquireMutex('ratchet-{peerId}'):585",
            "getOrEstablishSession() — X3DH if no session:175",
            "ratchetEncrypt(session, payload):71 — REAL XChaCha20-Poly1305",
            "POST /api/message with ciphertext"
          ],
          "breaks_at": null,
          "verdict": "WORKS"
        },
        {
          "name": "Push notification decryption",
          "steps": [
            "PushMethodChannel.onPush()",
            "PushDecryptor.decryptPushPayload()",
            "TODO: Access crypto isolate via IsolateNameServer",
            "RETURNS FALLBACK: 'You may have new messages'"
          ],
          "breaks_at": "push_decryptor.dart:79 — always returns fallback, 5 TODOs",
          "verdict": "DOES NOT WORK"
        },
        {
          "name": "Media file send",
          "steps": [
            "session.sendMedia(payload)",
            "SendMessageUseCase.sendMedia():451",
            "DELEGATES to sendText('[media:${payload.fileName}]')",
            "Real AES-GCM media crypto exists but IS NOT WIRED"
          ],
          "breaks_at": "send_message_use_case.dart:451 — short-circuits to text placeholder",
          "verdict": "DOES NOT WORK (sends text marker, not encrypted file)"
        }
      ],
      "blocking_issues": [
        { "severity": "CRITICAL", "file": "engine/lib/src/crypto/crypto_isolate.dart", "line": 285, "description": "Crypto isolate echoes plaintext unchanged for all 4 operations. Crypto runs on main thread, not background isolate." },
        { "severity": "CRITICAL", "file": "engine/lib/src/domain/use_cases/send_message_use_case.dart", "line": 141, "description": "recipientDeviceId = 1 hardcoded. Multi-device fan-out not implemented." },
        { "severity": "CRITICAL", "file": "engine/lib/src/notifications/push_decryptor.dart", "line": 79, "description": "Push decryption returns hardcoded fallback. 5 TODOs mark missing wiring." },
        { "severity": "HIGH", "file": "engine/lib/src/domain/use_cases/send_message_use_case.dart", "line": 451, "description": "sendMedia() delegates to sendText() with text marker. Real media crypto exists but not wired." },
        { "severity": "HIGH", "file": "engine/lib/src/crypto/pqxdh/pqxdh.dart", "line": 54, "description": "Kyber-1024 is a stub. StubKyber returns random 32-byte keys. Post-quantum claims are vaporware." },
        { "severity": "HIGH", "file": "engine/lib/src/crypto/franking/message_franking.dart", "line": 40, "description": "Abstract class only. No concrete implementation. E2EE moderation non-functional." },
        { "severity": "MEDIUM", "file": "engine/lib/src/crypto/keys/hardware_key_store.dart", "line": 82, "description": "isHardwareAvailable() returns false. No iOS Secure Enclave or Android StrongBox." }
      ],
      "missing_for_b2b": [
        "Wire crypto isolate to call real DoubleRatchet/GroupCipher (not echo)",
        "Multi-device fan-out (query recipient devices, encrypt to each)",
        "Push decryption (iOS NSE + Android Service + crypto isolate via IsolateNameServer)",
        "Wire media send to real AES-GCM pipeline (streaming_aead.dart exists)",
        "Implement Kyber-1024 via FFI to liboqs (or remove PQ claims)",
        "Concrete MessageFranking implementation",
        "Hardware key store (iOS Secure Enclave, Android StrongBox)",
        "Persist sender keys to Drift DB (currently in-memory, lost on restart)"
      ]
    },

    {
      "id": "decision-engine",
      "name": "Decision Engine (algo/)",
      "verdict": "CORE_WORKS",
      "can_demo": true,
      "can_sell": false,
      "reason": "All algorithms are real and tested (198 tests). But TypeScript build has 26 errors from duplicate GroupId. Zero production adapters — only in-memory. No HTTP server.",
      "platforms": ["typescript"],
      "files": [
        { "path": "algo/src/engine/heart-sort.ts", "lines": 188, "status": "REAL", "evidence": "7 pure functions. Real weighted scoring, dedup, O(n log n) sort.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "algo/src/__tests__/heart-sort.test.ts (25 tests)" },
        { "path": "algo/src/engine/green-lock.ts", "lines": 202, "status": "REAL", "evidence": "commitItem, lockItem, transferOwnership. Proof validation. Ownership audit trail.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "algo/src/__tests__/green-lock.test.ts (20 tests)" },
        { "path": "algo/src/engine/state-machine.ts", "lines": 66, "status": "REAL", "evidence": "Configurable trigger-based transitions. transition(), isLocked(), canTransition().", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "algo/src/__tests__/state-machine.test.ts (21 tests)" },
        { "path": "algo/src/engine/state-flows.ts", "lines": 57, "status": "REAL", "evidence": "4 preset flows: BOOKING, PURCHASE, SIMPLE_VOTE, SOLO_DECISION.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "algo/src/__tests__/state-machine.test.ts" },
        { "path": "algo/src/engine/consensus-engine.ts", "lines": 594, "status": "REAL", "evidence": "Full orchestrator: spaces, items, reactions, locking, tasks, events, AI grounding, pagination.", "todos": [], "stubs": ["27: duplicate GroupId import (harmless at runtime, breaks tsc)", "198: duplicate groupId property (harmless, JS takes last value)"], "hardcoded": [], "test_coverage": "algo/src/__tests__/consensus-engine.test.ts (16 tests)" },
        { "path": "algo/src/engine/ai-grounding.ts", "lines": 140, "status": "REAL", "evidence": "buildGroundingContext, generateGroundingPrompt, checkSuggestionConflicts. All real.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "algo/src/__tests__/ai-grounding.test.ts (8 tests)" },
        { "path": "algo/src/engine/task-assignment.ts", "lines": 106, "status": "REAL", "evidence": "createTask, assignTask, reassignTask, unassignTask. UUID IDs.", "todos": [], "stubs": ["101-106: resetTaskCounter() is deprecated no-op"], "hardcoded": [], "test_coverage": "algo/src/__tests__/task-assignment.test.ts (8 tests)" },
        { "path": "algo/src/models/types.ts", "lines": 191, "status": "REAL", "evidence": "All types, enums, interfaces. REACTION_WEIGHTS, DEFAULT_SPACE_CONFIG.", "todos": [], "stubs": ["15: duplicate GroupId type declaration — breaks tsc --noEmit"], "hardcoded": ["30-34: REACTION_WEIGHTS love_it:5, works_for_me:1, not_for_me:-3", "161-170: DEFAULT_SPACE_CONFIG groupFavoriteThreshold:80"], "test_coverage": "algo/src/__tests__/backwards-compat.test.ts" },
        { "path": "algo/src/service/decision-service.ts", "lines": 594, "status": "REAL", "evidence": "Stateless orchestrator. Auth + persistence + events + cache + optimistic concurrency.", "todos": [], "stubs": ["31/37: duplicate GroupId imports — breaks tsc"], "hardcoded": ["115: cacheTtlMs default 60000 (1min)"], "test_coverage": "algo/src/__tests__/decision-service.test.ts (17 tests)" },
        { "path": "algo/src/service/request-handler.ts", "lines": 374, "status": "REAL", "evidence": "Framework-agnostic HTTP router. 18 routes. Proper HTTP status codes.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "algo/src/__tests__/request-handler.test.ts (22 tests)" },
        { "path": "algo/src/ports/persistence.ts", "lines": 57, "status": "INTERFACE_ONLY", "evidence": "PersistencePort interface (12 methods) + VersionConflictError.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "N/A" },
        { "path": "algo/src/ports/event-bus.ts", "lines": 38, "status": "INTERFACE_ONLY", "evidence": "EventBusPort interface.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "N/A" },
        { "path": "algo/src/ports/auth.ts", "lines": 55, "status": "INTERFACE_ONLY", "evidence": "AuthPort interface. 10 action types.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "N/A" },
        { "path": "algo/src/ports/cache.ts", "lines": 35, "status": "INTERFACE_ONLY", "evidence": "CachePort interface.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "N/A" },
        { "path": "algo/src/ports/messaging.ts", "lines": 100, "status": "INTERFACE_ONLY", "evidence": "MessagingPort interface (5 methods).", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "N/A" },
        { "path": "algo/src/adapters/memory-persistence.ts", "lines": 137, "status": "REAL", "evidence": "Full CRUD with structuredClone isolation. Version conflict checks. Cascade delete.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "algo/src/__tests__/adapters.test.ts (35 tests)" },
        { "path": "algo/src/adapters/memory-event-bus.ts", "lines": 73, "status": "REAL", "evidence": "In-process pub/sub. Subscriber isolation. Unsubscribe.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "algo/src/__tests__/adapters.test.ts" },
        { "path": "algo/src/adapters/memory-cache.ts", "lines": 64, "status": "REAL", "evidence": "Map-based with TTL expiry. Prefix delete.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "algo/src/__tests__/adapters.test.ts" },
        { "path": "algo/src/adapters/noop-auth.ts", "lines": 38, "status": "REAL", "evidence": "Dev adapter. Trusts token as userId. Authorizes everything.", "todos": [], "stubs": ["23: 'Trust the token as userId. Replace with real validation.'"], "hardcoded": ["36: authorize always returns true"], "test_coverage": "algo/src/__tests__/adapters.test.ts" },
        { "path": "algo/src/adapters/plaintext-messaging.ts", "lines": 174, "status": "REAL", "evidence": "Full MessagingPort impl. 8 slash commands parsed.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "algo/src/__tests__/adapters.test.ts" },
        { "path": "algo/src/index.ts", "lines": 131, "status": "REAL", "evidence": "Barrel export. Duplicate GroupId on line 23.", "todos": [], "stubs": ["23: duplicate GroupId export — breaks tsc"], "hardcoded": [], "test_coverage": "N/A" }
      ],
      "execution_paths": [
        {
          "name": "Full decision lifecycle (in-memory)",
          "steps": [
            "engine.createSpace({title, members}) → space with UUID ID",
            "engine.addItem(groupId, {title, category}) → item with UUID ID",
            "engine.react(groupId, itemId, userId, LoveIt) → score recalculated",
            "engine.getRankedItems(groupId) → sorted by weighted score",
            "engine.lock(groupId, itemId, userId, proof) → state=locked, ownership stamped",
            "engine.getGroundingContext(groupId) → locked items as constraints"
          ],
          "breaks_at": null,
          "verdict": "WORKS (in single process, in-memory only)"
        },
        {
          "name": "HTTP API request flow",
          "steps": [
            "POST /spaces → RequestHandler.handle() → DecisionService.createSpace()",
            "AuthPort.authenticate(token) → NoopAuthAdapter trusts token",
            "PersistencePort.saveSpace() → MemoryPersistenceAdapter saves to Map",
            "EventBusPort.publish() → MemoryEventBusAdapter broadcasts",
            "Response: {status: 201, body: {space}}"
          ],
          "breaks_at": "No server.ts exists — RequestHandler is framework-agnostic but nothing calls listen()",
          "verdict": "WORKS as library, NOT as deployable service"
        }
      ],
      "blocking_issues": [
        { "severity": "CRITICAL", "file": "algo/src/models/types.ts", "line": 15, "description": "Duplicate GroupId declaration. Propagates to 4 files. tsc --noEmit produces 26 errors. npm run build FAILS." },
        { "severity": "CRITICAL", "file": "N/A", "line": 0, "description": "ZERO production adapters. Only in-memory persistence/events/cache. Data lost on restart." },
        { "severity": "HIGH", "file": "N/A", "line": 0, "description": "No HTTP server entry point. RequestHandler exists but nothing binds to a port." },
        { "severity": "HIGH", "file": "algo/src/adapters/noop-auth.ts", "line": 36, "description": "NoopAuth authorizes everything. No JWT/OAuth. Zero security." }
      ],
      "missing_for_b2b": [
        "Fix duplicate GroupId in types.ts:15 (15-minute fix, unblocks build)",
        "PostgreSQL persistence adapter implementing PersistencePort",
        "Redis event bus adapter implementing EventBusPort",
        "Redis cache adapter implementing CachePort",
        "JWT auth adapter implementing AuthPort",
        "server.ts entry point (Express/Fastify/Hono)",
        "Database migrations for persistence schema",
        "Input validation layer (zod schemas)",
        "Logging + OpenTelemetry",
        "Rate limiting middleware"
      ]
    },

    {
      "id": "xpensly-sdk",
      "name": "Xpensly Expense SDK",
      "verdict": "CORE_WORKS",
      "can_demo": true,
      "can_sell": false,
      "reason": "Split calculator, settlement engine, debt simplifier all use correct cent-based arithmetic. 85 tests pass with real numeric assertions. But no database adapter exists. Stripe/Razorpay are fake. 8 web API routes are stubs.",
      "platforms": ["dart", "web", "flutter"],
      "files": [
        { "path": "xpensly/xpensly_core/lib/src/engine/split_calculator.dart", "lines": 203, "status": "REAL", "evidence": "4 split modes with cent-based rounding. Greedy creditor/debtor debt resolution.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "xpensly/xpensly_core/test/engine/split_calculator_test.dart" },
        { "path": "xpensly/xpensly_core/lib/src/engine/settlement_engine.dart", "lines": 358, "status": "REAL", "evidence": "Multi-currency via CurrencyConverter. Refunds, prior settlements, computeAsOf().", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "xpensly/xpensly_core/test/engine/settlement_engine_test.dart" },
        { "path": "xpensly/xpensly_core/lib/src/engine/debt_simplifier.dart", "lines": 97, "status": "REAL", "evidence": "Net-balance greedy algorithm. simplify() + pairwise().", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "xpensly/xpensly_core/test/engine/debt_simplifier_test.dart" },
        { "path": "xpensly/xpensly_core/lib/src/engine/currency_converter.dart", "lines": 44, "status": "REAL", "evidence": "amount * (toRate / fromRate). Rate validation. Same-currency passthrough.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "xpensly/xpensly_core/test/engine/currency_converter_test.dart" },
        { "path": "xpensly/xpensly_core/lib/src/engine/recurrence_expander.dart", "lines": 64, "status": "REAL", "evidence": "Daily/weekly/monthly. DateTime overflow handling.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "xpensly/xpensly_core/test/engine/recurrence_expander_test.dart" },
        { "path": "xpensly/xpensly_core/lib/src/engine/trip_aggregator.dart", "lines": 230, "status": "REAL", "evidence": "Full analytics: by currency, category, phase, member, timeline.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "xpensly/xpensly_core/test/engine/trip_aggregator_test.dart" },
        { "path": "xpensly/xpensly_core/lib/src/adapters/in_memory_data_source.dart", "lines": 277, "status": "REAL", "evidence": "Full XpenslyDataSource CRUD. Filtering by category/phase/paidBy/date/tags.", "todos": [], "stubs": [], "hardcoded": ["27: IDs use 'mem_' prefix with auto-increment"], "test_coverage": "xpensly/xpensly_core/test/engine/in_memory_data_source_test.dart" },
        { "path": "xpensly/xpensly_core/lib/src/adapters/venmo_payment.dart", "lines": 41, "status": "REAL", "evidence": "venmo://paycharge deep links. Correct URI scheme.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "xpensly/xpensly_core/lib/src/adapters/upi_payment.dart", "lines": 53, "status": "REAL", "evidence": "upi://pay URIs per NPCI spec. QR-capable.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "xpensly/xpensly_core/lib/src/adapters/paypal_payment.dart", "lines": 39, "status": "REAL", "evidence": "paypal.me/{user}/{amount} URLs.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "xpensly/xpensly_core/lib/src/adapters/stripe_payment.dart", "lines": 43, "status": "STUB", "evidence": "Lines 1-9: doc comment says 'placeholder URL for demonstration and testing purposes only'. Line 29: fake https://checkout.stripe.com/pay URL.", "todos": [], "stubs": ["29: generates non-functional placeholder URL — real Stripe requires server-side session"], "hardcoded": ["29: https://checkout.stripe.com/pay?amount=... (fake URL)"], "test_coverage": "NONE" },
        { "path": "xpensly/xpensly_core/lib/src/adapters/razorpay_payment.dart", "lines": 49, "status": "STUB", "evidence": "Lines 1-9: doc comment says 'placeholder URL for demonstration and testing purposes'. Line 29: fake https://rzp.io/pay URL.", "todos": [], "stubs": ["29: generates non-functional placeholder URL — real Razorpay requires server-side order"], "hardcoded": ["29: https://rzp.io/pay?amount=... (fake URL)"], "test_coverage": "NONE" },
        { "path": "web/src/app/api/xpensly/calculate/route.ts", "lines": 51, "status": "REAL", "evidence": "Calls computeSettlement() with real TS engine.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "web/src/app/api/xpensly/split/route.ts", "lines": 54, "status": "REAL", "evidence": "Calls calculateSplit() with real engine.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "web/src/app/api/xpensly/simplify/route.ts", "lines": 32, "status": "REAL", "evidence": "Calls simplifyDebts() or pairwiseDebts().", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "web/src/app/api/xpensly/convert/route.ts", "lines": 60, "status": "REAL", "evidence": "Calls convert() from real engine.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "web/src/app/api/xpensly/trip/route.ts", "lines": 35, "status": "STUB", "evidence": "Line 20: '// TODO: Store trip in database'. Line 21: generates fake trip_${Date.now()} ID.", "todos": ["3: // TODO: Integrate with database", "20: // TODO: Store trip in database"], "stubs": ["21: returns fake tripId, no persistence"], "hardcoded": ["21: tripId = `trip_${Date.now()}`"], "test_coverage": "NONE" },
        { "path": "web/src/app/api/xpensly/trip/[tripId]/route.ts", "lines": 63, "status": "STUB", "evidence": "GET returns fake data. PATCH returns {updated:true}. DELETE returns {deleted:true}. No DB.", "todos": ["3,13,35,55: 4 TODO comments about database integration"], "stubs": ["14-20: GET returns fake trip data", "37-39: PATCH no-op", "56-57: DELETE no-op"], "hardcoded": ["14: name: `Trip ${tripId}`, currency: 'USD', members: [], expenses: []"], "test_coverage": "NONE" },
        { "path": "web/src/app/api/xpensly/trip/[tripId]/expense/route.ts", "lines": 106, "status": "PARTIAL", "evidence": "POST runs real calculateSplit() but line 94: '// TODO: Store expense in database'. GET returns empty array.", "todos": ["5,21,94: 3 TODO comments about database"], "stubs": ["22-29: GET returns expenses:[]", "94: POST never persists"], "hardcoded": ["46: fake exp_${Date.now()} ID"], "test_coverage": "NONE" },
        { "path": "web/src/app/api/xpensly/trip/[tripId]/settle/route.ts", "lines": 58, "status": "STUB", "evidence": "Line 35: '// TODO: Store settlement record in database'. Returns fake settlementId.", "todos": ["3,35: 2 TODO comments about database"], "stubs": ["36: returns fake stl_${Date.now()} ID, no persistence"], "hardcoded": ["36: settlementId = `stl_${Date.now()}`"], "test_coverage": "NONE" },
        { "path": "web/src/app/api/xpensly/lib/settlement-engine.ts", "lines": 195, "status": "REAL", "evidence": "TS port of Dart engine. Same algorithm.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "web/src/app/api/xpensly/lib/split-calculator.ts", "lines": 204, "status": "REAL", "evidence": "TS port. All 4 split modes with cent rounding.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "web/src/app/api/xpensly/lib/debt-simplifier.ts", "lines": 86, "status": "REAL", "evidence": "TS port. simplifyDebts + pairwiseDebts.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "xpensly/xpensly_ui/lib/src/widgets/xpensly_dashboard.dart", "lines": 334, "status": "REAL", "evidence": "Loads from dataSource. 3 tabs. FAB for expense entry.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "xpensly/xpensly_ui/test/xpensly_dashboard_test.dart" },
        { "path": "xpensly/xpensly_ui/lib/src/widgets/expense_entry.dart", "lines": 327, "status": "REAL", "evidence": "Full form. Multi-payer chips. Split mode toggle. Calls onSubmit with Expense.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "xpensly/xpensly_ui/test/expense_entry_test.dart" },
        { "path": "xpensly/xpensly_ui/lib/src/widgets/settlement_card.dart", "lines": 210, "status": "REAL", "evidence": "Ledger entries, balance bars, simplified/pairwise toggle.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "xpensly/xpensly_ui/test/settlement_card_test.dart" }
      ],
      "execution_paths": [
        {
          "name": "Calculate expense split (stateless)",
          "steps": [
            "POST /api/xpensly/split with {members, amount, mode}",
            "split-calculator.ts:calculateSplit() — REAL cent-based math",
            "Returns {splits: [{member, amount}]}"
          ],
          "breaks_at": null,
          "verdict": "WORKS"
        },
        {
          "name": "Full trip settlement (stateless)",
          "steps": [
            "POST /api/xpensly/calculate with {expenses, members, rates}",
            "settlement-engine.ts:computeSettlement() — REAL multi-currency",
            "Returns {ledger, rawDeltas, simplifiedDeltas, stats}"
          ],
          "breaks_at": null,
          "verdict": "WORKS"
        },
        {
          "name": "Create trip and add expense (stateful)",
          "steps": [
            "POST /api/xpensly/trip — returns fake tripId (trip_1712345678)",
            "POST /api/xpensly/trip/{id}/expense — runs real split calc",
            "BUT: '// TODO: Store expense in database' — never persists",
            "GET /api/xpensly/trip/{id}/expense — returns empty array"
          ],
          "breaks_at": "trip/route.ts:21 and expense/route.ts:94 — no database, data vanishes",
          "verdict": "DOES NOT WORK (calculation works, persistence doesn't)"
        },
        {
          "name": "Flutter in-memory flow",
          "steps": [
            "Xpensly(dataSource: InMemoryDataSource())",
            "XpenslyDashboard loads from dataSource.fetchExpenses()",
            "ExpenseEntry form → onSubmit → dataSource.addExpense()",
            "computeTripSettlement() → real math",
            "SettlementCard renders results"
          ],
          "breaks_at": "Data lost when app closes (InMemoryDataSource)",
          "verdict": "WORKS in-session, no persistence"
        }
      ],
      "blocking_issues": [
        { "severity": "CRITICAL", "file": "N/A", "line": 0, "description": "No SupabaseDataSource exists. InMemoryDataSource is the only implementation. All data lost on restart." },
        { "severity": "HIGH", "file": "xpensly/xpensly_core/lib/src/adapters/stripe_payment.dart", "line": 29, "description": "Stripe adapter generates fake checkout.stripe.com URL. Real Stripe requires server-side session creation." },
        { "severity": "HIGH", "file": "xpensly/xpensly_core/lib/src/adapters/razorpay_payment.dart", "line": 29, "description": "Razorpay adapter generates fake rzp.io URL. Real Razorpay requires server-side order creation." },
        { "severity": "HIGH", "file": "web/src/app/api/xpensly/trip/route.ts", "line": 21, "description": "8 trip CRUD routes return mock data with timestamp IDs. No database writes." },
        { "severity": "MEDIUM", "file": "N/A", "line": 0, "description": "No live exchange rate API. Only FixedRateProvider with hardcoded rates." }
      ],
      "missing_for_b2b": [
        "SupabaseDataSource implementing XpenslyDataSource (+ 8 Supabase tables)",
        "Real Stripe adapter with server-side Checkout Sessions",
        "Real Razorpay adapter with server-side Order creation",
        "Wire 8 trip CRUD routes to Supabase",
        "Live exchange rate provider (OpenExchangeRates API)",
        "Auth + RLS policies for trip-level permissions",
        "Audit logging for expense changes"
      ]
    },

    {
      "id": "sesame-multi-device",
      "name": "Sesame Multi-Device Protocol",
      "verdict": "DOES_NOT_WORK",
      "can_demo": false,
      "can_sell": false,
      "reason": "DB tables exist. Everything above is abstract interfaces or a TODO barrel file. Messages hardcoded to device 1.",
      "platforms": ["dart", "web", "db"],
      "files": [
        { "path": "engine/lib/src/devices/device_registry.dart", "lines": 53, "status": "INTERFACE_ONLY", "evidence": "Abstract class. Zero implementation.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "engine/lib/src/devices/device_linking.dart", "lines": 95, "status": "INTERFACE_ONLY", "evidence": "Abstract class + data classes. Zero implementation.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "engine/lib/src/devices/devices.dart", "lines": 8, "status": "STUB", "evidence": "Line 7: '// TODO(phase2): Implement DeviceRegistry, DeviceLinkingProtocol, and KeyRotationService.'", "todos": ["7: // TODO(phase2)"], "stubs": ["Barrel file, no re-exports"], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "web/src/lib/crypto/device-registry.ts", "lines": 42, "status": "REAL", "evidence": "Thin Supabase RPC wrappers.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "web/src/lib/crypto/device-linking.ts", "lines": 37, "status": "INTERFACE_ONLY", "evidence": "Types and JSON encode/decode only. No protocol logic.", "todos": [], "stubs": ["No actual linking protocol"], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "web/supabase/migrations/20260327190001_user_devices.sql", "lines": 95, "status": "REAL", "evidence": "CREATE TABLE, RLS policies, 5-device limit trigger, 3 RPCs.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "engine/lib/src/domain/use_cases/send_message_use_case.dart", "lines": 480, "status": "SEE_E2EE_MODULE", "evidence": "Line 141: const recipientDeviceId = 1 — hardcoded single device.", "todos": [], "stubs": ["141: no multi-device fan-out"], "hardcoded": ["141: recipientDeviceId = 1"], "test_coverage": "NONE for multi-device" }
      ],
      "execution_paths": [
        {
          "name": "Link new device",
          "steps": [
            "DeviceLinking abstract class has method signatures",
            "No concrete implementation exists",
            "STOPS at interface boundary"
          ],
          "breaks_at": "engine/lib/src/devices/device_linking.dart — abstract class, no implementation",
          "verdict": "DOES NOT WORK"
        },
        {
          "name": "Send to multi-device recipient",
          "steps": [
            "SendMessageUseCase encrypts message",
            "Line 141: const recipientDeviceId = 1",
            "Only device 1 receives ciphertext",
            "Devices 2-5 never get the message"
          ],
          "breaks_at": "send_message_use_case.dart:141 — hardcoded to device 1",
          "verdict": "DOES NOT WORK"
        }
      ],
      "blocking_issues": [
        { "severity": "CRITICAL", "file": "engine/lib/src/devices/devices.dart", "line": 7, "description": "Entire Dart device layer is TODO(phase2). No implementation." },
        { "severity": "CRITICAL", "file": "engine/lib/src/domain/use_cases/send_message_use_case.dart", "line": 141, "description": "recipientDeviceId = 1 hardcoded. Multi-device encryption not implemented." },
        { "severity": "CRITICAL", "file": "web/src/lib/crypto/device-linking.ts", "line": 0, "description": "Types only. No QR generation, no key transfer, no history sync, no verification protocol." }
      ],
      "missing_for_b2b": [
        "Concrete DeviceRegistry implementation (Dart)",
        "QR-based device linking protocol with encrypted history transfer",
        "Multi-device fan-out in send path (query devices, encrypt to each)",
        "Sender key rotation on device unlink",
        "Key rotation service"
      ]
    },

    {
      "id": "ai-intelligence",
      "name": "AI Intelligence Orchestrator (@hello)",
      "verdict": "WORKS_E2E",
      "can_demo": true,
      "can_sell": true,
      "reason": "3-tier routing with real Gemini/SearchApi/Apify calls. Native function calling. Self-healing retry. Production-grade /api/hello route. Only dependency: valid API keys.",
      "platforms": ["web"],
      "files": [
        { "path": "web/src/lib/intelligence/orchestrator.ts", "lines": 762, "status": "REAL", "evidence": "Full 3-tier: gemini-local → gemini-search → SearchApi → Apify. 10 function declarations. Self-healing retry.", "todos": [], "stubs": [], "hardcoded": ["18: GEMINI_TIMEOUT_MS = 45000", "19: MAX_RESPONSE_LENGTH = 500", "177: 'gemini-2.5-flash'"], "test_coverage": "web/src/lib/__tests__/sanitize.test.ts (sanitizer only)" },
        { "path": "web/src/lib/intelligence/tool-registry.ts", "lines": 238, "status": "REAL", "evidence": "8 registered tools with real Apify actor IDs. SearchApi engine mapping.", "todos": [], "stubs": [], "hardcoded": ["163-238: Apify actor IDs (voyager/booking-scraper, compass/crawler-google-places)"], "test_coverage": "NONE" },
        { "path": "web/src/lib/intelligence/searchapi-client.ts", "lines": 205, "status": "REAL", "evidence": "Real HTTP calls to searchapi.io. Google Hotels/Flights/Local result parsing.", "todos": [], "stubs": [], "hardcoded": ["15: API_BASE = 'https://www.searchapi.io/api/v1/search'", "31: 15s timeout"], "test_coverage": "NONE" },
        { "path": "web/src/lib/intelligence/apify-client.ts", "lines": 176, "status": "REAL", "evidence": "Real ApifyClient from apify-client package. Sync/async actor runs.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "web/src/lib/intelligence/sanitize.ts", "lines": 78, "status": "REAL", "evidence": "PII redaction: credit cards (Luhn), SSN, CVV, bank routing.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "web/src/lib/__tests__/sanitize.test.ts" },
        { "path": "web/src/app/api/hello/route.ts", "lines": 442, "status": "REAL", "evidence": "POST handler. Auth + grounding context + taste intersection + orchestrate() + Pexels images.", "todos": [], "stubs": [], "hardcoded": ["17: MAX_MESSAGE_LENGTH = 1000", "22-29: CATEGORY_FALLBACKS Pexels URLs"], "test_coverage": "NONE" }
      ],
      "execution_paths": [
        {
          "name": "User asks @hello for hotel recommendations",
          "steps": [
            "POST /api/hello with {message: '@hello find hotels in Bali', spaceId}",
            "verifyAuth() → JWT check",
            "buildGroundingContext() → locked decisions as constraints",
            "orchestrate(intent, context) → Gemini native function calling",
            "Gemini returns search_hotel({location: 'Bali'}) function call",
            "tool-registry routes to SearchApi google_hotels engine",
            "searchapi-client.ts hits searchapi.io → returns real hotel results",
            "Quality gate filters garbage responses",
            "Response: {places: [...], tier: 'searchapi', model: 'gemini-2.5-flash'}"
          ],
          "breaks_at": null,
          "verdict": "WORKS (requires GEMINI_API_KEY + SEARCHAPI_API_KEY env vars)"
        }
      ],
      "blocking_issues": [
        { "severity": "LOW", "file": "web/src/lib/intelligence/orchestrator.ts", "line": 0, "description": "No unit tests for orchestrator itself. Only sanitize.test.ts." }
      ],
      "missing_for_b2b": [
        "Unit tests for orchestrator logic (mock API responses)",
        "Rate limiting per-user for AI calls",
        "Cost tracking per orchestration tier"
      ]
    },

    {
      "id": "discovery-engine",
      "name": "Discovery Engine",
      "verdict": "STUB",
      "can_demo": false,
      "can_sell": false,
      "reason": "ProviderRegistry architecture is real. But 2/3 providers are stubs (template strings / empty arrays). SeededCatalog returns 14 hardcoded mock items. In production returns fake data.",
      "platforms": ["web"],
      "files": [
        { "path": "web/src/lib/discovery/provider-registry.ts", "lines": 98, "status": "REAL", "evidence": "Multi-provider registry. Priority search. Dedup by title+location.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "web/tests/discovery/discovery-api.test.ts" },
        { "path": "web/src/lib/discovery/providers/seeded-catalog.ts", "lines": 340, "status": "MOCK", "evidence": "Lines 8-258: 14 hardcoded items (Rome/Paris/NYC/Barcelona). Fake URLs, phone +1-555-0100.", "todos": [], "stubs": [], "hardcoded": ["8-258: 14 mock items with fake data"], "test_coverage": "web/tests/discovery/discovery-api.test.ts" },
        { "path": "web/src/lib/discovery/providers/gemini-enrichment.ts", "lines": 109, "status": "STUB", "evidence": "Line 11: 'TODO: integrate with existing /api/hello 3-tier intelligence'. Lines 37-79: returns 3 template items like 'AI Pick: Best {category}'.", "todos": ["11: TODO: integrate with /api/hello", "106: TODO: ping Gemini API health endpoint"], "stubs": ["37-79: returns canned template data, no Gemini API call"], "hardcoded": ["37: 'AI Pick: Best ${category}' template"], "test_coverage": "NONE" },
        { "path": "web/src/lib/discovery/providers/apify-scraping.ts", "lines": 37, "status": "STUB", "evidence": "Line 24: search() returns []. Line 29: getDetail() returns null. Line 34: health 'degraded'.", "todos": ["11: TODO: integrate with existing algo/src/apify-fetch.ts"], "stubs": ["24: search returns empty array", "29: getDetail returns null"], "hardcoded": [], "test_coverage": "NONE" }
      ],
      "execution_paths": [
        {
          "name": "Discovery feed request",
          "steps": [
            "GET /api/discovery/feed?category=restaurants",
            "ProviderRegistry.search() runs all providers in parallel",
            "SeededCatalogProvider returns 3 hardcoded Rome restaurants",
            "GeminiEnrichmentProvider returns 3 template 'AI Pick' items",
            "ApifyScrapingProvider returns []",
            "Deduplicated results = 6 fake items"
          ],
          "breaks_at": "All data is fake/hardcoded",
          "verdict": "RETURNS DATA but it's all mock"
        }
      ],
      "blocking_issues": [
        { "severity": "CRITICAL", "file": "web/src/lib/discovery/providers/gemini-enrichment.ts", "line": 37, "description": "Returns template strings, no API calls. Real Gemini integration exists in intelligence/orchestrator.ts but not wired here." },
        { "severity": "CRITICAL", "file": "web/src/lib/discovery/providers/apify-scraping.ts", "line": 24, "description": "Returns empty arrays. Real Apify integration exists in intelligence/apify-client.ts but not wired here." }
      ],
      "missing_for_b2b": [
        "Wire GeminiEnrichmentProvider to intelligence/orchestrator.ts",
        "Wire ApifyScrapingProvider to intelligence/apify-client.ts",
        "Replace SeededCatalog mock data with real provider or remove"
      ]
    },

    {
      "id": "offline-sync-engine",
      "name": "Offline-First Sync Engine",
      "verdict": "PARTIALLY_WORKS",
      "can_demo": false,
      "can_sell": false,
      "reason": "All sync components have real Drift queries and logic. 13 tables, SQLCipher encryption on native. But no integration test proves the full offline-to-online cycle. Web has no DB encryption. Identity key returns zeros.",
      "platforms": ["dart"],
      "files": [
        { "path": "engine/lib/src/sync/sync_coordinator.dart", "lines": 387, "status": "REAL", "evidence": "Orchestrates outbox, watermark, gap detection, conflict resolution, realtime subscriptions, background uploader.", "todos": [], "stubs": ["331: getIdentityKeyForConversation returns Uint8List(30) zeros"], "hardcoded": [], "test_coverage": "NONE (no integration test)" },
        { "path": "engine/lib/src/sync/outbox_worker.dart", "lines": 255, "status": "REAL", "evidence": "Timer-based drain. Per-group serial, cross-group concurrent. Exponential backoff, 10 max retries.", "todos": [], "stubs": [], "hardcoded": ["43: maxRetries = 10", "46: _baseBackoffSeconds = 2"], "test_coverage": "NONE" },
        { "path": "engine/lib/src/sync/watermark_sync.dart", "lines": 137, "status": "REAL", "evidence": "Pages from server watermark. Bulk insert with dedup. Updates watermark per page (crash-safe).", "todos": [], "stubs": [], "hardcoded": ["28: _pageLimit = 100"], "test_coverage": "NONE" },
        { "path": "engine/lib/src/sync/gap_detector.dart", "lines": 59, "status": "REAL", "evidence": "Fetches newer messages from server based on latest local timestamp.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "engine/lib/src/sync/conflict_resolver.dart", "lines": 117, "status": "REAL", "evidence": "reconcileOutboxMessage, reconcileGap (batch upsert), cleanupStaleMessages (24h threshold).", "todos": [], "stubs": [], "hardcoded": ["97: 24h stale threshold"], "test_coverage": "NONE" },
        { "path": "engine/lib/src/sync/deduplication_set.dart", "lines": 37, "status": "REAL", "evidence": "LRU set, 1000-entry cap, FIFO eviction.", "todos": [], "stubs": [], "hardcoded": ["8: maxSize = 1000"], "test_coverage": "NONE" },
        { "path": "engine/lib/src/sync/clock_sync.dart", "lines": 34, "status": "REAL", "evidence": "NTP-lite via HTTP Date header.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "engine/lib/src/persistence/database/tables.dart", "lines": 385, "status": "REAL", "evidence": "13 Drift table definitions. All columns, types, primary keys.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "engine/lib/src/persistence/database/database_factory_native.dart", "lines": 24, "status": "REAL", "evidence": "SQLCipher with PRAGMA key and cipher_compatibility=4.", "todos": [], "stubs": [], "hardcoded": ["10: 'e2ee_chat.db'"], "test_coverage": "NONE" },
        { "path": "engine/lib/src/persistence/database/database_factory_web.dart", "lines": 12, "status": "REAL", "evidence": "WasmDatabase — NO encryption on web.", "todos": [], "stubs": ["No key parameter — web DB is unencrypted"], "hardcoded": ["6: 'e2ee_chat'", "7: 'sqlite3.wasm'"], "test_coverage": "NONE" },
        { "path": "engine/lib/src/persistence/repositories/message_repository_impl.dart", "lines": 291, "status": "REAL", "evidence": "Full Drift CRUD: save, batch, paginate, search, watchMessages stream.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "engine/lib/src/persistence/repositories/outbox_repository_impl.dart", "lines": 74, "status": "REAL", "evidence": "Full Drift CRUD: enqueue, getPending, markSent, markFailed.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" }
      ],
      "execution_paths": [
        {
          "name": "Offline message send + sync",
          "steps": [
            "User sends message while offline",
            "OutboxRepository.enqueue() saves to Drift DB",
            "OutboxWorker timer fires every 2s",
            "Worker calls MessageGateway.send() — fails (offline)",
            "Exponential backoff: 2s, 4s, 8s...",
            "Network reconnects",
            "Worker retries — MessageGateway.send() succeeds",
            "OutboxRepository.markSent(serverSeq)",
            "WatermarkSync.syncAll() pages from server watermark",
            "ConflictResolver.reconcileGap() upserts missed messages"
          ],
          "breaks_at": "NO INTEGRATION TEST EXISTS to prove this full cycle",
          "verdict": "THEORETICALLY WORKS — never tested end-to-end"
        }
      ],
      "blocking_issues": [
        { "severity": "HIGH", "file": "N/A", "line": 0, "description": "No integration test proves offline → online → sync → conflict resolve cycle." },
        { "severity": "HIGH", "file": "engine/lib/src/persistence/database/database_factory_web.dart", "line": 6, "description": "Web WasmDatabase has no encryption. Local messages stored in plaintext on web." },
        { "severity": "MEDIUM", "file": "engine/lib/src/sync/sync_coordinator.dart", "line": 331, "description": "getIdentityKeyForConversation returns Uint8List(30) zeros — safety number verification shows fake fingerprint." }
      ],
      "missing_for_b2b": [
        "Integration test: offline enqueue → reconnect → drain → watermark fill → conflict resolve",
        "Web DB encryption (encrypt WasmDatabase or document limitation)",
        "Real identity key lookup for safety number verification"
      ]
    },

    {
      "id": "consensus-voting-ui",
      "name": "Consensus/Voting Widget Kit",
      "verdict": "PARTIALLY_WORKS",
      "can_demo": true,
      "can_sell": false,
      "reason": "Flutter DecisionBoard is wired to engine. Web DecisionBoard queries Supabase directly (violates iron rule). Locking uses mock proofs. Not a standalone package.",
      "platforms": ["dart", "web"],
      "files": [
        { "path": "app/lib/demov2/decision_board.dart", "lines": 121, "status": "REAL", "evidence": "Wired to ChatEngineDecisions.getDecisionItems(). Groups by category. Sorts by weighted score.", "todos": [], "stubs": ["109: CommitmentProof(type: 'mock', value: 'booked')"], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "app/lib/demov2/swim_lane_rail.dart", "lines": 147, "status": "REAL", "evidence": "Horizontal scroll with 72% width cards. Vital labels computed.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "app/lib/demov2/plans_view.dart", "lines": 996, "status": "REAL", "evidence": "3-tier hierarchy. Category pills. Wired to engine.", "todos": [], "stubs": ["961: CommitmentProof(type: 'mock', value: 'booked')"], "hardcoded": ["79: MockDataSeed.displayNames"], "test_coverage": "NONE" },
        { "path": "app/lib/demov2/gold_burst.dart", "lines": 103, "status": "REAL", "evidence": "40 gold particles on consensus >=80%. Pure animation.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "app/lib/demov2/group_summary_card.dart", "lines": 124, "status": "REAL", "evidence": "Dashboard: item counts, votes, locked decisions.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" },
        { "path": "app/lib/demov2/add_item_sheet.dart", "lines": 194, "status": "PARTIAL", "evidence": "UI complete. Uses demo asset images.", "todos": [], "stubs": [], "hardcoded": ["24-31: 6 hardcoded demo asset paths"], "test_coverage": "NONE" },
        { "path": "app/lib/demov2/time_scrubber.dart", "lines": 356, "status": "MOCK", "evidence": "Lines 14-30: 15 hardcoded mock events. Lines 179/259/333/344: fontWeight w600-w900 VIOLATES No-Bold mandate.", "todos": [], "stubs": ["14-30: fully hardcoded mock event data"], "hardcoded": ["14-30: mock events", "41: hardcoded years 2020-2024", "179: fontWeight w800 (VIOLATES mandate)", "259: fontWeight w900 (VIOLATES mandate)"], "test_coverage": "NONE" },
        { "path": "app/lib/widgets/action_card_widget.dart", "lines": 423, "status": "REAL", "evidence": "Decision card. Spring physics. 3-signal voting. Gold burst integration.", "todos": [], "stubs": [], "hardcoded": [], "test_coverage": "NONE" }
      ],
      "execution_paths": [
        {
          "name": "Flutter: view and vote on decision items",
          "steps": [
            "DecisionBoard calls engine.getDecisionItems(groupId)",
            "Items grouped by category, sorted by weighted score",
            "SwimLaneRail renders horizontal card scrolls",
            "User taps vote → engine.reactToItem(itemId, reaction)",
            "Score recalculated, UI rebuilds"
          ],
          "breaks_at": null,
          "verdict": "WORKS (data from engine, voting calls engine)"
        },
        {
          "name": "Flutter: lock a decision item",
          "steps": [
            "User long-press → lock action",
            "engine.lockItem(itemId, CommitmentProof(type: 'mock', value: 'booked'))",
            "Proof is hardcoded mock — no real booking confirmation"
          ],
          "breaks_at": "decision_board.dart:109 — mock proof, not real commitment",
          "verdict": "WORKS mechanically, but proof is fake"
        }
      ],
      "blocking_issues": [
        { "severity": "MEDIUM", "file": "app/lib/demov2/decision_board.dart", "line": 109, "description": "CommitmentProof always mock. No UI for real proof capture (screenshot, confirmation number)." },
        { "severity": "MEDIUM", "file": "app/lib/demov2/time_scrubber.dart", "line": 179, "description": "Uses fontWeight w800/w900 — violates No-Bold mandate (max w400)." },
        { "severity": "LOW", "file": "N/A", "line": 0, "description": "Not a standalone package. Deeply coupled to engine + app." }
      ],
      "missing_for_b2b": [
        "Real proof capture UI (camera → screenshot, manual confirmation number)",
        "Fix No-Bold violations in time_scrubber.dart",
        "Extract as standalone Flutter package with clean dependency on algo/",
        "Web component should use engine port, not direct Supabase queries"
      ]
    }
  ],

  "flutter_app_critical_findings": {
    "default_mode_is_mock": {
      "file": "app/lib/main.dart",
      "line": 19,
      "value": "const bool _useLiveEngine = false",
      "impact": "Entire app runs on MockChatEngine by default. Must change to env-based toggle."
    },
    "mock_files": [
      { "file": "app/lib/src/mock_chat_engine.dart", "lines": 331, "description": "Full mock of ChatEngine + ChatEngineDecisions. Hardcoded AI responses, fake invites." },
      { "file": "app/lib/src/mock_data_seed.dart", "lines": 813, "description": "All demo conversations, messages, decision items." },
      { "file": "app/lib/views/settings/profile_edit.dart", "lines": 147, "description": "Hardcoded 'Ram Chitturi'. No engine connection." },
      { "file": "app/lib/views/settings/device_list.dart", "lines": 141, "description": "3 hardcoded devices. No engine connection." },
      { "file": "app/lib/views/settings/device_linking_page.dart", "lines": 191, "description": "Simulated QR scan + fake handshake." },
      { "file": "app/lib/views/ai/spotlight_sheet.dart", "lines": 148, "description": "Hardcoded AI response. Fake SSE stream via Stream.periodic." },
      { "file": "app/lib/views/invite/claim_sheet.dart", "lines": 204, "description": "MockDeepLinkNotifier. No engine.claimInvite." },
      { "file": "app/lib/views/invite/invite_surface.dart", "lines": 179, "description": "MockQRPainter. No engine.generateInvite." },
      { "file": "app/lib/views/auth/auth_flow_page.dart", "lines": 374, "description": "Mock 1500ms delay. No real Firebase token exchange." }
    ],
    "test_coverage_gap": "Only app/test/discover/ tested (702 LOC). Auth, chat, settings, providers have ZERO tests."
  },

  "database_critical_findings": {
    "migrations_total": 44,
    "migrations_total_lines": 3411,
    "key_rpcs_status": {
      "send_e2ee_message": { "file": "20260327180002_atomic_send_message.sql", "lines": 110, "status": "REAL" },
      "user_devices_trigger": { "file": "20260327190001_user_devices.sql", "lines": 95, "status": "REAL" },
      "tombstone_message": { "file": "20260327180001_uuidv7_helpers.sql", "lines": 35, "status": "REAL" },
      "mark_group_read": { "file": "20260327180003_read_watermarks.sql", "lines": 31, "status": "REAL" }
    },
    "xpensly_tables": "NOT CREATED — 8 tables defined in spec but no migration exists"
  }
}
```
