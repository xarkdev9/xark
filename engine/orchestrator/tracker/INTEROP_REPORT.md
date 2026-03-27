# Interop Test Report

**Date:** 2026-03-26
**Flutter engine:** ~/fe2ee (Phase 1 build)
**React app:** ~/xark9
**Supabase project:** ldnsxwkkxwztqyqkyuqa.supabase.co

## Results

| Test | Result | Notes |
|------|--------|-------|
| Crypto interop (offline, 11 tests) | ✅ PASS | All HKDF strings, pack formats, wire formats verified |
| Dev server reachable | ✅ PASS | HTTP 307 (redirect to login) |
| JWT for name_ram | ✅ PASS | 233 chars, obtained via /api/dev-auto-login |
| JWT for name_myna | ✅ PASS | 235 chars, obtained via /api/dev-auto-login |
| Flutter → Server (message written) | ✅ PASS | msg_a4399bc2-1911-480b-aa95-a6f1af0463b8 written to Supabase |
| Key bundle fetch (name_myna) | ✅ PASS | 404 = no keys registered yet (expected — React hasn't registered for this user) |

## Crypto Parameters Verified

- HKDF info strings: ✅ match — `XarkE2EE-x3dh`, `XarkE2EE-ratchet`, `XarkE2EE-header-secret`, `XarkE2EE-header-key`
- Pack format (nonce+ct): ✅ match — 24-byte nonce prefix verified
- Header encryption: ✅ match — nonce(24) + headerCiphertext, XChaCha20-Poly1305
- Group wire format: ✅ match — nonce(24) + sig(64) + iter(4 BE) + ct
- Chain KDF: ✅ match — 10 sequential + bidirectional exchange all decrypt
- Ed25519→Curve25519: ✅ deterministic, consistent
- Message payload JSON: ✅ match — text, type, replyTo, mediaUrl, aesKeyBase64, ivBase64, mimeType, inlineThumbnail
- Wire format (JSON fields): ✅ match — snake_case: space_id, sender_device_id, ciphertext, ratchet_header, recipient_id, recipient_device_id, message_type, distribution_ciphertexts

## Server Response Verified

```json
POST /api/message → 200
{
  "messageId": "msg_a4399bc2-1911-480b-aa95-a6f1af0463b8",
  "distribution_written": false
}
```

- `messageId` field present ✅
- `distribution_written` field present ✅
- Message row written to Supabase `messages` table ✅
- RLS passed (JWT `sub` = `name_ram`, member of `interop-test-space`) ✅

## Test Infrastructure Created

- `test/interop/crypto_interop_test.dart` — 11 offline crypto tests (no network)
- `test/interop/live_interop_test.dart` — 5 live tests (need dev server + env vars)
- Test space `interop-test-space` created in Supabase with members name_ram + name_myna
- Test users `name_ram` and `name_myna` seeded via service role key

## Failures

None. All 16 tests pass (11 offline + 5 live).

## Phase 1 Sign-Off

- [x] All offline crypto interop tests pass (11/11)
- [x] All live interop tests pass (5/5)
- [x] HKDF strings, pack formats, wire formats verified against CODEBASE_CONTEXT.md
- [x] Message successfully written to production Supabase via Flutter engine's envelope format
- [x] JWT auth flow works (dev-auto-login → Bearer token → RLS passes)
- [ ] Full E2E round-trip (Flutter encrypts → React decrypts) — requires React key registration + manual verification
