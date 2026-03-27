// XARK OS v2.0 — Double Ratchet Algorithm
// Per-message forward secrecy for 1:1 sanctuaries.
// Implements the Signal Protocol Double Ratchet specification.

import {
  generateDHKeyPair, dh, kdfRatchet, kdfChain,
  aesEncrypt, aesDecrypt, toBase64, fromBase64, hkdf
} from './primitives';
import type { SessionState, RatchetHeader, RawKeyPair } from './types';

const MAX_SKIP = 1000; // bounded skipped-key dictionary
const HEADER_KEY_INFO = 'XarkE2EE-header-key';

/** Initialize session as the initiator (Alice — sends first message) */
export function initSessionAsInitiator(
  sharedSecret: Uint8Array,
  peerRatchetKey: Uint8Array
): SessionState {
  const sendRatchetKey = generateDHKeyPair();
  const dhOutput = dh(sendRatchetKey.privateKey, peerRatchetKey);
  const { newRootKey, chainKey } = kdfRatchet(sharedSecret, dhOutput);

  // Derive a stable header secret from the original shared secret
  // This MUST be the same on both sides
  const headerSecret = hkdf(sharedSecret, new Uint8Array(32), 'XarkE2EE-header-secret', 32);

  return {
    rootKey: newRootKey,
    sendChainKey: chainKey,
    recvChainKey: null,
    sendRatchetKey,
    recvRatchetKey: peerRatchetKey,
    sendMessageNumber: 0,
    recvMessageNumber: 0,
    previousSendCount: 0,
    skippedKeys: new Map(),
    headerSecret,  // stable across both sides
  };
}

/** Initialize session as the responder (Bob — receives first message) */
export function initSessionAsResponder(
  sharedSecret: Uint8Array,
  myRatchetKey: RawKeyPair
): SessionState {
  const headerSecret = hkdf(sharedSecret, new Uint8Array(32), 'XarkE2EE-header-secret', 32);

  return {
    rootKey: sharedSecret,
    sendChainKey: null,
    recvChainKey: null,
    sendRatchetKey: myRatchetKey,
    recvRatchetKey: null,
    sendMessageNumber: 0,
    recvMessageNumber: 0,
    previousSendCount: 0,
    skippedKeys: new Map(),
    headerSecret,
  };
}

/** Encrypt a message using the Double Ratchet */
export function ratchetEncrypt(
  session: SessionState,
  plaintext: Uint8Array
): { ciphertext: Uint8Array; nonce: Uint8Array; header: Uint8Array } {
  if (!session.sendChainKey || !session.sendRatchetKey) {
    throw new Error('Session not ready for sending');
  }

  const { messageKey, nextChainKey } = kdfChain(session.sendChainKey);
  session.sendChainKey = nextChainKey;

  const headerObj: RatchetHeader = {
    publicKey: session.sendRatchetKey.publicKey,
    previousCount: session.previousSendCount,
    messageNumber: session.sendMessageNumber,
  };

  session.sendMessageNumber++;

  // Encrypt message body
  const { ciphertext, nonce } = aesEncrypt(plaintext, messageKey);

  // P1-1 fix: encrypt the header with a key derived from the stable header secret
  const headerKey = hkdf(session.headerSecret, new Uint8Array(32), HEADER_KEY_INFO, 32);
  const headerJson = new TextEncoder().encode(JSON.stringify({
    publicKey: toBase64(headerObj.publicKey),
    previousCount: headerObj.previousCount,
    messageNumber: headerObj.messageNumber,
  }));
  const { ciphertext: headerCiphertext, nonce: headerNonce } = aesEncrypt(headerJson, headerKey);

  // Pack: headerNonce (24 bytes) + headerCiphertext
  const encryptedHeader = new Uint8Array(headerNonce.length + headerCiphertext.length);
  encryptedHeader.set(headerNonce, 0);
  encryptedHeader.set(headerCiphertext, headerNonce.length);

  return { ciphertext, nonce, header: encryptedHeader };
}

/** Decrypt a message using the Double Ratchet */
export function ratchetDecrypt(
  session: SessionState,
  ciphertext: Uint8Array,
  nonce: Uint8Array,
  encryptedHeader: Uint8Array  // P1-1: was RatchetHeader, now encrypted bytes
): Uint8Array {
  // P1-1 fix: decrypt the header first
  const headerKey = hkdf(session.headerSecret, new Uint8Array(32), HEADER_KEY_INFO, 32);
  const headerNonce = encryptedHeader.slice(0, 24);  // XChaCha20 nonce is 24 bytes
  const headerCiphertext = encryptedHeader.slice(24);
  const headerJson = aesDecrypt(headerCiphertext, headerNonce, headerKey);
  const headerObj = JSON.parse(new TextDecoder().decode(headerJson));
  const header: RatchetHeader = {
    publicKey: fromBase64(headerObj.publicKey),
    previousCount: headerObj.previousCount,
    messageNumber: headerObj.messageNumber,
  };

  // Try skipped keys first (out-of-order messages)
  const skipKey = `${toBase64(header.publicKey)}:${header.messageNumber}`;
  const skippedMk = session.skippedKeys.get(skipKey);
  if (skippedMk) {
    session.skippedKeys.delete(skipKey);
    return aesDecrypt(ciphertext, nonce, skippedMk);
  }

  // Check if we need a DH ratchet step (new ratchet key from peer)
  const needsRatchet = !session.recvRatchetKey ||
    toBase64(header.publicKey) !== toBase64(session.recvRatchetKey);

  if (needsRatchet) {
    // Skip any remaining messages in the current receiving chain
    if (session.recvChainKey) {
      skipMessages(session, header.previousCount);
    }

    // DH ratchet step
    dhRatchetStep(session, header.publicKey);
  }

  // Skip messages if needed (out-of-order within same chain)
  skipMessages(session, header.messageNumber);

  // Derive message key and advance chain
  if (!session.recvChainKey) throw new Error('No receive chain key');
  const { messageKey, nextChainKey } = kdfChain(session.recvChainKey);
  session.recvChainKey = nextChainKey;
  session.recvMessageNumber++;

  return aesDecrypt(ciphertext, nonce, messageKey);
}

/** Perform DH ratchet step when receiving a new ratchet public key */
function dhRatchetStep(session: SessionState, peerPublicKey: Uint8Array): void {
  session.previousSendCount = session.sendMessageNumber;
  session.sendMessageNumber = 0;
  session.recvMessageNumber = 0;
  session.recvRatchetKey = peerPublicKey;

  // Derive new receiving chain
  if (!session.sendRatchetKey) throw new Error('No send ratchet key');
  const dhRecv = dh(session.sendRatchetKey.privateKey, peerPublicKey);
  const { newRootKey: rootKey1, chainKey: recvChain } = kdfRatchet(session.rootKey, dhRecv);
  session.rootKey = rootKey1;
  session.recvChainKey = recvChain;

  // Generate new sending ratchet key pair
  session.sendRatchetKey = generateDHKeyPair();
  const dhSend = dh(session.sendRatchetKey.privateKey, peerPublicKey);
  const { newRootKey: rootKey2, chainKey: sendChain } = kdfRatchet(session.rootKey, dhSend);
  session.rootKey = rootKey2;
  session.sendChainKey = sendChain;
}

/** Skip messages and store their keys for later decryption */
function skipMessages(session: SessionState, until: number): void {
  if (!session.recvChainKey) return;

  while (session.recvMessageNumber < until) {
    const { messageKey, nextChainKey } = kdfChain(session.recvChainKey);
    session.recvChainKey = nextChainKey;

    if (session.recvRatchetKey) {
      const key = `${toBase64(session.recvRatchetKey)}:${session.recvMessageNumber}`;
      session.skippedKeys.set(key, messageKey);

      // Enforce bounded dictionary
      if (session.skippedKeys.size > MAX_SKIP) {
        const firstKey = session.skippedKeys.keys().next().value;
        if (firstKey) session.skippedKeys.delete(firstKey);
      }
    }

    session.recvMessageNumber++;
  }
}

// ── Session Serialization ──

/** Serialize session state to Uint8Array for storage */
export function serializeSession(session: SessionState): Uint8Array {
  const obj = {
    rootKey: toBase64(session.rootKey),
    sendChainKey: session.sendChainKey ? toBase64(session.sendChainKey) : null,
    recvChainKey: session.recvChainKey ? toBase64(session.recvChainKey) : null,
    sendRatchetKey: session.sendRatchetKey ? {
      pub: toBase64(session.sendRatchetKey.publicKey),
      priv: toBase64(session.sendRatchetKey.privateKey),
    } : null,
    recvRatchetKey: session.recvRatchetKey ? toBase64(session.recvRatchetKey) : null,
    sendMessageNumber: session.sendMessageNumber,
    recvMessageNumber: session.recvMessageNumber,
    previousSendCount: session.previousSendCount,
    skippedKeys: Object.fromEntries(
      Array.from(session.skippedKeys.entries()).map(([k, v]) => [k, toBase64(v)])
    ),
    headerSecret: toBase64(session.headerSecret),
  };
  return new TextEncoder().encode(JSON.stringify(obj));
}

/** Deserialize session state from Uint8Array */
export function deserializeSession(data: Uint8Array): SessionState {
  const obj = JSON.parse(new TextDecoder().decode(data));
  return {
    rootKey: fromBase64(obj.rootKey),
    sendChainKey: obj.sendChainKey ? fromBase64(obj.sendChainKey) : null,
    recvChainKey: obj.recvChainKey ? fromBase64(obj.recvChainKey) : null,
    sendRatchetKey: obj.sendRatchetKey ? {
      publicKey: fromBase64(obj.sendRatchetKey.pub),
      privateKey: fromBase64(obj.sendRatchetKey.priv),
    } : null,
    recvRatchetKey: obj.recvRatchetKey ? fromBase64(obj.recvRatchetKey) : null,
    sendMessageNumber: obj.sendMessageNumber,
    recvMessageNumber: obj.recvMessageNumber,
    previousSendCount: obj.previousSendCount,
    skippedKeys: new Map(
      Object.entries(obj.skippedKeys as Record<string, string>).map(
        ([k, v]) => [k, fromBase64(v)]
      )
    ),
    headerSecret: fromBase64(obj.headerSecret),
  };
}
