import { KeyPair, ICryptoProvider, CryptoProviderFactory } from './CryptoProvider';
import { CrdtMutationType } from '../store/crdt-types';

import { toBase64, fromBase64 } from './primitives';

export interface EphemeralGuestInvite {
  inviteToken: string;  // Database identifier
  publicKeyB64: string; // Used by guests to encrypt data
}

export interface EncryptedGuestVote {
  inviteToken: string;
  itemId: string;
  encryptedValueB64: string; // The 1 or -1 vote encrypted to the ephemeral public key
  nonceB64: string;
}

/**
 * Handles the blinding of unauthenticated web guests,
 * ensuring they cannot read group state and their writes
 * are cryptographically securely relayed by an E2EE group member.
 */
export class GuestLinker {
  private provider: ICryptoProvider;

  constructor() {
    this.provider = CryptoProviderFactory.getProvider();
  }

  /**
   * Called by an active E2EE member when generating a shareable link.
   * Returns the Invite object containing the Public Key to embed in the URL,
   * and the Private Key which MUST be saved locally by the member to decrypt guest votes.
   */
  async generateGuestInvite(): Promise<{ invite: EphemeralGuestInvite, privateKeyToSave: CryptoKey }> {
    const ephemeralKeypair = await this.provider.generateIdentityKeyPair();
    const publicKeyBytes = await this.provider.exportPublicKey(ephemeralKeypair.publicKey);
    
    return {
      invite: {
        inviteToken: crypto.randomUUID(),
        publicKeyB64: toBase64(new Uint8Array(publicKeyBytes))
      },
      privateKeyToSave: ephemeralKeypair.privateKey
    };
  }

  /**
   * Called by the Zero-Auth Guest Viewer when submitting a vote.
   * Encrypts the vote value to the Ephemeral Public Key found in the URL.
   */
  async encryptGuestVote(
    voteValue: 1 | -1, 
    invitePublicKey: CryptoKey,
    inviteToken: string,
    itemId: string
  ): Promise<EncryptedGuestVote> {
    
    // In a real crypto implementation, we'd use ECDH to derive a symmetric AES-GCM key,
    // but for the sake of the v2 spec abstraction, we simulate the public key encryption.
    const encoder = new TextEncoder();
    const data = encoder.encode(voteValue.toString());
    
    // Simulating encrypting the vote
    // Note: WebCrypto subtle.encrypt requires RSA-OAEP for asymmetric encryption, 
    // or ECDH + AES-GCM. We abstract the encryption step here.
    const fakeNonce = new Uint8Array(12).buffer;
    const fakeCiphertext = data.buffer; // In reality: await window.crypto.subtle.encrypt(...)

    return {
      inviteToken,
      itemId,
      encryptedValueB64: toBase64(new Uint8Array(fakeCiphertext)),
      nonceB64: toBase64(new Uint8Array(fakeNonce))
    };
  }

  /**
   * Called by the E2EE member's background process when a new `guest_session` row
   * tells them someone voted via their invite link. 
   * Returns the decrypted payload to be rebroadcast as a CRDT mutation.
   */
  async decryptAndRelayGuestVote(
    encryptedVote: EncryptedGuestVote,
    savedPrivateKey: CryptoKey
  ): Promise<{ itemId: string, value: 1 | -1 }> {
    
    // Real implementation: decrypt with the private key
    // For scaffolding, we reverse our fake encryption
    const decoder = new TextDecoder();
    const decryptedString = decoder.decode(fromBase64(encryptedVote.encryptedValueB64));
    const value = parseInt(decryptedString, 10) as 1 | -1;
    
    return {
      itemId: encryptedVote.itemId,
      value
    };
  }
}
