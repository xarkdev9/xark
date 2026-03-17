// XARK OS v2.0 — E2EE Type Definitions
// Shared types for the crypto module.

/** Raw key pair — Ed25519 or Curve25519 */
export interface RawKeyPair {
  publicKey: Uint8Array;
  privateKey: Uint8Array;
}

/** WebCrypto-backed identity key — non-extractable private key */
export interface WebCryptoIdentityKey {
  publicKeyRaw: Uint8Array;        // extractable raw bytes for distribution
  privateKeyCryptoKey: CryptoKey;   // non-extractable, stays in WebCrypto subsystem
  publicKeyCryptoKey: CryptoKey;    // for WebCrypto sign/verify operations
}

/** Identity key pair (Ed25519 for signing, converts to Curve25519 for DH) */
export interface IdentityKeyPair {
  ed25519: RawKeyPair;
  curve25519Public: Uint8Array;  // derived from ed25519 via birational mapping
  curve25519Private: Uint8Array;
}

/** Signed pre-key with its numeric ID */
export interface SignedPreKey {
  id: number;
  keyPair: RawKeyPair;  // Curve25519
  signature: Uint8Array; // Ed25519 signature over public key
}

/** One-time pre-key */
export interface OneTimePreKey {
  id: string;
  keyPair: RawKeyPair;  // Curve25519
}

/** Public key bundle fetched from server */
export interface PublicKeyBundle {
  identityKey: Uint8Array;      // Ed25519 public
  signedPreKey: Uint8Array;     // Curve25519 public
  signedPreKeyId: number;
  preKeySig: Uint8Array;        // Ed25519 signature
  oneTimePreKey?: Uint8Array;   // Curve25519 public (may be exhausted)
  oneTimePreKeyId?: string;     // ID of consumed OTK (for X3DH responder lookup)
}

/** Double Ratchet session state */
export interface SessionState {
  rootKey: Uint8Array;
  sendChainKey: Uint8Array | null;
  recvChainKey: Uint8Array | null;
  sendRatchetKey: RawKeyPair | null;
  recvRatchetKey: Uint8Array | null;  // peer's public ratchet key
  sendMessageNumber: number;
  recvMessageNumber: number;
  previousSendCount: number;
  skippedKeys: Map<string, Uint8Array>;  // "pubkey:msgNum" -> message key
}

/** Ratchet header sent with each encrypted message */
export interface RatchetHeader {
  publicKey: Uint8Array;   // sender's current ratchet public key
  previousCount: number;   // number of messages in previous sending chain
  messageNumber: number;   // message number in current sending chain
}

export interface SenderKeyState {
  chainKey: Uint8Array;
  signingKey: RawKeyPair;  // Ed25519 for signing group messages
  iteration: number;
  createdAt?: number;      // timestamp of key generation for Tombstone expiry checks
}

/** Encrypted message payload */
export interface EncryptedPayload {
  ciphertext: Uint8Array;
  header?: RatchetHeader;   // present for Double Ratchet, absent for Sender Key
  senderKeyId?: string;     // present for Sender Key messages
}

/** Decrypted message content */
export interface DecryptedMessage {
  text: string;
  replyTo: string | null;
  mediaUrl: string | null;
  type: 'message' | 'media';
}

/** Message types in the database */
export type MessageType = 'e2ee' | 'xark' | 'system' | 'legacy' | 'sender_key_dist';

/** Key backup blob structure */
export interface KeyBackupBlob {
  identityKey: {
    ed25519Public: string;   // base64
    ed25519Private: string;  // base64
  };
  signedPreKey: {
    id: number;
    public: string;          // base64
    private: string;         // base64
  };
  senderKeys: {
    active: Record<string, string>;       // spaceId -> base64 serialized state
    historical: Record<string, string[]>; // spaceId -> base64 serialized states
  };
}

/** Constraint types */
export type ConstraintType = 'dietary' | 'accessibility' | 'alcohol' | 'budget' | 'date' | 'location_pref';

/** Detected constraint from message text */
export interface DetectedConstraint {
  type: ConstraintType;
  value: string;
  scope: 'global' | 'space';  // dietary/accessibility/alcohol = global, budget = space
}
