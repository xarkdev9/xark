// XARK OS v2.0 — Sender Keys (Group Encryption)
// One encrypt, all members decrypt. O(1) vs O(N) Double Ratchet.
// Key rotation on member leave for forward secrecy.

import {
  generateSigningKeyPair, sign, verify,
  aesEncrypt, aesDecrypt, kdfChain,
  randomBytes, toBase64, fromBase64
} from './primitives';
import type { SenderKeyState, RawKeyPair } from './types';

// BUG 16 fix: bounded skipped-key dictionary for out-of-order group messages
const MAX_SK_SKIP = 1000;
// Cache: "chainKeyB64:iteration" -> messageKey (Uint8Array)
const skippedSenderKeys = new Map<string, Uint8Array>();

/** Generate a new Sender Key for a group space */
export function generateSenderKey(): SenderKeyState {
  return {
    chainKey: randomBytes(32),
    signingKey: generateSigningKeyPair(),
    iteration: 0,
    createdAt: Date.now(),
  };
}

/** Encrypt a group message with the sender's Sender Key */
export function senderKeyEncrypt(
  state: SenderKeyState,
  plaintext: Uint8Array
): { ciphertext: Uint8Array; nonce: Uint8Array; signature: Uint8Array; iteration: number } {
  // Derive message key from chain and advance
  const { messageKey, nextChainKey } = kdfChain(state.chainKey);
  state.chainKey = nextChainKey;
  state.iteration++;

  // Encrypt with derived message key
  const { ciphertext, nonce } = aesEncrypt(plaintext, messageKey);

  // Sign for authenticity
  const toSign = new Uint8Array(ciphertext.length + nonce.length);
  toSign.set(ciphertext, 0);
  toSign.set(nonce, ciphertext.length);
  const signature = sign(toSign, state.signingKey.privateKey);

  return { ciphertext, nonce, signature, iteration: state.iteration };
}

/** Decrypt a group message using the sender's Sender Key */
export function senderKeyDecrypt(
  state: SenderKeyState,
  ciphertext: Uint8Array,
  nonce: Uint8Array,
  signature: Uint8Array,
  targetIteration: number
): Uint8Array {
  // Verify signature first (always, even for cached keys)
  const toVerify = new Uint8Array(ciphertext.length + nonce.length);
  toVerify.set(ciphertext, 0);
  toVerify.set(nonce, ciphertext.length);
  if (!verify(signature, toVerify, state.signingKey.publicKey)) {
    throw new Error('SenderKey: Invalid message signature');
  }

  // BUG 16 fix: check skipped key cache first
  const chainId = toBase64(state.chainKey);
  const skipKey = `${chainId}:${targetIteration}`;
  const cachedMk = skippedSenderKeys.get(skipKey);
  if (cachedMk) {
    skippedSenderKeys.delete(skipKey);
    return aesDecrypt(ciphertext, nonce, cachedMk);
  }

  // Advance chain to target, caching intermediate keys
  let currentChainKey = state.chainKey;
  let currentIteration = state.iteration;

  while (currentIteration < targetIteration - 1) {
    const { messageKey: skippedMk, nextChainKey } = kdfChain(currentChainKey);
    currentIteration++;

    // Cache the skipped message key
    const cacheKey = `${chainId}:${currentIteration}`;
    skippedSenderKeys.set(cacheKey, skippedMk);

    // Enforce bounded dictionary — evict oldest
    if (skippedSenderKeys.size > MAX_SK_SKIP) {
      const firstKey = skippedSenderKeys.keys().next().value;
      if (firstKey) skippedSenderKeys.delete(firstKey);
    }

    currentChainKey = nextChainKey;
  }

  // Derive the actual message key at targetIteration
  const { messageKey, nextChainKey } = kdfChain(currentChainKey);

  // Update state to latest known position
  if (currentIteration + 1 >= state.iteration) {
    state.chainKey = nextChainKey;
    state.iteration = currentIteration + 1;
  }

  return aesDecrypt(ciphertext, nonce, messageKey);
}

/** Clear the skipped key cache — used in testing and on space leave */
export function clearSkippedSenderKeys(): void {
  skippedSenderKeys.clear();
}

// ── Serialization ──

/** Serialize for LOCAL STORAGE ONLY — includes private signing key.
 *  NEVER send the output of this function over the network. */
export function serializeSenderKeyForStorage(state: SenderKeyState): Uint8Array {
  const obj = {
    chainKey: toBase64(state.chainKey),
    signingKey: {
      pub: toBase64(state.signingKey.publicKey),
      priv: toBase64(state.signingKey.privateKey),
    },
    iteration: state.iteration,
    ...(state.createdAt && { createdAt: state.createdAt }),
  };
  return new TextEncoder().encode(JSON.stringify(obj));
}

/** Serialize for DISTRIBUTION to group members — NEVER includes private signing key.
 *  Recipients only need the public key for signature verification. */
export function serializeSenderKeyForDistribution(state: SenderKeyState): Uint8Array {
  const obj = {
    chainKey: toBase64(state.chainKey),
    signingKey: {
      pub: toBase64(state.signingKey.publicKey),
      // Private key INTENTIONALLY OMITTED — BUG 15 fix
    },
    iteration: state.iteration,
    ...(state.createdAt && { createdAt: state.createdAt }),
  };
  return new TextEncoder().encode(JSON.stringify(obj));
}

/** Deserialize Sender Key state (handles both storage and distribution formats) */
export function deserializeSenderKey(data: Uint8Array): SenderKeyState {
  const obj = JSON.parse(new TextDecoder().decode(data));
  return {
    chainKey: fromBase64(obj.chainKey),
    signingKey: {
      publicKey: fromBase64(obj.signingKey.pub),
      // Private key absent in distributed keys — empty array signals "received key"
      privateKey: obj.signingKey.priv ? fromBase64(obj.signingKey.priv) : new Uint8Array(0),
    } as RawKeyPair,
    iteration: obj.iteration,
    createdAt: obj.createdAt,
  };
}

/** Create a distribution message — ALWAYS uses safe serialization (no private key) */
export function createSenderKeyDistribution(
  spaceId: string,
  state: SenderKeyState
): { spaceId: string; serializedKey: Uint8Array } {
  return {
    spaceId,
    serializedKey: serializeSenderKeyForDistribution(state),
  };
}

/** Rotate Sender Key for a space — called when a member leaves.
 *  Generates fresh key material. Old key should be archived for historical decrypt. */
export function rotateSenderKey(): SenderKeyState {
  return generateSenderKey();
}
