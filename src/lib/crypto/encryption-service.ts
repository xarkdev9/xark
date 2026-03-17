// XARK OS v2.0 — Encryption Service
// High-level API for encrypting/decrypting messages.
// Bridges Double Ratchet (1:1) and Sender Keys (groups).
// Handles Sender Key distribution via pairwise sessions.

import {
  initCrypto, toBase64, fromBase64, toBytes, fromBytes,
  ed25519SkToCurve25519, ed25519PkToCurve25519, generateDHKeyPair
} from './primitives';
import { x3dhInitiate, x3dhRespond } from './x3dh';
import {
  initSessionAsInitiator, initSessionAsResponder,
  ratchetEncrypt, ratchetDecrypt,
  serializeSession, deserializeSession
} from './double-ratchet';
import {
  generateSenderKey, senderKeyEncrypt, senderKeyDecrypt,
  serializeSenderKeyForStorage, serializeSenderKeyForDistribution, deserializeSenderKey
} from './sender-keys';
import { keyStore } from './keystore';
// fetchPeerKeyBundle uses supabase.rpc('fetch_key_bundle') directly (not /api/keys/fetch).
// This is intentional: client-side reads go through RPC (RLS enforced), writes go through API routes.
import { fetchPeerKeyBundle } from './key-manager';
import { supabase, getSupabaseToken } from '../supabase';
import type { DecryptedMessage, MessageType, RawKeyPair } from './types';

/** Encrypted message ready for server transmission */
export interface EncryptedEnvelope {
  ciphertext: string;       // base64
  ratchetHeader?: string;   // base64 JSON envelope (Double Ratchet only)
  recipientId: string;      // user_id or '_group_'
  recipientDeviceId: number; // device_id or 0
}

// ── X3DH Session Metadata ──
// Module-level map to track X3DH ephemeral keys for new sessions.
// Replaces the old `(session as any)._x3dh*` hack with a proper typed approach.
// Key: "peerId:peerDeviceId", Value: { ephemeralPub, identityPub }
const x3dhSessionMeta = new Map<string, {
  ephemeralPub: string;  // base64
  identityPub: string;   // base64
}>();

// ── Identity Key Compatibility Layer ──

/**
 * Get raw Ed25519 identity key bytes for DH operations.
 * Handles both formats:
 * - Legacy: getIdentityKeyLegacy() returns { publicKey, privateKey } as Uint8Array
 * - Transitional: getIdentityKey() returns { publicKeyRaw, privateKeyCryptoKey, publicKeyCryptoKey }
 *   where privateKeyCryptoKey may actually be a Uint8Array (when key-manager.ts passes
 *   libsodium raw bytes to the new saveIdentityKey signature).
 */
async function getIdentityKeyRaw(): Promise<RawKeyPair> {
  // Try legacy format first (old base64 {pub, priv} storage)
  const legacy = await keyStore.getIdentityKeyLegacy();
  if (legacy) return legacy;

  // Try new format — key-manager.ts still uses generateIdentityKeyPair() (libsodium)
  // which returns raw bytes, but saveIdentityKey() now stores as { publicKeyRaw, privateKeyCryptoKey, ... }.
  // The privateKeyCryptoKey field may actually hold a Uint8Array at runtime (type mismatch).
  const webCrypto = await keyStore.getIdentityKey();
  if (webCrypto) {
    const { publicKeyRaw, privateKeyCryptoKey } = webCrypto;

    // Check if privateKeyCryptoKey is actually raw bytes (Uint8Array) — transitional state
    // where key-manager.ts passes libsodium bytes through the new saveIdentityKey signature
    if (privateKeyCryptoKey instanceof Uint8Array) {
      return { publicKey: publicKeyRaw, privateKey: privateKeyCryptoKey };
    }

    // It's a real CryptoKey (non-extractable) — cannot use for libsodium DH.
    // This means WebCrypto key generation is fully wired. Raw bytes are not available.
    throw new Error(
      '[xark-e2ee] WebCrypto identity key found but raw private key needed for DH. Re-register keys.'
    );
  }

  throw new Error('[xark-e2ee] No identity key found');
}

/**
 * Get identity public key bytes (works with both old and new format).
 */
async function getIdentityPublicKeyRaw(): Promise<Uint8Array> {
  const legacy = await keyStore.getIdentityKeyLegacy();
  if (legacy) return legacy.publicKey;

  const webCrypto = await keyStore.getIdentityKey();
  if (webCrypto) return webCrypto.publicKeyRaw;

  throw new Error('[xark-e2ee] No identity key found');
}

// ── Helpers ──

async function getCurrentUserId(): Promise<string> {
  if (typeof window !== 'undefined') {
    const stored = localStorage.getItem('xark_user_id');
    if (stored) return stored;
  }
  throw new Error('No authenticated user');
}

/**
 * Build the ratchet header envelope for transport.
 * Contains the encrypted ratchet header + optional X3DH metadata for first-contact.
 * Returns base64-encoded JSON string.
 */
function buildHeaderEnvelope(
  encryptedHeader: Uint8Array,
  x3dh?: { identityKey: string; ephemeralKey?: string }
): string {
  const envelope: Record<string, unknown> = {
    eh: toBase64(encryptedHeader),  // encrypted header bytes
  };
  if (x3dh) {
    envelope.x3dh = x3dh;
  }
  return toBase64(new TextEncoder().encode(JSON.stringify(envelope)));
}

/**
 * Parse a ratchet header envelope from transport.
 * Handles BOTH old format (plain JSON with publicKey/previousCount/messageNumber)
 * and new format (JSON with eh + optional x3dh).
 */
function parseHeaderEnvelope(ratchetHeaderB64: string): {
  encryptedHeader: Uint8Array;
  x3dh?: { identityKey?: string; ephemeralKey?: string };
} {
  const raw = fromBase64(ratchetHeaderB64);
  const obj = JSON.parse(new TextDecoder().decode(raw));

  // New format: has 'eh' field (encrypted header bytes)
  if (obj.eh) {
    return {
      encryptedHeader: fromBase64(obj.eh),
      x3dh: obj.x3dh,
    };
  }

  // Legacy format: plain JSON { publicKey, previousCount, messageNumber, x3dh? }
  // This was the old unencrypted header format. Cannot be used with new ratchetDecrypt
  // which expects encrypted header bytes. Throw with clear message.
  throw new Error(
    '[xark-e2ee] Legacy unencrypted ratchet header detected. ' +
    'Cannot decrypt — re-establish session required.'
  );
}

/** Get or establish a pairwise Double Ratchet session with a peer */
async function getOrEstablishSession(
  peerId: string,
  peerDeviceId: number
): Promise<ReturnType<typeof deserializeSession>> {
  const sessionData = await keyStore.getSession(peerId, peerDeviceId);
  if (sessionData) {
    return deserializeSession(sessionData);
  }

  // New session — X3DH key agreement as initiator
  const identity = await getIdentityKeyRaw();
  const curve25519Private = ed25519SkToCurve25519(identity.privateKey);
  const curve25519Public = ed25519PkToCurve25519(identity.publicKey);

  // Direct RPC read — RLS enforced, no rate limit needed for reads (BUG 10 documented)
  const peerBundle = await fetchPeerKeyBundle(peerId, peerDeviceId);

  const { sharedSecret, ephemeralKey } = x3dhInitiate(
    { publicKey: curve25519Public, privateKey: curve25519Private },
    peerBundle
  );

  const session = initSessionAsInitiator(sharedSecret, peerBundle.signedPreKey);

  // Store X3DH metadata in module-level map (replaces unsafe `as any` property hack)
  const metaKey = `${peerId}:${peerDeviceId}`;
  x3dhSessionMeta.set(metaKey, {
    ephemeralPub: toBase64(ephemeralKey.publicKey),
    identityPub: toBase64(identity.publicKey),
  });

  return session;
}

// ═══════════════════════════════════════════════════════════════
// SENDER KEY DISTRIBUTION
// ═══════════════════════════════════════════════════════════════

/**
 * Distribute a Sender Key to all space members via pairwise Double Ratchet sessions.
 * Each member gets the key encrypted with their existing (or newly established) session.
 * The distribution message is a control message (message_type: 'sender_key_dist')
 * that is not displayed in chat UI.
 */
export async function distributeSenderKey(
  spaceId: string,
  senderKey: ReturnType<typeof generateSenderKey>
): Promise<void> {
  const myUserId = await getCurrentUserId();
  const myDeviceId = await keyStore.getDeviceId();

  // Fetch all space member devices (excluding self)
  const { data: members, error } = await supabase.rpc('get_space_member_devices', {
    p_space_id: spaceId,
    p_exclude_user: myUserId,
  });

  if (error) {
    console.warn('[xark-sk-dist] Failed to fetch space member devices:', error.message);
    return;
  }
  if (!members || members.length === 0) {
    console.log('[xark-sk-dist] No peer devices — solo space, skipping distribution');
    return;
  }

  console.log(`[xark-sk-dist] Distributing SK to ${members.length} device(s) in space ${spaceId}`);

  // Serialize the sender key for distribution (BUG 15 fix: no private signing key)
  const serializedKey = serializeSenderKeyForDistribution(senderKey);

  // Build ciphertext rows for each member device
  const ciphertextRows: Array<{
    id: string;
    message_id: string;
    recipient_id: string;
    recipient_device_id: number;
    ciphertext: string;
    ratchet_header: string;
  }> = [];

  const msgId = `msg_skd_${crypto.randomUUID()}`;

  for (const member of members as Array<{ user_id: string; device_id: number }>) {
    try {
      // Get or establish pairwise session
      const session = await getOrEstablishSession(member.user_id, member.device_id);

      // Encrypt serialized Sender Key with Double Ratchet
      // header is now Uint8Array (encrypted header bytes)
      const { ciphertext, nonce, header } = ratchetEncrypt(session, serializedKey);

      // Persist updated session
      await keyStore.saveSession(member.user_id, member.device_id, serializeSession(session));

      // Pack nonce + ciphertext
      const packed = new Uint8Array(nonce.length + ciphertext.length);
      packed.set(nonce, 0);
      packed.set(ciphertext, nonce.length);

      // Build header envelope with X3DH metadata for first-contact sessions
      const metaKey = `${member.user_id}:${member.device_id}`;
      const meta = x3dhSessionMeta.get(metaKey);
      let x3dh: { identityKey: string; ephemeralKey?: string } | undefined;

      if (meta) {
        x3dh = {
          identityKey: meta.identityPub,
          ephemeralKey: meta.ephemeralPub,
        };
        // Clean up — metadata only needed for first message
        x3dhSessionMeta.delete(metaKey);
      }

      ciphertextRows.push({
        id: `mc_${crypto.randomUUID()}`,
        message_id: msgId,
        recipient_id: member.user_id,
        recipient_device_id: member.device_id,
        ciphertext: toBase64(packed),
        ratchet_header: buildHeaderEnvelope(header, x3dh),
      });
    } catch (err) {
      console.warn(`[xark-sk-dist] Failed to encrypt SK for ${member.user_id}:${member.device_id}:`, err);
      // Continue with other members — partial distribution is better than none
    }
  }

  if (ciphertextRows.length === 0) return;

  // Send distribution message via /api/message — DB write MUST succeed before broadcast
  const token = getSupabaseToken();
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;

  console.log(`[xark-sk-dist] POSTing distribution message (${ciphertextRows.length} ciphertexts)`);

  let res: Response;
  try {
    res = await fetch('/api/message', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        space_id: spaceId,
        sender_device_id: myDeviceId,
        ciphertext: '__sender_key_dist__', // placeholder — real ciphertexts are per-recipient
        recipient_id: '_group_',
        recipient_device_id: 0,
        message_type_override: 'sender_key_dist',
        distribution_ciphertexts: ciphertextRows,
      }),
    });
  } catch (fetchErr) {
    console.error('[xark-sk-dist] Network error during distribution POST:', fetchErr);
    return;
  }

  // BUG 5 fix: verify DB write succeeded before broadcasting
  if (!res.ok) {
    const errText = await res.text().catch(() => 'unknown');
    throw new Error(`[xark-sk-dist] Distribution POST failed: ${res.status} ${errText}`);
  }

  console.log('[xark-sk-dist] DB write confirmed, broadcasting...');

  const data = await res.json();
  if (!data.messageId) {
    console.warn('[xark-sk-dist] No messageId returned — skipping broadcast');
    return;
  }

  // BUG 20 fix: broadcast with retry so live recipients process immediately
  const distributionPayload = {
    id: data.messageId,
    space_id: spaceId,
    role: 'user',
    content: null,
    user_id: myUserId,
    sender_name: null,
    created_at: new Date().toISOString(),
    message_type: 'sender_key_dist',
    sender_device_id: myDeviceId,
  };

  try {
    const { supabase: supa } = await import('@/lib/supabase');
    const channel = supa.channel(`chat:${spaceId}`);
    await channel.subscribe();

    // Retry broadcast up to 3 times with linear backoff
    let broadcastSuccess = false;
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        await channel.send({
          type: 'broadcast',
          event: 'message',
          payload: distributionPayload,
        });
        console.log(`[xark-sk-dist] Broadcast confirmed (attempt ${attempt})`);
        broadcastSuccess = true;
        break;
      } catch (err) {
        console.warn(`[xark-sk-dist] Broadcast attempt ${attempt} failed:`, err);
        if (attempt < 3) {
          await new Promise(r => setTimeout(r, 1000 * attempt));
        }
      }
    }

    if (!broadcastSuccess) {
      console.error('[xark-sk-dist] Broadcast failed after 3 attempts — recipients will fetch on next load');
    }

    supa.removeChannel(channel);
  } catch (broadcastErr) {
    console.error('[xark-sk-dist] Broadcast setup failed:', broadcastErr);
    // Non-critical — DB row exists, recipients will pick it up on next load
  }
}

/**
 * Process an incoming Sender Key distribution message.
 * Decrypts the Sender Key from the pairwise session and stores it locally.
 */
export async function processSenderKeyDistribution(
  senderId: string,
  senderDeviceId: number,
  spaceId: string,
  ciphertextB64: string,
  ratchetHeaderB64: string
): Promise<void> {
  await initCrypto();

  const packed = fromBase64(ciphertextB64);
  const nonceLen = 24;
  const nonce = packed.slice(0, nonceLen);
  const ciphertext = packed.slice(nonceLen);

  // Parse header envelope (supports both new encrypted and legacy formats)
  const { encryptedHeader, x3dh: x3dhMeta } = parseHeaderEnvelope(ratchetHeaderB64);

  let sessionData = await keyStore.getSession(senderId, senderDeviceId);
  let session;

  if (!sessionData) {
    // First contact — X3DH responder side
    const identity = await getIdentityKeyRaw();
    const curve25519Private = ed25519SkToCurve25519(identity.privateKey);
    const curve25519Public = ed25519PkToCurve25519(identity.publicKey);

    const spkId = 1;
    const signedPreKey = await keyStore.getSignedPreKey(spkId);
    if (!signedPreKey) throw new Error('No signed pre-key');

    // Extract X3DH metadata from envelope
    let peerIdentityEd25519: Uint8Array | null = null;
    if (x3dhMeta?.identityKey) {
      peerIdentityEd25519 = fromBase64(x3dhMeta.identityKey);
    }

    if (peerIdentityEd25519) {
      const peerIdentityCurve = ed25519PkToCurve25519(peerIdentityEd25519);
      // BUG 11 fix: use actual X3DH ephemeral key from envelope
      const peerEphemeralPublic = x3dhMeta?.ephemeralKey
        ? fromBase64(x3dhMeta.ephemeralKey)
        : null;

      if (!peerEphemeralPublic) {
        throw new Error('[xark-e2ee] Missing X3DH ephemeral key in distribution message');
      }

      const sharedSecret = x3dhRespond(
        { publicKey: curve25519Public, privateKey: curve25519Private },
        signedPreKey,
        null, // OTK lookup skipped for SK distribution — simplified for v1
        peerIdentityCurve,
        peerEphemeralPublic
      );

      const myRatchetKey = generateDHKeyPair();
      session = initSessionAsResponder(sharedSecret, myRatchetKey);
    } else {
      // No X3DH metadata — use simplified session init
      const myRatchetKey = generateDHKeyPair();
      session = initSessionAsResponder(new Uint8Array(32), myRatchetKey);
    }
  } else {
    session = deserializeSession(sessionData);
  }

  // ratchetDecrypt now takes encrypted header bytes directly
  const plaintext = ratchetDecrypt(session, ciphertext, nonce, encryptedHeader);
  await keyStore.saveSession(senderId, senderDeviceId, serializeSession(session));

  // plaintext is a serialized SenderKeyState — store it keyed by spaceId:senderId
  const senderKey = deserializeSenderKey(plaintext);
  await keyStore.saveSenderKey(`${spaceId}:${senderId}`, serializeSenderKeyForStorage(senderKey));
}

// ═══════════════════════════════════════════════════════════════
// ENCRYPT
// ═══════════════════════════════════════════════════════════════

/** Encrypt a message for a 1:1 sanctuary */
export async function encryptForSanctuary(
  text: string,
  peerId: string,
  peerDeviceId: number
): Promise<EncryptedEnvelope> {
  await initCrypto();

  const payload: DecryptedMessage = {
    text,
    replyTo: null,
    mediaUrl: null,
    type: 'message',
  };
  const plaintext = toBytes(JSON.stringify(payload));

  // Get or establish session
  let sessionData = await keyStore.getSession(peerId, peerDeviceId);
  let session;
  let isNewSession = false;

  if (!sessionData) {
    isNewSession = true;
    session = await getOrEstablishSession(peerId, peerDeviceId);
  } else {
    session = deserializeSession(sessionData);
  }

  // header is now Uint8Array (encrypted header bytes)
  const { ciphertext, nonce, header } = ratchetEncrypt(session, plaintext);

  // Persist updated session
  await keyStore.saveSession(peerId, peerDeviceId, serializeSession(session));

  // Pack nonce + ciphertext
  const packed = new Uint8Array(nonce.length + ciphertext.length);
  packed.set(nonce, 0);
  packed.set(ciphertext, nonce.length);

  // Build header envelope with X3DH metadata for first message
  let x3dh: { identityKey: string; ephemeralKey?: string } | undefined;
  if (isNewSession) {
    const metaKey = `${peerId}:${peerDeviceId}`;
    const meta = x3dhSessionMeta.get(metaKey);
    if (meta) {
      x3dh = {
        identityKey: meta.identityPub,
        ephemeralKey: meta.ephemeralPub,
      };
      x3dhSessionMeta.delete(metaKey);
    } else {
      // Fallback: include identity key without ephemeral
      const identityPub = await getIdentityPublicKeyRaw();
      x3dh = { identityKey: toBase64(identityPub) };
    }
  }

  return {
    ciphertext: toBase64(packed),
    ratchetHeader: buildHeaderEnvelope(header, x3dh),
    recipientId: peerId,
    recipientDeviceId: peerDeviceId,
  };
}

/** Encrypt a message for a group space (Sender Key) */
export async function encryptForSpace(
  text: string,
  spaceId: string
): Promise<EncryptedEnvelope> {
  await initCrypto();

  const payload: DecryptedMessage = {
    text,
    replyTo: null,
    mediaUrl: null,
    type: 'message',
  };
  const plaintext = toBytes(JSON.stringify(payload));

  // Get or generate Sender Key for this space
  let senderKeyData = await keyStore.getSenderKey(spaceId);
  let senderKey;

  if (!senderKeyData) {
    // Generate new Sender Key and distribute to space members
    senderKey = generateSenderKey();
    await keyStore.saveSenderKey(spaceId, serializeSenderKeyForStorage(senderKey));

    // Distribute to all space members via pairwise sessions
    try {
      await distributeSenderKey(spaceId, senderKey);
    } catch (err) {
      console.warn('[e2ee] Sender Key distribution failed:', err);
      // Continue anyway — we can still encrypt, recipients will request key later
    }
  } else {
    senderKey = deserializeSenderKey(senderKeyData);

    // ── TOMBSTONE LAZY ROTATION RECOVERY ──
    // If a tombstone was issued AFTER this key was created, it may exist on a compromised device.
    if (senderKey.createdAt) {
      const { data: tombstones, error: tsError } = await supabase
        .from('space_tombstones')
        .select('id')
        .eq('space_id', spaceId)
        .gt('created_at', new Date(senderKey.createdAt).toISOString())
        .limit(1);

      if (!tsError && tombstones && tombstones.length > 0) {
        console.warn(`[e2ee] Tombstone detected after key generation! Forcing Lazy Rotation.`);
        senderKey = generateSenderKey();
        await keyStore.saveSenderKey(spaceId, serializeSenderKeyForStorage(senderKey));
        try {
          // get_space_member_devices intrinsically excludes kicked users,
          // guaranteeing distribution only to SAFE devices.
          await distributeSenderKey(spaceId, senderKey);
        } catch (err) {
          console.warn('[e2ee] Lazy rotation distribution failed:', err);
        }
      }
    }
  }

  const { ciphertext, nonce, signature, iteration } = senderKeyEncrypt(senderKey, plaintext);

  // Persist advanced state
  await keyStore.saveSenderKey(spaceId, serializeSenderKeyForStorage(senderKey));

  // Pack: nonce + signature + iteration(4 bytes) + ciphertext
  const iterBytes = new Uint8Array(4);
  new DataView(iterBytes.buffer).setUint32(0, iteration, false);

  const packed = new Uint8Array(nonce.length + signature.length + 4 + ciphertext.length);
  packed.set(nonce, 0);
  packed.set(signature, nonce.length);
  packed.set(iterBytes, nonce.length + signature.length);
  packed.set(ciphertext, nonce.length + signature.length + 4);

  return {
    ciphertext: toBase64(packed),
    recipientId: '_group_',
    recipientDeviceId: 0,
  };
}

// ═══════════════════════════════════════════════════════════════
// DECRYPT
// ═══════════════════════════════════════════════════════════════

/** Decrypt a message based on its type */
export async function decryptMessage(
  messageId: string,
  senderId: string,
  senderDeviceId: number | null,
  ciphertextB64: string,
  ratchetHeaderB64: string | null,
  recipientId: string,
  spaceId: string
): Promise<DecryptedMessage> {
  await initCrypto();

  let plaintext: Uint8Array;

  if (recipientId === '_group_') {
    // Group message — Sender Key
    const packed = fromBase64(ciphertextB64);
    const nonceLen = 24; // XChaCha20-Poly1305 nonce is 24 bytes
    const sigLen = 64;
    const nonce = packed.slice(0, nonceLen);
    const signature = packed.slice(nonceLen, nonceLen + sigLen);
    const iterBytes = packed.slice(nonceLen + sigLen, nonceLen + sigLen + 4);
    const iteration = new DataView(iterBytes.buffer, iterBytes.byteOffset).getUint32(0, false);
    const ciphertext = packed.slice(nonceLen + sigLen + 4);

    // Get sender's Sender Key (received via pairwise distribution)
    let senderKeyData = await keyStore.getSenderKey(`${spaceId}:${senderId}`);
    if (!senderKeyData) {
      // BUG 6 fix: retry after 2s — SK distribution may still be processing
      await new Promise(r => setTimeout(r, 2000));
      senderKeyData = await keyStore.getSenderKey(`${spaceId}:${senderId}`);
    }
    if (!senderKeyData) {
      return { text: '[encrypted message - sender key not available]', replyTo: null, mediaUrl: null, type: 'message' };
    }

    const senderKey = deserializeSenderKey(senderKeyData);
    plaintext = senderKeyDecrypt(senderKey, ciphertext, nonce, signature, iteration);

    // Persist advanced state
    await keyStore.saveSenderKey(`${spaceId}:${senderId}`, serializeSenderKeyForStorage(senderKey));
  } else {
    // 1:1 message — Double Ratchet
    if (!ratchetHeaderB64) throw new Error('Missing ratchet header for 1:1 message');

    const packed = fromBase64(ciphertextB64);
    const nonceLen = 24; // XChaCha20-Poly1305 nonce is 24 bytes
    const nonce = packed.slice(0, nonceLen);
    const ciphertext = packed.slice(nonceLen);

    // Parse header envelope (encrypted header + X3DH metadata)
    const { encryptedHeader, x3dh: x3dhMeta } = parseHeaderEnvelope(ratchetHeaderB64);

    // BUG 7/8 fix: missing device ID is an explicit error, not a silent 0-sentinel
    if (senderDeviceId == null) {
      console.error('[xark-e2ee] Missing sender device ID for message', messageId);
      return { text: '[missing device info]', replyTo: null, mediaUrl: null, type: 'message' as const };
    }

    let sessionData = await keyStore.getSession(senderId, senderDeviceId);
    let session;

    if (!sessionData) {
      // First message received — X3DH responder side
      const identity = await getIdentityKeyRaw();
      const curve25519Private = ed25519SkToCurve25519(identity.privateKey);
      const curve25519Public = ed25519PkToCurve25519(identity.publicKey);

      const spkId = 1; // current signed pre-key ID
      const signedPreKey = await keyStore.getSignedPreKey(spkId);
      if (!signedPreKey) throw new Error('No signed pre-key');

      // Extract X3DH metadata from envelope
      let peerIdentityEd25519: Uint8Array | null = null;
      if (x3dhMeta?.identityKey) {
        peerIdentityEd25519 = fromBase64(x3dhMeta.identityKey);
      }

      if (peerIdentityEd25519) {
        // Full X3DH responder flow
        const peerIdentityCurve = ed25519PkToCurve25519(peerIdentityEd25519);
        // BUG 11 fix: use actual X3DH ephemeral key from envelope
        const peerEphemeralPublic = x3dhMeta?.ephemeralKey
          ? fromBase64(x3dhMeta.ephemeralKey)
          : null;

        if (!peerEphemeralPublic) {
          throw new Error('[xark-e2ee] Missing X3DH ephemeral key — cannot establish session');
        }

        const sharedSecret = x3dhRespond(
          { publicKey: curve25519Public, privateKey: curve25519Private },
          signedPreKey,
          null, // OTK handling simplified for v1
          peerIdentityCurve,
          peerEphemeralPublic
        );

        const myRatchetKey = generateDHKeyPair();
        session = initSessionAsResponder(sharedSecret, myRatchetKey);
      } else {
        // Legacy: no X3DH metadata (messages from before wiring update)
        const myRatchetKey = generateDHKeyPair();
        session = initSessionAsResponder(new Uint8Array(32), myRatchetKey);
      }
    } else {
      session = deserializeSession(sessionData);
    }

    // ratchetDecrypt now takes encrypted header bytes directly
    plaintext = ratchetDecrypt(session, ciphertext, nonce, encryptedHeader);
    await keyStore.saveSession(senderId, senderDeviceId, serializeSession(session));
  }

  const parsed = JSON.parse(fromBytes(plaintext)) as DecryptedMessage;
  return parsed;
}

/** Client-side message type guard — anti-injection defense */
export function resolveMessageContent(
  messageType: MessageType | string,
  serverContent: string | null,
  decryptedContent: string | null
): string {
  // E2EE message types — NEVER trust server content
  if (messageType === 'e2ee' || messageType === 'e2ee_xark') {
    return decryptedContent ?? '[decryption pending]';
  }
  // Unencrypted types — server content is authoritative
  if (messageType === 'xark' || messageType === 'system' || messageType === 'legacy') {
    return serverContent ?? '';
  }
  return serverContent ?? '';
}
