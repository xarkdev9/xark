# Phase 2 — Next Steps

Items to implement after Phase 1 (Foundation) is complete and validated.

## Multi-Device Architecture
- Device registry: server-side `userId -> [deviceId1, deviceId2, ...]` mapping
- Device linking protocol: primary device transfers encrypted history to new device via local encrypted channel (QR code + proximity)
- Fan-out: sender encrypts and sends N ciphertexts (one per recipient device)
- Device limit enforcement: 1 primary + 4 linked devices max
- Device unlinking: revoke keys, rotate Sender Keys for all groups

## Contact Discovery
- Client-side SHA-256 hash truncation (first 10 bytes) of phone numbers
- Server intersection query: return only matching registered user hashes
- Batch and rate-limit discovery requests to prevent enumeration attacks
- Ephemeral server-side hash table (no permanent logging of discovery queries)

## Profile Metadata Encryption
- Generate 32-byte Profile Key per user
- Encrypt display name, status, and profile picture with Profile Key before upload
- Distribute Profile Key to verified contacts via E2EE message
- Profile Key rotation on contact removal, re-distribute to remaining contacts
- Generic placeholder rendering when Profile Key is unavailable

## Push Notification Native Extensions
- **iOS**: Notification Service Extension (Swift) — wake minimal crypto isolate, decrypt from shared Keychain (App Group), mutate `UNNotificationContent`, complete within 30s budget
- **Android**: `FirebaseMessagingService` (Kotlin) — decrypt in background worker, post local notification with plaintext content
- **Web**: Service Worker push event handler — decrypt and show `Notification`
- Fallback to generic "New Message" on decryption failure

## Voice Messages
- Opus encoding/decoding in background isolate
- Same media encryption pipeline as images/video (AES-256-GCM + E2EE key delivery)
- Raw PCM/Opus bytes exposed to UI via `MediaPayload` (no audio player in engine)

## Disappearing Messages
- Per-conversation timer configuration (off, 24h, 7d, 90d)
- Scheduler that deletes expired messages from local encrypted DB
- Timer metadata included in encrypted message payload
- Sync timer state across devices

## Link Preview Server-Side Proxy
- Engine sends URL to proxy server (avoids leaking client IP to target site)
- Proxy fetches Open Graph metadata, returns title + description + thumbnail
- Thumbnail encrypted via media pipeline before storage
- Preview metadata included in message payload (encrypted end-to-end)

## Message Forwarding
- Forward flag on `Message` model (preserves original sender attribution)
- Forwarded media re-uses existing encrypted blob URL (no re-upload)
- New AES key generated for forwarded media (re-encrypted for new recipient's ratchet)

## Starred Messages
- Local-only starred flag on `Message` model (not synced to server)
- Query interface: `getStarredMessages({int limit, int offset})`
- Exposed via `ChatEngine` public API

## App Lock (PIN / Biometric)
- Engine-level lock state: `locked` / `unlocked`
- DB access gated by unlock status
- Configurable auto-lock timeout (immediate, 1m, 5m, 30m)
- Lock event emitted on `ChatEngine.connectionState` stream

## Performance Benchmarking
Measure against CLAUDE.md targets:
- Message encrypt + enqueue: < 50ms
- Engine initialize to connected: < 2 seconds
- Incoming message decrypt + emit: < 20ms
- Incoming push decrypt (native extension): < 500ms
- Offline queue drain on reconnect: < 3 seconds for 50 msgs
- Encryption overhead per message: < 5ms on mid-range device
- Media encrypt (10MB file): < 500ms in background isolate

## Security Audit
- External review of Signal Protocol implementation (X3DH + Double Ratchet)
- Verify HKDF info string uniqueness and correctness
- Review key storage security (platform keychain usage)
- Audit for plaintext leakage in logs, error messages, or crash reports
- Verify forward secrecy guarantees under ratchet state recovery scenarios
- Review Sender Key rotation logic for group membership changes
