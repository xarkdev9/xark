# XARK OS E2EE — Security & Architecture Audit

**Date**: 2026-03-16
**Auditor**: Principal Cryptography Engineer (Signal/WhatsApp background)
**Scope**: Complete E2EE architecture, key management, multi-device routing, Web Worker attack surface, metadata analysis
**Method**: Specification review (SECURITY.md) + source code inspection (src/lib/crypto/*, src/app/api/message/*, src/workers/*, src/hooks/useE2EE.ts)
**Verdict**: Multiple P0/P1 vulnerabilities. System is NOT production-ready for security-conscious deployment.

---

## CRITICAL VULNERABILITIES (P0/P1)

### P0-1: IndexedDB KeyStore Is Plaintext — Complete Key Compromise on Device Access

**Finding**: `keystore.ts` stores all private keys (identity keys, signed pre-keys, Double Ratchet session state, Sender Keys) in IndexedDB with zero encryption. Raw base64 serialization via `toBase64(state)`. No encryption layer whatsoever.

**Impact**: Any extension with IndexedDB access, any XSS attack, any browser inspector access, or any device backup tool (iTunes, Android debug bridge) extracts every private key in plaintext. This destroys the entire E2EE security model.

**WhatsApp comparison**: WhatsApp stores keys in the Android Keystore / iOS Keychain (hardware-backed, OS-enforced isolation). Even a rooted device requires significant effort to extract keys. Xark's IndexedDB is readable by any JavaScript running on the same origin.

**Severity**: P0. A single XSS vulnerability in any third-party dependency (Framer Motion, Next.js, Supabase client) provides full read access to every private key the user possesses. Game over.

**Remediation**: Encrypt IndexedDB values with a key derived from Web Crypto `CryptoKey` (non-extractable, stored in `crypto.subtle`). This prevents JavaScript inspection of the raw key material. For v2, migrate to a native shell with OS-level keychain.

---

### P0-2: Memory Worker Indexes and Persists Plaintext — "Zero-Knowledge" Is False

**Finding**: `memory-worker.ts` receives decrypted plaintext messages from the main thread, indexes them in MiniSearch (RAM), and persists the entire index to IndexedDB as unencrypted JSON: `JSON.stringify({ messages: [...messages.values()], lastIndexedTimestamp })`.

**Impact**: All decrypted message content is stored in plaintext on disk via IndexedDB. An attacker who gains read access to the user's IndexedDB (same attack surface as P0-1) obtains the full message history in plaintext — rendering E2EE completely meaningless.

**The spec claims**: "Zero-knowledge" and "server never sees plaintext." True — but the CLIENT stores plaintext permanently. The security model is "zero-knowledge for the server" but "full-knowledge on the client disk, unencrypted."

**WhatsApp comparison**: WhatsApp's local message database (msgstore.db) on Android is encrypted with a key stored in the Android Keystore. A file system dump yields an encrypted blob, not plaintext. Signal uses SQLCipher for its local database.

**Severity**: P0. SECURITY.md Section 8 claims IndexedDB contents are "browser sandboxed." This is true — but it means any origin-same JavaScript can read them. The Worker persists plaintext messages indefinitely.

**Remediation**: Encrypt the Worker's IndexedDB blob with XChaCha20-Poly1305 using a key derived from the user's identity key. Decrypt only in the Worker's ephemeral RAM on load.

---

### P1-1: Ratchet Header Leaks Identity Key Material in Plaintext

**Finding**: `encryption-service.ts` (lines 148-151) embeds X3DH metadata in the ratchet header JSON:

```typescript
headerJson.x3dh = {
  identityKey: toBase64(identity.publicKey),
  ephemeralKey: x3dhEph ?? undefined,
};
```

This header is stored in `message_ciphertexts.ratchet_header` as **plaintext base64** in Supabase.

**Impact**: The server (and any database breach) can extract every user's Ed25519 public identity key from ratchet headers. While identity keys are "public," having them correlated with message_id + sender_id + recipient_id + timestamp creates a complete key-identity mapping. An attacker who later obtains any private key can retroactively correlate it to its owner and all their messages.

**WhatsApp comparison**: WhatsApp transmits X3DH headers as part of the encrypted message envelope — the header is encrypted with the shared secret, not stored in plaintext alongside the ciphertext.

**Severity**: P1. The identity key is public by design, but its correlation with message metadata in a single database table creates an unnecessary attack surface for post-compromise identity resolution.

**Remediation**: Encrypt the ratchet header with the shared DH secret before storage. The recipient derives the same secret and can decrypt the header to obtain the ratchet public key.

---

### P1-2: Sender Key Distribution Bypasses OTK — Reduced Security on First Contact

**Finding**: `encryption-service.ts` line 290 passes `null` for OTK when establishing pairwise sessions during Sender Key distribution. This means X3DH runs with **3 DH operations** instead of 4. The 4th DH (with OTK) is implemented in `x3dh.ts` but never invoked during distribution.

**Impact**: Without OTK consumption, there is no forward secrecy on the initial key exchange for Sender Key distribution. If an attacker compromises the identity key and signed pre-key of the recipient, they can retroactively decrypt the Sender Key that was distributed — and thereby decrypt all group messages encrypted with that Sender Key.

**WhatsApp comparison**: WhatsApp always consumes an OTK on first session establishment. If no OTKs are available, the client waits or falls back with explicit degradation warning. Xark silently downgrades.

**Severity**: P1. The entire group encryption for a space can be retroactively compromised if a single member's identity + signed pre-key are obtained, because the Sender Key was distributed without OTK protection.

**Remediation**: Always consume an OTK when establishing pairwise sessions for Sender Key distribution. If no OTK is available, queue the distribution and retry when the peer replenishes their OTKs.

---

### P1-3: No Sender Key Rotation on Member Leave (Deferred = Vulnerable)

**Finding**: SECURITY.md Section 5 states "Member leave → ALL remaining members rotate Sender Keys." The code explicitly defers this: primer.md states "Key rotation on member leave deferred to v2."

**Impact**: A departed member retains their copy of all active Sender Keys. They can continue decrypting group messages until the next manual Sender Key rotation (which is not triggered by any event). Forward secrecy on member departure does not exist in v1.

**WhatsApp comparison**: WhatsApp rotates Sender Keys on every member leave. This is non-negotiable for group forward secrecy.

**Severity**: P1. The spec makes a forward secrecy claim that the code does not implement. Any departed member can read all future group messages indefinitely.

**Remediation**: Implement Sender Key rotation on member leave. This is O(N) distribution per remaining member — trivial for groups of 2-15.

---

### P1-4: `message_type_override` in /api/message — Injection Vector

**Finding**: `/api/message/route.ts` accepts a `message_type_override` field in the request body. While there is an allowlist (`['sender_key_dist']`), this means authenticated users can inject control messages (`sender_key_dist`) that will be processed silently by recipients.

**Impact**: A malicious authenticated user could craft a `sender_key_dist` message that distributes a known Sender Key to a target. The recipient's client would silently process it and start using the attacker's Sender Key for that space — allowing the attacker to decrypt future messages.

**WhatsApp comparison**: WhatsApp Sender Key distribution is cryptographically bound to the sender's identity. A third party cannot forge a distribution because the pairwise session authenticates the sender. Xark's RLS checks `user_id = auth.jwt()->>'sub'` but the recipient client doesn't verify that the Sender Key distribution came from a legitimate member.

**Severity**: P1. Requires authenticated access but enables full group message compromise via key substitution.

**Remediation**: Recipients must verify that the sender of a `sender_key_dist` message is an active member of the space AND that the pairwise session identity matches the claimed sender. Reject distributions from unknown identities.

---

## WHATSAPP/SIGNAL DEVIATIONS

### 1. No Sealed Sender

**Xark**: `sender_id` stored in plaintext in the `messages` table. Server knows exactly who sent every message to which space.

**Signal**: Implements "sealed sender" — the server cannot determine the sender of most messages. The sender is encrypted in the message envelope.

**Impact**: Xark's server (or a database breach, or a subpoena) reveals the complete social graph and communication patterns. This is a significant metadata privacy gap.

### 2. No Safety Number Verification

**Xark**: No mechanism for users to verify each other's identity keys out-of-band (QR code scanning, number comparison).

**Signal/WhatsApp**: Safety numbers / security codes allow users to verify they are communicating with the intended party and detect MITM key substitution attacks.

**Impact**: If the key distribution server (Supabase) is compromised, an attacker can substitute public keys and perform a MITM attack. Users have no way to detect this.

### 3. No Key Transparency Log

**Xark**: Public keys are stored in a mutable Postgres table. No audit trail of key changes.

**Signal**: Implements Key Transparency (CONIKS-based) — an append-only, verifiable log of all key changes. Clients can detect unauthorized key substitutions.

**Impact**: A compromised server can silently substitute keys. No client-side detection mechanism exists.

### 4. Browser-Based Crypto vs. Native

**Xark**: All crypto runs in a browser context (WASM via libsodium-wrappers-sumo). Subject to JavaScript side-channels, extension access, and developer tools inspection.

**Signal/WhatsApp**: Native implementations with OS-level memory protection. Keys in hardware-backed keystores.

**Impact**: The entire crypto module is inspectable by any browser extension. A single malicious extension compromises all keys.

### 5. Skipped Key Bound: 1000 vs. Signal's 2000

**Xark**: `MAX_SKIP = 1000` in `double-ratchet.ts`.

**Signal**: Uses 2000 as the standard bound.

**Impact**: Under high message volume with intermittent connectivity (common on mobile), Xark will silently drop decryptable messages before Signal would. This creates a UX gap — "messages randomly fail to decrypt" — that users will blame on the app.

---

## METADATA & TRAFFIC ANALYSIS VULNERABILITIES

### Layer 3 Administrative Leakage

**Finding**: The `space_ledger` table (Layer 3, unencrypted) records administrative actions with full metadata: `actor` (user_id), `action` (e.g., "update_dates", "rename_space"), `payload` (dates, new name), and `previous` (old values).

**Attack**: An observer with database access can infer significant information about the encrypted chat by analyzing Layer 3 events:
- If `update_dates` fires shortly after a burst of E2EE messages, the observer knows the group was discussing dates
- If `rename_space` fires, the observer knows the group changed plans
- Reaction patterns (who voted what, when) reveal group dynamics and preferences
- Constraint creation (dietary restrictions) reveals personal health information

**Combined with sender_id metadata**, an attacker can build a detailed behavioral profile of each user without ever decrypting a single message.

### Decision Item Timing Correlation

**Finding**: Decision items are created in response to @xark commands (which are sent as E2EE messages, but the @xark trigger text is echoed in plaintext to the server). The server can correlate the E2EE message timestamp with the @xark API call timestamp to identify which messages contain @xark commands — even if the message content is encrypted.

---

## ACTIONABLE REMEDIATION PLAN

### Immediate (Before Any Security Claims)

- [ ] **P0-1**: Encrypt IndexedDB values with a non-extractable `CryptoKey` from Web Crypto API
- [ ] **P0-2**: Encrypt the Memory Worker's IndexedDB blob with a session-derived key; plaintext exists only in Worker RAM
- [ ] **P1-1**: Encrypt ratchet headers with the shared DH secret before storage
- [ ] **P1-2**: Always consume OTK during Sender Key distribution sessions; queue if unavailable
- [ ] **P1-3**: Implement Sender Key rotation on member leave (non-negotiable for group forward secrecy)
- [ ] **P1-4**: Recipient-side identity verification on Sender Key distribution processing

### Short-Term (Before Public Launch)

- [ ] Add safety number verification UI (QR code + numeric comparison)
- [ ] Increase MAX_SKIP to 2000 to match Signal standard
- [ ] Add key change notification in chat UI ("X's security code changed")
- [ ] Implement signed pre-key rotation (currently says "30 days" but no rotation mechanism in code)
- [ ] Remove `message_type_override` from API — use separate authenticated endpoint for SK distribution

### Medium-Term (Before Security Marketing)

- [ ] Implement sealed sender (encrypt sender_id in message envelope)
- [ ] Add key transparency log (append-only, client-verifiable)
- [ ] Encrypt Layer 3 constraint data (dietary/health info is sensitive PII)
- [ ] Separate @xark command routing from E2EE message flow to prevent timing correlation
- [ ] Native shell with OS keychain for key storage (iOS Secure Enclave, Android Keystore)

### Long-Term (Before "Better Than WhatsApp" Claims)

- [ ] Third-party cryptographic audit (NCC Group, Trail of Bits, or Cure53)
- [ ] Publish audit report publicly
- [ ] Open-source the crypto module under a permissive license
- [ ] Bug bounty program for cryptographic vulnerabilities
- [ ] Formal verification of the Double Ratchet state machine

---

## BOTTOM LINE

The architecture is **directionally correct** — Signal Protocol, three-layer separation, client-side crypto. The spec is well-written and demonstrates genuine understanding of the threat model.

But the implementation has critical gaps that make the security claims in SECURITY.md **misleading**:

1. "Browser sandboxed" is not "encrypted at rest" — and the document conflates the two
2. The Memory Worker makes the E2EE model pointless for an on-device attacker
3. Sender Key rotation on member leave is claimed but not implemented
4. The OTK bypass during distribution weakens the initial key exchange to 3-DH

**The system currently provides**: Protection against server-side data breaches and network eavesdropping.

**The system does NOT currently provide**: Protection against client-side attacks (XSS, malicious extensions, device forensics), post-departure group forward secrecy, or identity verification against MITM key substitution.

Fix P0-1 and P0-2 before making any encryption claims in marketing. Fix P1-1 through P1-4 before the Hacker News launch the banger playbook recommends. Get a professional audit before claiming parity with Signal or WhatsApp.
