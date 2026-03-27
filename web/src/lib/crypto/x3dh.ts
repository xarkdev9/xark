// XARK OS v2.0 — X3DH Key Agreement
// Extended Triple Diffie-Hellman for establishing 1:1 sessions.
// Used to initialize Double Ratchet sessions.

import { dh, hkdf, verify, ed25519PkToCurve25519, generateDHKeyPair } from './primitives';
import type { PublicKeyBundle, RawKeyPair } from './types';

const X3DH_INFO = 'XarkE2EE-x3dh';

/**
 * Initiator side of X3DH — creates shared secret for session setup.
 * Called by the person sending the first message.
 */
export function x3dhInitiate(
  myIdentityCurve25519: { publicKey: Uint8Array; privateKey: Uint8Array },
  peerBundle: PublicKeyBundle
): { sharedSecret: Uint8Array; ephemeralKey: RawKeyPair } {
  // BUG 11/13 hardening: validate initiator identity key
  if (!myIdentityCurve25519.privateKey.length || !myIdentityCurve25519.publicKey.length) {
    throw new Error('X3DH: Invalid initiator identity key — zero-length key material');
  }

  if (!peerBundle.identityKey.length || !peerBundle.signedPreKey.length) {
    throw new Error('X3DH: Invalid zero-length keys provided');
  }

  // Verify signed pre-key signature
  const isValid = verify(
    peerBundle.preKeySig,
    peerBundle.signedPreKey,
    peerBundle.identityKey // Ed25519 public key
  );
  if (!isValid) throw new Error('X3DH: Invalid signed pre-key signature');

  // Convert peer's Ed25519 identity key to Curve25519
  const peerIdentityCurve = ed25519PkToCurve25519(peerBundle.identityKey);

  // Generate ephemeral key pair
  const ephemeralKey = generateDHKeyPair();

  // Four DH computations
  const dh1 = dh(myIdentityCurve25519.privateKey, peerBundle.signedPreKey);   // IK_A x SPK_B
  const dh2 = dh(ephemeralKey.privateKey, peerIdentityCurve);                  // EK_A x IK_B
  const dh3 = dh(ephemeralKey.privateKey, peerBundle.signedPreKey);            // EK_A x SPK_B

  let ikm: Uint8Array;
  if (peerBundle.oneTimePreKey) {
    const dh4 = dh(ephemeralKey.privateKey, peerBundle.oneTimePreKey);         // EK_A x OTK_B
    ikm = concatBytes(dh1, dh2, dh3, dh4);
  } else {
    ikm = concatBytes(dh1, dh2, dh3);
  }

  const sharedSecret = hkdf(ikm, new Uint8Array(32), X3DH_INFO, 32);
  return { sharedSecret, ephemeralKey };
}

/**
 * Responder side of X3DH — derives same shared secret from initiator's message.
 * Called when receiving the first message in a session.
 */
export function x3dhRespond(
  myIdentityCurve25519: { publicKey: Uint8Array; privateKey: Uint8Array },
  mySignedPreKey: RawKeyPair,
  myOneTimePreKey: RawKeyPair | null,
  peerIdentityCurve25519Public: Uint8Array,
  peerEphemeralPublic: Uint8Array
): Uint8Array {
  // BUG 11 hardening: reject missing ephemeral key — cannot compute shared secret without it
  if (!peerEphemeralPublic || !peerEphemeralPublic.length) {
    throw new Error('X3DH: Missing peer ephemeral key — cannot compute shared secret');
  }
  if (!peerIdentityCurve25519Public || !peerIdentityCurve25519Public.length) {
    throw new Error('X3DH: Missing peer identity key');
  }
  if (!mySignedPreKey.privateKey.length) {
    throw new Error('X3DH: Invalid signed pre-key — zero-length private key');
  }

  const dh1 = dh(mySignedPreKey.privateKey, peerIdentityCurve25519Public);    // SPK_B x IK_A
  const dh2 = dh(myIdentityCurve25519.privateKey, peerEphemeralPublic);       // IK_B x EK_A
  const dh3 = dh(mySignedPreKey.privateKey, peerEphemeralPublic);             // SPK_B x EK_A

  let ikm: Uint8Array;
  if (myOneTimePreKey) {
    const dh4 = dh(myOneTimePreKey.privateKey, peerEphemeralPublic);          // OTK_B x EK_A
    ikm = concatBytes(dh1, dh2, dh3, dh4);
  } else {
    ikm = concatBytes(dh1, dh2, dh3);
  }

  return hkdf(ikm, new Uint8Array(32), X3DH_INFO, 32);
}

/** Concatenate multiple Uint8Arrays */
function concatBytes(...arrays: Uint8Array[]): Uint8Array {
  const total = arrays.reduce((sum, a) => sum + a.length, 0);
  const result = new Uint8Array(total);
  let offset = 0;
  for (const arr of arrays) {
    result.set(arr, offset);
    offset += arr.length;
  }
  return result;
}
