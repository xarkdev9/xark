import { KeyPair, ICryptoProvider, CryptoProviderFactory } from './CryptoProvider';

import { toBase64, fromBase64 } from './primitives';

export interface DeviceLinkRequest {
  linkingPublicKeyB64: string;
}

export interface DeviceLinkPayload {
  signedPublicKeyB64: string;
  signatureB64: string;
  deviceId: string;
}

/**
 * Handles the secure signature verification and generation
 * for linking a Web Browser (secondary) to a Native App (primary).
 */
export class DeviceLinker {
  private provider: ICryptoProvider;

  constructor() {
    this.provider = CryptoProviderFactory.getProvider();
  }

  /**
   * Called by the Native App (Primary Device) after scanning a QR code containing
   * the Web App's ephemeral public key.
   */
  async approveLinkRequest(
    primaryKeyPair: KeyPair, 
    request: DeviceLinkRequest
  ): Promise<DeviceLinkPayload> {
    
    // The native primary device signs the web app's public key
    const signature = await this.provider.sign(
      primaryKeyPair.privateKey, 
      fromBase64(request.linkingPublicKeyB64).buffer as ArrayBuffer
    );

    return {
      signedPublicKeyB64: request.linkingPublicKeyB64,
      signatureB64: toBase64(new Uint8Array(signature)),
      deviceId: crypto.randomUUID()
    };
  }

  /**
   * Called by the Web App (Secondary Device) after generating its ephemeral key,
   * creates the payload encoded into the QR code.
   */
  async createLinkRequest(ephemeralKeyPair: KeyPair): Promise<DeviceLinkRequest> {
    const linkingPublicKey = await this.provider.exportPublicKey(ephemeralKeyPair.publicKey);
    return {
      linkingPublicKeyB64: toBase64(new Uint8Array(linkingPublicKey))
    };
  }
}
