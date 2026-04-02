// hello OS v2.0 — Encryption Service
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
import { keyStore, getAckedSenders, markSkAcked } from './keystore';
// fetchPeerKeyBundle uses supabase.rpc('fetch_key_bundle') directly (not /api/keys/fetch).
// This is intentional: client-side reads go through RPC (RLS enforced), writes go through API routes.
import { fetchPeerKeyBundle } from './key-manager';
import { supabase, getSupabaseToken } from '../supabase';
import type { DecryptedMessage, MessageType, RawKeyPair } from './types';
import { requestMissingSenderKey, waitForSenderKey, notifySenderKeyArrived } from './sk-recovery';
import { acquireRatchetLock, acquireSenderKeyLock } from './mutex';

/** Distribution ciphertext row — piggybacked on the message POST */
export interface DistributionCiphertext {
  id: string;
  recipient_id: string;
  recipient_device_id: number;
  ciphertext: string;
  ratchet_header: string;
}

/** Encrypted message ready for server transmission */
export interface EncryptedEnvelope {
  ciphertext: string;       // base64
  ratchetHeader?: string;   // base64 JSON envelope (Double Ratchet only)
  recipientId: string;      // user_id or '_group_'
  recipientDeviceId: number; // device_id or 0
  /** Two-phase commit: call ONLY after network ACK to persist ratchet advancement.
   *  If network fails, do NOT call — ratchet state stays at pre-encrypt position. */
  commit: () => Promise<void>;
  /** Sender Key distribution ciphertexts — piggybacked on the same POST for atomic delivery */
  distributionCiphertexts?: DistributionCiphertext[];
}

// ── X3DH Session Metadata ──
// Module-level map to track X3DH ephemeral keys for new sessions.
// Replaces the old `(session as any)._x3dh*` hack with a proper typed approach.
// Key: "peerId:peerDeviceId", Value: { ephemeralPub, identityPub }
const x3dhSessionMeta = new Map<string, {
  ephemeralPub: string;  // base64
  identityPub: string;   // base64
  otkId?: string;        // The OTK ID consumed by the initiator
}>();

// ── Concurrency Mutex (CRYPTO-05: Web Locks API) ──
// Cross-tab exclusive locks via navigator.locks (with in-tab fallback).
// Replaces the old in-process Map-based mutexes with cross-tab safety.
// See ./mutex.ts for implementation.

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
      '[hello-e2ee] WebCrypto identity key found but raw private key needed for DH. Re-register keys.'
    );
  }

  throw new Error('[hello-e2ee] No identity key found');
}

/**
 * Get identity public key bytes (works with both old and new format).
 */
async function getIdentityPublicKeyRaw(): Promise<Uint8Array> {
  const legacy = await keyStore.getIdentityKeyLegacy();
  if (legacy) return legacy.publicKey;

  const webCrypto = await keyStore.getIdentityKey();
  if (webCrypto) return webCrypto.publicKeyRaw;

  throw new Error('[hello-e2ee] No identity key found');
}

// ── Helpers ──

async function getCurrentUserId(): Promise<string> {
  if (typeof window !== 'undefined') {
    const stored = localStorage.getItem('hello_user_id');
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
  x3dh?: { identityKey: string; ephemeralKey?: string; otkId?: string }
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
  x3dh?: { identityKey?: string; ephemeralKey?: string; otkId?: string };
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
    '[hello-e2ee] Legacy unencrypted ratchet header detected. ' +
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

  // X3DH key material NEVER logged — see CLAUDE.md security requirements

  const { sharedSecret, ephemeralKey } = x3dhInitiate(
    { publicKey: curve25519Public, privateKey: curve25519Private },
    peerBundle
  );

  // Shared secret derived — never log key material

  const session = initSessionAsInitiator(sharedSecret, peerBundle.signedPreKey);

  // Store X3DH metadata in module-level map
  const metaKey = `${peerId}:${peerDeviceId}`;
  x3dhSessionMeta.set(metaKey, {
    ephemeralPub: toBase64(ephemeralKey.publicKey),
    identityPub: toBase64(identity.publicKey),
    otkId: peerBundle.oneTimePreKeyId,
  });

  return session;
}

// ═══════════════════════════════════════════════════════════════
// SENDER KEY DISTRIBUTION
// ═══════════════════════════════════════════════════════════════

/**
 * Prepare Sender Key distribution ciphertexts for all space members.
 * Does all the crypto (fetch peers, pairwise encrypt SK) but makes NO network calls.
 * Returns ciphertext rows to be piggybacked on the message POST for atomic delivery.
 *
 * JWT GATEKEEPER: fails loudly if no JWT — prevents silent distribution skip.
 */
export async function prepareSenderKeyDistribution(
  groupId: string,
  senderKey: ReturnType<typeof generateSenderKey>,
  ackedSenders?: Set<string>
): Promise<DistributionCiphertext[]> {
  // ── JWT GATEKEEPER — fail the send, don't silently skip ──
  if (!getSupabaseToken()) {
    throw new Error('[hello-sk-dist] No JWT — cannot distribute Sender Key. Aborting send.');
  }

  const myUserId = await getCurrentUserId();

  // Fetch all space member devices (excluding self)
  const { data: members, error } = await supabase.rpc('get_space_member_devices', {
    p_group_id: groupId,
    p_exclude_user: myUserId,
  });

  if (error) {
    throw new Error(`[hello-sk-dist] Failed to fetch space member devices: ${error.message}`);
  }
  if (!members || members.length === 0) {
    console.log('[hello-sk-dist] No peer devices — solo space, skipping distribution');
    return [];
  }

  // CRYPTO-04: filter out ACKed devices for O(1) distribution
  const allDevices = members as Array<{ user_id: string; device_id: number }>;
  const targetDevices = ackedSenders
    ? allDevices.filter((d) => !ackedSenders.has(`${d.user_id}:${d.device_id}`))
    : allDevices;

  if (targetDevices.length === 0) {
    console.log(`[hello-sk-dist] All ${allDevices.length} device(s) already ACKed — skipping distribution`);
    return [];
  }

  console.log(`[hello-sk-dist] Preparing SK distribution for ${targetDevices.length}/${allDevices.length} device(s) in space ${groupId}`);

  // Serialize the sender key for distribution (BUG 15 fix: no private signing key)
  const serializedKey = serializeSenderKeyForDistribution(senderKey);

  // Build ciphertext rows for each member device
  const ciphertextRows: DistributionCiphertext[] = [];

  // Parallelize in chunks of 10 to prevent DOM freeze
  const CHUNK_SIZE = 10;

  for (let i = 0; i < targetDevices.length; i += CHUNK_SIZE) {
    const chunk = targetDevices.slice(i, i + CHUNK_SIZE);

    const results = await Promise.allSettled(
      chunk.map(async (member) => {
        try {
          // Get or establish pairwise session
          const session = await getOrEstablishSession(member.user_id, member.device_id);

          // Encrypt serialized Sender Key with Double Ratchet
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
          let x3dh: { identityKey: string; ephemeralKey?: string; otkId?: string } | undefined;

          if (meta) {
            x3dh = {
              identityKey: meta.identityPub,
              ephemeralKey: meta.ephemeralPub,
              otkId: meta.otkId,
            };
            x3dhSessionMeta.delete(metaKey);
          }

          return {
            id: `mc_${crypto.randomUUID()}`,
            recipient_id: member.user_id,
            recipient_device_id: member.device_id,
            ciphertext: toBase64(packed),
            ratchet_header: buildHeaderEnvelope(header, x3dh),
          };
        } catch (err) {
          console.warn(`[hello-sk-dist] Failed to encrypt SK for ${member.user_id}:${member.device_id}:`, err);
          return null;
        }
      })
    );

    // Collect successful results
    for (const result of results) {
      if (result.status === 'fulfilled' && result.value) {
        ciphertextRows.push(result.value);
      }
    }

    // Yield to main thread between chunks (prevents DOM freeze)
    if (i + CHUNK_SIZE < targetDevices.length) {
      await new Promise(r => setTimeout(r, 0));
    }
  }

  return ciphertextRows;
}

/**
 * Distribute a Sender Key to all space members via pairwise Double Ratchet sessions.
 * Thin wrapper around prepareSenderKeyDistribution() for the lazy rotation edge case
 * where distribution must happen as a standalone POST + broadcast.
 */
export async function distributeSenderKey(
  groupId: string,
  senderKey: ReturnType<typeof generateSenderKey>
): Promise<void> {
  const myUserId = await getCurrentUserId();
  const myDeviceId = await keyStore.getDeviceId();

  const ciphertextRows = await prepareSenderKeyDistribution(groupId, senderKey);
  if (ciphertextRows.length === 0) return;

  const msgId = `msg_skd_${crypto.randomUUID()}`;
  const rowsWithMsgId = ciphertextRows.map(row => ({ ...row, message_id: msgId }));

  // Send distribution message via /api/message — DB write MUST succeed before broadcast
  const token = getSupabaseToken();
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;

  console.log(`[hello-sk-dist] POSTing distribution message (${rowsWithMsgId.length} ciphertexts)`);

  let res: Response;
  try {
    res = await fetch('/api/message', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        group_id: groupId,
        sender_device_id: myDeviceId,
        ciphertext: '__sender_key_dist__', // placeholder — real ciphertexts are per-recipient
        recipient_id: '_group_',
        recipient_device_id: 0,
        message_type: 'sender_key_dist',
        message_id: msgId,
        distribution_ciphertexts: rowsWithMsgId,
      }),
    });
  } catch (fetchErr) {
    console.error('[hello-sk-dist] Network error during distribution POST:', fetchErr);
    return;
  }

  // BUG 5 fix: verify DB write succeeded before broadcasting
  if (!res.ok) {
    const errText = await res.text().catch(() => 'unknown');
    throw new Error(`[hello-sk-dist] Distribution POST failed: ${res.status} ${errText}`);
  }

  console.log('[hello-sk-dist] DB write confirmed, broadcasting...');

  const data = await res.json();
  if (!data.messageId) {
    console.warn('[hello-sk-dist] No messageId returned — skipping broadcast');
    return;
  }

  // BUG 20 fix: broadcast with retry so live recipients process immediately
  const distributionPayload = {
    id: data.messageId,
    group_id: groupId,
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
    const channel = supa.channel(`chat:${groupId}`);
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
        console.log(`[hello-sk-dist] Broadcast confirmed (attempt ${attempt})`);
        broadcastSuccess = true;
        break;
      } catch (err) {
        console.warn(`[hello-sk-dist] Broadcast attempt ${attempt} failed:`, err);
        if (attempt < 3) {
          await new Promise(r => setTimeout(r, 1000 * attempt));
        }
      }
    }

    if (!broadcastSuccess) {
      console.error('[hello-sk-dist] Broadcast failed after 3 attempts — recipients will fetch on next load');
    }

    supa.removeChannel(channel);
  } catch (broadcastErr) {
    console.error('[hello-sk-dist] Broadcast setup failed:', broadcastErr);
    // Non-critical — DB row exists, recipients will pick it up on next load
  }
}

/**
 * Process an incoming Sender Key distribution message.
 * Decrypts the Sender Key from the pairwise session and stores it locally.
 */
export async function processSenderKeyDistribution(
  messageId: string,
  senderId: string,
  senderDeviceId: number,
  groupId: string,
  ciphertextB64: string,
  ratchetHeaderB64: string
): Promise<void> {
  const alreadyProcessed = await keyStore.hasProcessedSKDistribution(messageId);
  if (alreadyProcessed) {
    console.log(`[E2EE] SK Distribution ${messageId} already processed. Skipping to prevent ratchet corruption.`);
    return;
  }

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
    let myOneTimePreKey: RawKeyPair | null = null;

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
        throw new Error('[hello-e2ee] Missing X3DH ephemeral key in distribution message');
      }

      const otkId = x3dhMeta?.otkId;
      if (otkId) {
        myOneTimePreKey = await keyStore.getOneTimePreKey(otkId);
        if (!myOneTimePreKey) {
          console.error(`[e2ee-x3dh] OTK ${otkId} NOT FOUND in local keystore! Initiator used 4-DH, we'll use 3-DH → shared secret WILL diverge.`);
        } else {
          console.log(`[e2ee-x3dh] OTK ${otkId} found locally. 4-DH key agreement.`);
        }
      } else {
        console.log(`[e2ee-x3dh] No OTK in envelope — 3-DH key agreement (initiator also had no OTK).`);
      }

      // Responder X3DH — key material never logged

      const sharedSecret = x3dhRespond(
        { publicKey: curve25519Public, privateKey: curve25519Private },
        signedPreKey,
        myOneTimePreKey,
        peerIdentityCurve,
        peerEphemeralPublic
      );

      // Responder shared secret derived — never log

      // Responder OTK cleanup
      if (otkId && myOneTimePreKey) {
        await keyStore.deleteOneTimePreKey(otkId);
        console.log(`[e2ee-x3dh] Receiver cleaned up consumed OTK ${otkId}`);
      }

      session = initSessionAsResponder(sharedSecret, signedPreKey);
    } else {
      // No X3DH metadata — use simplified session init
      const myRatchetKey = { publicKey: new Uint8Array(32), privateKey: new Uint8Array(32) };
      session = initSessionAsResponder(new Uint8Array(32), myRatchetKey);
    }
  } else {
    session = deserializeSession(sessionData);
  }

  // ratchetDecrypt now takes encrypted header bytes directly
  const plaintext = ratchetDecrypt(session, ciphertext, nonce, encryptedHeader);
  await keyStore.saveSession(senderId, senderDeviceId, serializeSession(session));

  // plaintext is a serialized SenderKeyState — store it keyed by groupId:senderId
  const senderKey = deserializeSenderKey(plaintext);
  await keyStore.saveSenderKey(`${groupId}:${senderId}`, serializeSenderKeyForStorage(senderKey));

  await keyStore.markSKDistributionProcessed(messageId);

  // Notify any pending SK recovery waiters that this key is now available
  notifySenderKeyArrived(groupId, senderId);

  // Priority 1 fix: emit DOM event so space page can re-decrypt failed messages
  // from this sender now that their Sender Key is available.
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent('sk-arrived', {
      detail: { groupId, senderId },
    }));
  }
}

// ═══════════════════════════════════════════════════════════════
// ENCRYPT
// ═══════════════════════════════════════════════════════════════

import type { LinkPreviewPayload } from './types';

/** Media metadata for E2EE media messages */
export interface MediaPayload {
  mediaUrl: string;
  aesKeyBase64: string;
  ivBase64: string;
  mimeType: string;
  inlineThumbnail?: string;
  linkPreview?: LinkPreviewPayload;
}

/** Encrypt a message for a 1:1 dm */
export async function encryptForSanctuary(
  text: string,
  peerId: string,
  peerDeviceId: number,
  media?: MediaPayload,
  linkPreview?: LinkPreviewPayload
): Promise<EncryptedEnvelope> {
  return acquireRatchetLock(`${peerId}:${peerDeviceId}`, async () => {
    await initCrypto();

  const payload: DecryptedMessage = {
    text,
    replyTo: null,
    mediaUrl: media?.mediaUrl ?? null,
    type: media ? 'media' : 'message',
    ...(media && {
      aesKeyBase64: media.aesKeyBase64,
      ivBase64: media.ivBase64,
      mimeType: media.mimeType,
      ...(media.inlineThumbnail && { inlineThumbnail: media.inlineThumbnail }),
      ...(media.linkPreview && { linkPreview: media.linkPreview }),
    }),
    ...(!media && linkPreview && { linkPreview }),
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

  // TWO-PHASE COMMIT with durable pre-commit state.
  // Write advanced ratchet state to IDB BEFORE the network call so it survives tab close.
  // On ACK: persist the session and delete the unacked entry.
  // On reopen after crash: getUnackedRatchets() recovers the advanced state.
  const serializedSession = serializeSession(session);
  const pendingMsgId = `pending_${crypto.randomUUID()}`;
  await keyStore.saveUnackedRatchet(pendingMsgId, {
    sessionKey: `${peerId}:${peerDeviceId}`,
    sessionType: 'ratchet',
    serializedState: toBase64(serializedSession),
  });

  const commitSession = async () => {
    // ACK received — persist the advanced session state and clean up
    await keyStore.saveSession(peerId, peerDeviceId, serializedSession);
    await keyStore.ackRatchet(pendingMsgId);
  };

  // Pack nonce + ciphertext
  const packed = new Uint8Array(nonce.length + ciphertext.length);
  packed.set(nonce, 0);
  packed.set(ciphertext, nonce.length);

  // Build header envelope with X3DH metadata for first message
  let x3dh: { identityKey: string; ephemeralKey?: string; otkId?: string } | undefined;
  if (isNewSession) {
    const metaKey = `${peerId}:${peerDeviceId}`;
    const meta = x3dhSessionMeta.get(metaKey);
    if (meta) {
      x3dh = {
        identityKey: meta.identityPub,
        ephemeralKey: meta.ephemeralPub,
        otkId: meta.otkId,
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
    commit: commitSession,
  };
  }); // End acquireRatchetLock
}

/** Encrypt a message for a group space (Sender Key) */
export async function encryptForSpace(
  text: string,
  groupId: string,
  media?: MediaPayload,
  linkPreview?: LinkPreviewPayload
): Promise<EncryptedEnvelope> {
  return acquireSenderKeyLock(groupId, async () => {
    await initCrypto();

  const payload: DecryptedMessage = {
    text,
    replyTo: null,
    mediaUrl: media?.mediaUrl ?? null,
    type: media ? 'media' : 'message',
    ...(media && {
      aesKeyBase64: media.aesKeyBase64,
      ivBase64: media.ivBase64,
      mimeType: media.mimeType,
      ...(media.inlineThumbnail && { inlineThumbnail: media.inlineThumbnail }),
      ...(media.linkPreview && { linkPreview: media.linkPreview }),
    }),
    ...(!media && linkPreview && { linkPreview }),
  };
  const plaintext = toBytes(JSON.stringify(payload));

  // Get or generate Sender Key for this space
  let senderKeyData = await keyStore.getSenderKey(groupId);
  let senderKey;
  let isNewKey = false;

  if (!senderKeyData) {
    // Generate new Sender Key
    senderKey = generateSenderKey();
    await keyStore.saveSenderKey(groupId, serializeSenderKeyForStorage(senderKey));
    isNewKey = true;
  } else {
    senderKey = deserializeSenderKey(senderKeyData);

    // ── TOMBSTONE LAZY ROTATION RECOVERY ──
    // If a tombstone was issued AFTER this key was created, it may exist on a compromised device.
    if (senderKey.createdAt) {
      const { data: tombstones, error: tsError } = await supabase
        .from('space_tombstones')
        .select('id')
        .eq('group_id', groupId)
        .gt('created_at', new Date(senderKey.createdAt).toISOString())
        .limit(1);

      if (!tsError && tombstones && tombstones.length > 0) {
        console.warn(`[e2ee] Tombstone detected after key generation! Forcing Lazy Rotation.`);
        senderKey = generateSenderKey();
        await keyStore.saveSenderKey(groupId, serializeSenderKeyForStorage(senderKey));
        isNewKey = true;
      }
    }
  }

  // ── O(1) ACK-aware SK distribution (CRYPTO-04) ──
  // Only distribute to devices that haven't ACKed yet.
  // New keys always require full distribution. Existing keys skip ACKed devices.
  let distCiphertexts: DistributionCiphertext[] = [];
  try {
    if (isNewKey) {
      // New key — full distribution to all devices (no ACKs exist yet)
      distCiphertexts = await prepareSenderKeyDistribution(groupId, senderKey);
    } else {
      // Existing key — check local ACKs to skip already-served devices
      const ackedSenders = await getAckedSenders(groupId);
      if (ackedSenders.size === 0) {
        // No ACKs recorded — fall back to full distribution
        distCiphertexts = await prepareSenderKeyDistribution(groupId, senderKey);
      } else {
        // Filter: only distribute to devices NOT yet ACKed
        distCiphertexts = await prepareSenderKeyDistribution(groupId, senderKey, ackedSenders);
      }
    }
  } catch (err) {
    if (isNewKey) {
      // New key with zero distribution = nobody can decrypt. Fail-closed.
      throw new Error(`Sender Key distribution failed. Aborting send to maintain E2EE integrity. ${err}`);
    }
    // Existing key — some members already have it. Non-fatal.
    console.warn('[e2ee] SK re-distribution failed (non-fatal):', err);
  }

  const { ciphertext, nonce, signature, iteration } = senderKeyEncrypt(senderKey, plaintext);

  // EAGER PERSIST: save advanced chain state to MAIN store immediately.
  // This ensures the next queued encrypt (within acquireSenderKeyLock) reads the
  // correct chain index — prevents rapid-fire chain index collisions.
  // Trade-off: if network fails, this chain index is "consumed" (wasted).
  // Signal Protocol handles gaps via the skipped key dictionary (BUG 16 fix).
  const serializedSK = serializeSenderKeyForStorage(senderKey);
  await keyStore.saveSenderKey(groupId, serializedSK);

  // Also save as unacked ratchet for crash recovery
  const pendingMsgId = `pending_${crypto.randomUUID()}`;
  await keyStore.saveUnackedRatchet(pendingMsgId, {
    sessionKey: groupId,
    sessionType: 'senderKey',
    serializedState: toBase64(serializedSK),
  });

  const commitSK = async () => {
    // ACK received — clean up unacked ratchet (state already persisted eagerly)
    await keyStore.ackRatchet(pendingMsgId);
  };

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
    commit: commitSK,
    distributionCiphertexts: distCiphertexts.length > 0 ? distCiphertexts : undefined,
  };
  }); // End acquireSenderKeyLock
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
  groupId: string
): Promise<DecryptedMessage> {
  // CRYPTO-05: Cross-tab exclusive lock per ratchet session / sender key group.
  // Group messages lock by groupId, 1:1 messages lock by senderId:deviceId.
  const lockFn = recipientId === '_group_'
    ? <T>(fn: () => Promise<T>) => acquireSenderKeyLock(`${groupId}:${senderId}`, fn)
    : <T>(fn: () => Promise<T>) => acquireRatchetLock(`${senderId}:${senderDeviceId}`, fn);

  return lockFn(async () => {
    // FIX 2: The Plaintext Cache (Idempotent Decrypt Guard)
    // Check media cache first (has full metadata), then text-only cache
    const cachedMedia = await keyStore.getDecryptedMedia(messageId);
    if (cachedMedia) {
      console.log(`[E2EE] Media cache hit for message ${messageId}`);
      return {
        text: cachedMedia.text,
        replyTo: null,
        mediaUrl: cachedMedia.mediaUrl,
        type: 'media',
        aesKeyBase64: cachedMedia.aesKeyBase64,
        ivBase64: cachedMedia.ivBase64,
        mimeType: cachedMedia.mimeType,
        ...(cachedMedia.inlineThumbnail && { inlineThumbnail: cachedMedia.inlineThumbnail }),
        ...(cachedMedia.linkPreview && { linkPreview: cachedMedia.linkPreview }),
      };
    }
    const cachedPlaintext = await keyStore.getDecryptedMessage(messageId);
    if (cachedPlaintext) {
      console.log(`[E2EE] Cache hit for message ${messageId}`);
      return { text: cachedPlaintext, replyTo: null, mediaUrl: null, type: 'message' };
    }

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
      // Check standard received-key path first
      let senderKeyData = await keyStore.getSenderKey(`${groupId}:${senderId}`);
      
      // Fallback: check self-authored key (stored as groupId only by encryptForSpace)
      // This handles: (a) solo spaces, (b) decrypting your own echoed messages
      if (!senderKeyData) {
        const myUserId = await getCurrentUserId();
        if (senderId === myUserId) {
          senderKeyData = await keyStore.getSenderKey(groupId);
        }
      }

      if (!senderKeyData) {
        // BUG 6 fix: retry after 2s — SK distribution may still be processing
        await new Promise(r => setTimeout(r, 2000));
        senderKeyData = await keyStore.getSenderKey(`${groupId}:${senderId}`);
        if (!senderKeyData) {
          const myUserId = await getCurrentUserId();
          if (senderId === myUserId) {
            senderKeyData = await keyStore.getSenderKey(groupId);
          }
        }
      }
      if (!senderKeyData) {
        // P2P SK recovery: request the missing key from the sender and wait
        const myUserId = await getCurrentUserId();
        const myDeviceId = await keyStore.getDeviceId();
        requestMissingSenderKey(groupId, senderId, myUserId, myDeviceId);

        const arrived = await waitForSenderKey(groupId, senderId, 10000);
        if (arrived) {
          senderKeyData = await keyStore.getSenderKey(`${groupId}:${senderId}`);
        }
      }
      if (!senderKeyData) {
        throw new Error('Decryption Failed: Missing Sender Key after recovery attempt');
      }

      const senderKey = deserializeSenderKey(senderKeyData);
      plaintext = senderKeyDecrypt(senderKey, ciphertext, nonce, signature, iteration);

      // Persist advanced state
      await keyStore.saveSenderKey(`${groupId}:${senderId}`, serializeSenderKeyForStorage(senderKey));

      // CRYPTO-04: mark this sender as ACKed so future encrypts skip distribution to them
      await markSkAcked(groupId, `${senderId}:${senderDeviceId ?? 0}`);
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
        console.error('[hello-e2ee] Missing sender device ID for message', messageId);
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
        let myOneTimePreKey: RawKeyPair | null = null;

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
            throw new Error('[hello-e2ee] Missing X3DH ephemeral key — cannot establish session');
          }

          const otkId = x3dhMeta?.otkId;
          if (otkId) {
            myOneTimePreKey = await keyStore.getOneTimePreKey(otkId);
          }

          const sharedSecret = x3dhRespond(
            { publicKey: curve25519Public, privateKey: curve25519Private },
            signedPreKey,
            myOneTimePreKey, // Now using the explicit OTK
            peerIdentityCurve,
            peerEphemeralPublic
          );

          // Responder OTK cleanup
          if (otkId && myOneTimePreKey) {
            await keyStore.deleteOneTimePreKey(otkId);
            console.log(`[hello-e2ee] Receiver cleaned up consumed OTK ${otkId}`);
          }

          session = initSessionAsResponder(sharedSecret, signedPreKey);
        } else {
          // Legacy: no X3DH metadata (messages from before wiring update)
          const myRatchetKey = { publicKey: new Uint8Array(32), privateKey: new Uint8Array(32) };
          session = initSessionAsResponder(new Uint8Array(32), myRatchetKey);
        }
      } else {
        session = deserializeSession(sessionData);
      }

      // ratchetDecrypt now takes encrypted header bytes directly
      plaintext = ratchetDecrypt(session, ciphertext, nonce, encryptedHeader);
      await keyStore.saveSession(senderId, senderDeviceId, serializeSession(session));
    }

    // Runtime payload validation — prevents prototype pollution from crafted E2EE payloads
    const raw = JSON.parse(fromBytes(plaintext));

    // Strict type check — only accept expected fields, reject everything else
    const validated: DecryptedMessage = {
      text: typeof raw.text === 'string' ? raw.text : '[invalid message]',
      replyTo: typeof raw.replyTo === 'string' ? raw.replyTo : null,
      mediaUrl: typeof raw.mediaUrl === 'string' ? raw.mediaUrl : null,
      type: raw.type === 'media' ? 'media' : 'message',
      ...(raw.type === 'media' && {
        aesKeyBase64: typeof raw.aesKeyBase64 === 'string' ? raw.aesKeyBase64 : undefined,
        ivBase64: typeof raw.ivBase64 === 'string' ? raw.ivBase64 : undefined,
        mimeType: typeof raw.mimeType === 'string' ? raw.mimeType : undefined,
        inlineThumbnail: typeof raw.inlineThumbnail === 'string' ? raw.inlineThumbnail : undefined,
      }),
      ...(raw.linkPreview && typeof raw.linkPreview === 'object' && typeof raw.linkPreview.url === 'string' && {
        linkPreview: {
          url: raw.linkPreview.url as string,
          title: typeof raw.linkPreview.title === 'string' ? raw.linkPreview.title : undefined,
          description: typeof raw.linkPreview.description === 'string' ? raw.linkPreview.description : undefined,
          mediaUrl: typeof raw.linkPreview.mediaUrl === 'string' ? raw.linkPreview.mediaUrl : undefined,
          aesKeyBase64: typeof raw.linkPreview.aesKeyBase64 === 'string' ? raw.linkPreview.aesKeyBase64 : undefined,
          ivBase64: typeof raw.linkPreview.ivBase64 === 'string' ? raw.linkPreview.ivBase64 : undefined,
          mimeType: typeof raw.linkPreview.mimeType === 'string' ? raw.linkPreview.mimeType : undefined,
          inlineThumbnail: typeof raw.linkPreview.inlineThumbnail === 'string' ? raw.linkPreview.inlineThumbnail : undefined,
        },
      }),
    };

    if (validated.text !== '[invalid message]') {
      if (validated.type === 'media' && validated.mediaUrl && validated.aesKeyBase64 && validated.ivBase64 && validated.mimeType) {
        // Media message — save full metadata for reload survival
        await keyStore.saveDecryptedMedia(messageId, {
          text: validated.text,
          mediaUrl: validated.mediaUrl,
          aesKeyBase64: validated.aesKeyBase64,
          ivBase64: validated.ivBase64,
          mimeType: validated.mimeType,
          ...(validated.inlineThumbnail && { inlineThumbnail: validated.inlineThumbnail }),
          ...(validated.linkPreview && { linkPreview: validated.linkPreview }),
        });
      }
      // Also cache linkPreview for text messages (no media) in the media store
      if (validated.type === 'message' && validated.linkPreview) {
        await keyStore.saveDecryptedMedia(messageId, {
          text: validated.text,
          mediaUrl: validated.linkPreview.mediaUrl ?? '',
          aesKeyBase64: validated.linkPreview.aesKeyBase64 ?? '',
          ivBase64: validated.linkPreview.ivBase64 ?? '',
          mimeType: validated.linkPreview.mimeType ?? '',
          linkPreview: validated.linkPreview,
        });
      }
      await keyStore.saveDecryptedMessage(messageId, validated.text);
    }

    return validated;
  }); // End acquireRatchetLock / acquireSenderKeyLock
}

// ═══════════════════════════════════════════════════════════════
// SK RECOVERY RESPONSE (crypto.md #19)
// ═══════════════════════════════════════════════════════════════

/**
 * Handle incoming SenderKeyRequest (NACK) from a peer who can't decrypt
 * our Sender Key messages. Re-send the SK distribution via 1:1 Double Ratchet.
 *
 * This is the response side of the SK recovery protocol:
 * 1. Peer broadcasts sk_request on the chat channel
 * 2. subscribeToSKRequests() validates membership + key bundle
 * 3. This function does the crypto: encrypt our SK via Double Ratchet to the requester
 * 4. POST the distribution message via /api/message for durability
 *
 * Uses 1:1 encryption (not group SK) so the requester can always decrypt it.
 */
export async function respondToSenderKeyRequest(
  groupId: string,
  requesterId: string,
  requesterDeviceId: number,
): Promise<void> {
  await initCrypto();

  // 1. Get our current Sender Key for this group
  const skData = await keyStore.getSenderKey(groupId);
  if (!skData) {
    console.log(`[hello-sk-recovery] No SK for group ${groupId} — nothing to re-distribute`);
    return;
  }

  const senderKey = deserializeSenderKey(skData);
  const myDeviceId = await keyStore.getDeviceId();

  // 2. Serialize the SK for distribution (no private signing key — BUG 15 safe)
  const serializedKey = serializeSenderKeyForDistribution(senderKey);

  // 3. Encrypt via Double Ratchet (1:1) to the requester's device
  const session = await getOrEstablishSession(requesterId, requesterDeviceId);
  const { ciphertext, nonce, header } = ratchetEncrypt(session, serializedKey);

  // Persist the advanced session state
  await keyStore.saveSession(requesterId, requesterDeviceId, serializeSession(session));

  // Pack nonce + ciphertext
  const packed = new Uint8Array(nonce.length + ciphertext.length);
  packed.set(nonce, 0);
  packed.set(ciphertext, nonce.length);

  // Build header envelope with X3DH metadata for first-contact sessions
  const metaKey = `${requesterId}:${requesterDeviceId}`;
  const meta = x3dhSessionMeta.get(metaKey);
  let x3dh: { identityKey: string; ephemeralKey?: string; otkId?: string } | undefined;

  if (meta) {
    x3dh = {
      identityKey: meta.identityPub,
      ephemeralKey: meta.ephemeralPub,
      otkId: meta.otkId,
    };
    x3dhSessionMeta.delete(metaKey);
  }

  // 4. POST as a sender_key_dist message via the normal message pipeline
  const token = getSupabaseToken();
  if (!token) {
    console.warn('[hello-sk-recovery] No JWT — cannot send SK recovery response');
    return;
  }

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };

  try {
    const res = await fetch('/api/message', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        group_id: groupId,
        sender_device_id: myDeviceId,
        message_type: 'sender_key_dist',
        ciphertext: toBase64(packed),
        ratchet_header: buildHeaderEnvelope(header, x3dh),
        recipient_id: requesterId,
        recipient_device_id: requesterDeviceId,
      }),
    });

    if (!res.ok) {
      const errText = await res.text().catch(() => 'unknown');
      console.error(`[hello-sk-recovery] Response POST failed: ${res.status} ${errText}`);
      return;
    }

    console.log(`[hello-sk-recovery] Re-distributed SK to ${requesterId}:${requesterDeviceId} for group ${groupId}`);
  } catch (err) {
    console.warn('[hello-sk-recovery] Re-distribution POST failed:', err);
  }
}

/** Client-side message type guard — anti-injection defense */
export function resolveMessageContent(
  messageType: MessageType | string,
  serverContent: string | null,
  decryptedContent: string | null
): string {
  // E2EE message types — NEVER trust server content
  if (messageType === 'e2ee' || messageType === 'e2ee_hello') {
    return decryptedContent ?? '[decryption pending]';
  }
  // Unencrypted types — server content is authoritative
  if (messageType === 'hello' || messageType === 'system' || messageType === 'legacy') {
    return serverContent ?? '';
  }
  return serverContent ?? '';
}
