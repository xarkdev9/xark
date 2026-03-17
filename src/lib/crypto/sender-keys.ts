// XARK OS v2.0 — Sender Keys (Group Encryption)
// One encrypt, all members decrypt. O(1) vs O(N) Double Ratchet.
// Key rotation on member leave for forward secrecy.

import {
  generateSigningKeyPair, sign, verify,
  aesEncrypt, aesDecrypt, kdfChain,
  randomBytes, toBase64, fromBase64
} from './primitives';
import type { SenderKeyState, RawKeyPair } from './types';

/** Generate a new Sender Key for a group space */
export function generateSenderKey(): SenderKeyState {
  return {
    chainKey: randomBytes(32),
    signingKey: generateSigningKeyPair(),
    iteration: 0,
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
  // Verify signature first
  const toVerify = new Uint8Array(ciphertext.length + nonce.length);
  toVerify.set(ciphertext, 0);
  toVerify.set(nonce, ciphertext.length);
  if (!verify(signature, toVerify, state.signingKey.publicKey)) {
    throw new Error('SenderKey: Invalid message signature');
  }

  // Advance chain to one step before target (sender advanced AFTER deriving messageKey)
  let currentChainKey = state.chainKey;
  let currentIteration = state.iteration;

  while (currentIteration < targetIteration - 1) {
    const { nextChainKey } = kdfChain(currentChainKey);
    currentChainKey = nextChainKey;
    currentIteration++;
  }

  // Derive the message key at this chain position (same kdfChain the sender used)
  const { messageKey, nextChainKey } = kdfChain(currentChainKey);

  // Update state to latest known position
  if (currentIteration + 1 >= state.iteration) {
    state.chainKey = nextChainKey;
    state.iteration = currentIteration + 1;
  }

  return aesDecrypt(ciphertext, nonce, messageKey);
}

// ── Serialization ──

/** Serialize Sender Key state for storage or distribution.
 *  BUG 15 fix: private signing key is ONLY included for local storage (own key).
 *  Distribution to other members includes only the public key (for verification). */
export function serializeSenderKey(state: SenderKeyState, includePrivate = true): Uint8Array {
  const obj: Record<string, unknown> = {
    chainKey: toBase64(state.chainKey),
    signingKey: {
      pub: toBase64(state.signingKey.publicKey),
      ...(includePrivate && state.signingKey.privateKey.length > 0
        ? { priv: toBase64(state.signingKey.privateKey) }
        : {}),
    },
    iteration: state.iteration,
  };
  return new TextEncoder().encode(JSON.stringify(obj));
}

/** Deserialize Sender Key state */
export function deserializeSenderKey(data: Uint8Array): SenderKeyState {
  const obj = JSON.parse(new TextDecoder().decode(data));
  return {
    chainKey: fromBase64(obj.chainKey),
    signingKey: {
      publicKey: fromBase64(obj.signingKey.pub),
      // Private key may be absent in distributed keys (BUG 15 fix)
      privateKey: obj.signingKey.priv ? fromBase64(obj.signingKey.priv) : new Uint8Array(0),
    } as RawKeyPair,
    iteration: obj.iteration,
  };
}

/** Create a distribution message (sent via pairwise Double Ratchet session) */
export function createSenderKeyDistribution(
  spaceId: string,
  state: SenderKeyState
): { spaceId: string; serializedKey: Uint8Array } {
  return {
    spaceId,
    serializedKey: serializeSenderKey(state),
  };
}
