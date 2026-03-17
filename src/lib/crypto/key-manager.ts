// XARK OS v2.0 — Key Management Service
// Registration, key bundle upload, OTK replenishment, backup/restore.
// Bridges local KeyStore with server-side key distribution.

import {
  initCrypto, generateIdentityKeyPair, generateDHKeyPair,
  sign, toBase64, fromBase64, deriveBackupKey,
  aesEncrypt, aesDecrypt, randomBytes, toBytes, fromBytes
} from './primitives';
import { keyStore } from './keystore';
import { supabase } from '../supabase';
import { rotateSenderKey, serializeSenderKeyForStorage } from './sender-keys';
import type { IdentityKeyPair, SignedPreKey, OneTimePreKey, PublicKeyBundle, SenderKeyState } from './types';

const OTK_BATCH_SIZE = 100;
const OTK_REPLENISH_THRESHOLD = 20;

/** Full key registration — called once after Firebase Auth signup */
export async function registerKeys(): Promise<{
  deviceId: number;
  identityPublicKey: string;
}> {
  await initCrypto();

  const deviceId = await keyStore.getDeviceId();

  // 1. Generate Identity Key pair (Ed25519 + Curve25519)
  const identity = generateIdentityKeyPair();

  // 2. Generate Signed Pre-Key
  const signedPreKeyId = 1;
  const signedPreKey = generateDHKeyPair();
  const spkSignature = sign(signedPreKey.publicKey, identity.ed25519.privateKey);

  // 3. Generate One-Time Pre-Keys
  const otks = generateOTKBatch(OTK_BATCH_SIZE);

  // 4. Store private keys locally
  // Cross-lane fix: saveIdentityKey now expects WebCrypto format (publicKeyRaw, CryptoKey, CryptoKey).
  // During transition, we pass raw Uint8Array bytes — getIdentityKeyRaw() in encryption-service
  // detects the Uint8Array instanceof check and handles it correctly.
  await keyStore.saveIdentityKey(
    identity.ed25519.publicKey,
    identity.ed25519.privateKey as unknown as CryptoKey,
    identity.ed25519.publicKey as unknown as CryptoKey
  );
  await keyStore.saveSignedPreKey(signedPreKeyId, signedPreKey);
  await keyStore.saveOneTimePreKeys(otks.map(o => ({ id: o.id, keyPair: o.keyPair })));

  // 5. Upload public keys via API route (rate limited + validated)
  const bundleRes = await fetch('/api/keys/bundle', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      device_id: deviceId,
      identity_key: toBase64(identity.ed25519.publicKey),
      signed_pre_key: toBase64(signedPreKey.publicKey),
      signed_pre_key_id: signedPreKeyId,
      pre_key_sig: toBase64(spkSignature),
    }),
  });
  if (!bundleRes.ok) {
    const err = await bundleRes.text().catch(() => 'unknown');
    throw new Error(`Failed to upload key bundle: ${bundleRes.status} ${err}`);
  }

  // 6. Upload OTK public keys via API route
  const otkPayload = otks.map(o => ({
    id: o.id,
    public_key: toBase64(o.keyPair.publicKey),
  }));
  const otkRes = await fetch('/api/keys/otk', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ device_id: deviceId, keys: otkPayload }),
  });
  if (!otkRes.ok) {
    const err = await otkRes.text().catch(() => 'unknown');
    throw new Error(`Failed to upload OTKs: ${otkRes.status} ${err}`);
  }

  return {
    deviceId,
    identityPublicKey: toBase64(identity.ed25519.publicKey),
  };
}

/** Fetch a peer's key bundle for establishing a session */
export async function fetchPeerKeyBundle(
  userId: string,
  deviceId: number
): Promise<PublicKeyBundle> {
  const { data, error } = await supabase.rpc('fetch_key_bundle', {
    p_user_id: userId,
    p_device_id: deviceId,
  });

  if (error) throw new Error(`Failed to fetch key bundle: ${error.message}`);
  if (!data || data.length === 0) throw new Error(`No key bundle for ${userId}:${deviceId}`);

  const row = data[0];
  const bundle: PublicKeyBundle = {
    identityKey: fromBase64(row.identity_key),
    signedPreKey: fromBase64(row.signed_pre_key),
    signedPreKeyId: row.signed_pre_key_id,
    preKeySig: fromBase64(row.pre_key_sig),
    oneTimePreKey: row.otk_public ? fromBase64(row.otk_public) : undefined,
    oneTimePreKeyId: row.otk_id ?? undefined,
  };

  // BUG 3 fix: consume the OTK locally after use
  if (row.otk_id) {
    await keyStore.deleteOneTimePreKey(row.otk_id);
    console.log(`[xark-e2ee] Consumed OTK ${row.otk_id}`);
  }

  return bundle;
}

/** Check and replenish OTKs if below threshold */
export async function replenishOTKsIfNeeded(): Promise<void> {
  await initCrypto();
  const deviceId = await keyStore.getDeviceId();
  const userId = await getCurrentUserId();

  // BUG 19 fix: query SERVER count, not local (server is source of truth for available OTKs)
  const { count, error: countError } = await supabase
    .from('one_time_pre_keys')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('device_id', deviceId);

  if (countError) {
    console.warn('[xark-e2ee] Failed to query OTK count:', countError.message);
    return;
  }

  const serverCount = count ?? 0;
  if (serverCount >= OTK_REPLENISH_THRESHOLD) return;

  console.log(`[xark-e2ee] OTK count ${serverCount}, replenishing to ${OTK_BATCH_SIZE}...`);
  const otks = generateOTKBatch(OTK_BATCH_SIZE);

  // Store locally
  await keyStore.saveOneTimePreKeys(otks.map(o => ({ id: o.id, keyPair: o.keyPair })));

  // Upload public keys via API route (rate limited + validated)
  const otkPayload = otks.map(o => ({
    id: o.id,
    public_key: toBase64(o.keyPair.publicKey),
  }));
  const otkRes = await fetch('/api/keys/otk', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ device_id: deviceId, keys: otkPayload }),
  });
  if (!otkRes.ok) {
    const err = await otkRes.text().catch(() => 'unknown');
    console.warn(`[xark-e2ee] OTK upload failed: ${otkRes.status} ${err}`);
  } else {
    console.log(`[xark-e2ee] Replenished ${OTK_BATCH_SIZE} OTKs`);
  }
}

/** Create encrypted backup of keys */
export async function createKeyBackup(password: string): Promise<Uint8Array> {
  await initCrypto();
  const identityKey = await keyStore.getIdentityKey();
  if (!identityKey) throw new Error('No identity key to backup');

  const backupData = {
    identityKey: {
      pub: toBase64(identityKey.publicKeyRaw),
      // privateKeyCryptoKey may be Uint8Array (transitional) or CryptoKey (WebCrypto).
      // For backup, we can only serialize raw bytes — CryptoKey backup requires different path.
      priv: identityKey.privateKeyCryptoKey instanceof Uint8Array
        ? toBase64(identityKey.privateKeyCryptoKey)
        : '', // WebCrypto non-extractable key — backup not possible without key export
    },
    // Sender keys would be included here in production
    timestamp: Date.now(),
  };

  const plaintext = toBytes(JSON.stringify(backupData));
  const { key, salt } = deriveBackupKey(password);
  const { ciphertext, nonce } = aesEncrypt(plaintext, key);

  // Pack: salt (16) + nonce (12) + ciphertext
  const packed = new Uint8Array(salt.length + nonce.length + ciphertext.length);
  packed.set(salt, 0);
  packed.set(nonce, salt.length);
  packed.set(ciphertext, salt.length + nonce.length);
  return packed;
}

/** Restore keys from encrypted backup */
export async function restoreKeyBackup(packed: Uint8Array, password: string): Promise<void> {
  await initCrypto();
  const saltLen = 16;
  const nonceLen = 12;
  const salt = packed.slice(0, saltLen);
  const nonce = packed.slice(saltLen, saltLen + nonceLen);
  const ciphertext = packed.slice(saltLen + nonceLen);

  const { key } = deriveBackupKey(password, salt);
  const plaintext = aesDecrypt(ciphertext, nonce, key);
  const data = JSON.parse(fromBytes(plaintext));

  // Restore as transitional format (raw bytes cast to CryptoKey for type compat)
  const pubBytes = fromBase64(data.identityKey.pub);
  const privBytes = fromBase64(data.identityKey.priv);
  await keyStore.saveIdentityKey(
    pubBytes,
    privBytes as unknown as CryptoKey,
    pubBytes as unknown as CryptoKey
  );
}

/** Check if this device has registered keys */
export async function hasRegisteredKeys(): Promise<boolean> {
  const identity = await keyStore.getIdentityKey();
  return identity !== null;
}

// ── Sender Key Rotation (member departure) ──

/**
 * Handle member departure — rotate Sender Key for forward secrecy.
 * 1. Archive current key (for decrypting historical messages)
 * 2. Delete active key
 * 3. Generate new key
 * 4. Save new key locally
 * Caller is responsible for distributing the new key to remaining members.
 */
export async function onMemberLeave(
  spaceId: string,
  leftUserId: string
): Promise<SenderKeyState> {
  await initCrypto();

  // 1. Archive current key for historical message decryption
  const currentKey = await keyStore.getSenderKey(spaceId);
  if (currentKey) {
    await keyStore.saveHistoricalSenderKey(spaceId, currentKey);
    console.log(`[xark-e2ee] Archived old Sender Key for space ${spaceId}`);
  }

  // 2. Delete active key — departed member had access to this
  await keyStore.deleteSenderKey(spaceId);

  // 3. Generate fresh key material
  const newKey = rotateSenderKey();

  // 4. Save new key locally
  await keyStore.saveSenderKey(spaceId, serializeSenderKeyForStorage(newKey));

  console.log(`[xark-e2ee] Rotated Sender Key for space ${spaceId} (member ${leftUserId} left)`);
  return newKey;
}

/**
 * Subscribe to member departures for automatic SK rotation.
 * Leader election: lowest alphabetical user_id triggers rotation (deterministic, no coordination).
 * Non-leaders receive the new SK via sender_key_dist message.
 */
export function subscribeToMemberChanges(
  spaceId: string,
  myUserId: string,
  currentMembers: string[],
  onRotation: (newKey: SenderKeyState) => Promise<void>
): () => void {
  const channel = supabase
    .channel(`sk-members:${spaceId}`)
    .on('postgres_changes', {
      event: 'DELETE',
      schema: 'public',
      table: 'space_members',
      filter: `space_id=eq.${spaceId}`,
    }, async (payload) => {
      const leftUserId = (payload.old as Record<string, string>)?.user_id;
      if (!leftUserId) return;

      // Leader election: lowest alphabetical user_id among remaining members
      const remaining = currentMembers.filter(m => m !== leftUserId).sort();
      const isLeader = remaining.length > 0 && remaining[0] === myUserId;

      if (isLeader) {
        console.log(`[xark-e2ee] I am SK rotation leader for ${spaceId}`);
        try {
          const newKey = await onMemberLeave(spaceId, leftUserId);
          await onRotation(newKey);
        } catch (err) {
          console.error(`[xark-e2ee] SK rotation failed for ${spaceId}:`, err);
        }
      } else {
        console.log(`[xark-e2ee] Waiting for leader to rotate SK for ${spaceId}`);
        // Non-leaders will receive new SK via sender_key_dist distribution
      }
    })
    .subscribe();

  // Return cleanup function
  return () => {
    supabase.removeChannel(channel);
  };
}

// ── Helpers ──

function generateOTKBatch(count: number): OneTimePreKey[] {
  const otks: OneTimePreKey[] = [];
  for (let i = 0; i < count; i++) {
    const id = `otk_${toBase64(randomBytes(8))}`;
    otks.push({ id, keyPair: generateDHKeyPair() });
  }
  return otks;
}

async function getCurrentUserId(): Promise<string> {
  // Read from localStorage (set by useAuth hook)
  if (typeof window !== 'undefined') {
    const stored = localStorage.getItem('xark_user_id');
    if (stored) return stored;
  }
  throw new Error('No authenticated user');
}
