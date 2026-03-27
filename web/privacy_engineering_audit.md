# XARK OS: Privacy Engineering & Compliance Audit

**Target Scope**: Account Deletion Cascades, Local IndexedDB Sanitization, Metadata Shredding
**Perspective**: GDPR Compliance, The Right to be Forgotten, E2EE Cryptographic Erasure

---

## 1. THE GHOST DATA VECTOR (P0/P1)
Your architecture exhibits catastrophic failures in both server-side cryptographic shredding and client-side device sanitization. You are actively hemorrhaging "Ghost Data."

### P0 — The IndexedDB Abandonment Trap
**Location:** [src/components/os/UserMenu.tsx](file:///Users/ramchitturi/xark9/src/components/os/UserMenu.tsx) (Lines 179-188: [handleLogout](file:///Users/ramchitturi/xark9/src/components/os/UserMenu.tsx#179-189))
**The Ghost Data:**
When a user clicks "Log out", your code merely executes `signOut(auth)` and `setSupabaseToken(null)`. It explicitly abandons the `xark-e2ee-store` IndexedDB container.
**The Exploit:**
All of the user's highest-value cryptographic assets remain chilling natively in the local browser IndexedDB:
- `identity_key` (Their unencrypted Ed25519 private key)
- `session` (Active Double Ratchet AES-GCM Root chains & Message keys)
- [senderKey](file:///Users/ramchitturi/xark9/src/lib/crypto/sender-keys.ts#56-115) (Group encryption keys for every space they've joined)
If a user logs out on a shared iPad or library computer, the next user (or an attacker with physical access) doesn't need to bypass authentication or execute XSS. They just open Chrome DevTools → Application → IndexedDB, extract the raw `Uint8Array` asymmetric private keys, and clone the victim's cryptographic identity permanently. 
**The Fix:** You MUST invoke `await keyStore.clearAll()` or explicitly execute `indexedDB.deleteDatabase('xark-e2ee-store')` inside [handleLogout](file:///Users/ramchitturi/xark9/src/components/os/UserMenu.tsx#179-189) to securely shred local encryption states.

### P0 — The Foreign Key Orphan Breach (Server-Side)
**Location:** [supabase/migrations/014_e2ee.sql](file:///Users/ramchitturi/xark9/supabase/migrations/014_e2ee.sql)
**The Ghost Data:** 
When compiling your E2EE database schema, you declared the foreign keys for the cryptographic tables incorrectly. 
```sql
CREATE TABLE IF NOT EXISTS key_bundles (
  user_id          text NOT NULL, -- FATAL: Missing REFERENCES users(id) ON DELETE CASCADE
  device_id        integer NOT NULL,
  ...
CREATE TABLE IF NOT EXISTS one_time_pre_keys (
  user_id          text NOT NULL, -- FATAL: Missing REFERENCES users(id) ON DELETE CASCADE
  ...
```
**The Exploit:** When a user executes a "Delete Account" procedure internally or via the Supabase Auth Dashboard, their `auth.users` and `public.users` rows are deleted. Because you omitted `ON DELETE CASCADE` constraints on the highly sensitive E2EE tables, their `key_bundles`, `one_time_pre_keys`, and `message_ciphertexts` are permanently orphaned on the server. You are violating the GDPR Right to be Forgotten by permanently storing orphaned user ciphertexts and public key fingerprints that are entirely disconnected from any active user.

---

## 2. COMPLIANCE & LEGAL RISKS (P2)
### The Hardcoded Ledger PII Leak
**Location:** [supabase/migrations/017_hybrid_brain.sql](file:///Users/ramchitturi/xark9/supabase/migrations/017_hybrid_brain.sql) (`space_ledger` table)
**The Flaw:** You record audit trails using `actor_name text` and `payload jsonb`. If "Alice" renames a space or proposes an item, her plaintext name ("Alice") is permanently hardcoded into the immutable ledger rows of that space. 
**The Compliance Risk:** If Alice asserts her right to erasure (GDPR Article 17) and deletes her account, her PII (metadata, name, actions) survives immutably inside the `space_ledger` of every group she ever participated in. This breaks the compliance boundary. You must either cryptographically sign ledger actions and drop names (resolving names client-side continuously via active member lists), or run an active sanitization cron-job upon user deletion that scrubs their `actor_name` from historical ledgers.

### The Group Departure Ciphertext Fragmentation
**Location:** [src/lib/crypto/encryption-service.ts](file:///Users/ramchitturi/xark9/src/lib/crypto/encryption-service.ts)
**The UX Flaw:** When a user departs a group, their previously encrypted `message_ciphertexts` remain in the database (standard practice). However, when *new* users join the space months later, the server will push the departed user's ciphertexts to the new user. Because the departed user is gone, they will never securely distribute their old Sender Key to the new user. The new user's chat UI will permanently render rows of `[decryption pending]` or `[invalid message]` for the entire history of the departed user.

---

## 3. THE SANITIZATION VERDICT
**"Logout" does not cryptographically secure the local device.** Your frontend architecture relies heavily on persistent IndexedDB blobs to circumvent the complexities of true WebCrypto `extractable: false` wrap/unwrap semantics. Because the logout function abandons these blobs, a logged-out device is effectively a fully compromised cryptographic clone waiting to be extracted.

## 4. THE INTERROGATION
*(Technical Repercussions You Must Address)*
1. **The IDB Shredding Pipeline:** `indexedDB.deleteDatabase()` is asynchronous. Have you confirmed that your frontend `router.push('/login')` transition waits for the IDB Promise to resolve, guaranteeing the wipe finishes before the user closes the tab?
2. **Postgres Migration Fixes:** Will you write a migration to `ALTER TABLE key_bundles ADD CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;` for all E2EE tables? 
3. **Database Backups:** Supabase runs PITR (Point-in-Time Recovery) and daily WAL backups. Even if you implement cascades, deleted keys persist in cold-storage backups for 7-30 days. Have you documented this retention limit in your Privacy Policy to fulfill GDPR transparency mandates?
