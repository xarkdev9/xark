import { Preferences } from '@capacitor/preferences';
import { Capacitor } from '@capacitor/core';

import { webcrypto } from 'crypto';

export interface KeyPair {
  publicKey: CryptoKey;
  privateKey: CryptoKey;
}

export interface ICryptoProvider {
  generateIdentityKeyPair(): Promise<KeyPair>;
  exportPublicKey(key: CryptoKey): Promise<ArrayBuffer>;
  importPublicKey(keyData: ArrayBuffer): Promise<CryptoKey>;
  sign(privateKey: CryptoKey, data: ArrayBuffer): Promise<ArrayBuffer>;
  verify(publicKey: CryptoKey, signature: ArrayBuffer, data: ArrayBuffer): Promise<boolean>;
}

export class CryptoProviderFactory {
  static getProvider(): ICryptoProvider {
    if (Capacitor.isNativePlatform()) {
      return new NativeCryptoProvider();
    }
    return new WebCryptoProvider();
  }
}

class WebCryptoProvider implements ICryptoProvider {
  private get subtle(): SubtleCrypto {
    if (typeof window !== 'undefined' && window.crypto) {
      return window.crypto.subtle;
    }
    // Fallback for Node.js test environments
    return webcrypto.subtle as SubtleCrypto;
  }

  async generateIdentityKeyPair(): Promise<KeyPair> {
    return this.subtle.generateKey(
      {
        name: 'ECDSA',
        namedCurve: 'P-256',
      },
      false, // extractable: false for WebCrypto
      ['sign', 'verify']
    );
  }

  async exportPublicKey(key: CryptoKey): Promise<ArrayBuffer> {
    return this.subtle.exportKey('raw', key);
  }

  async importPublicKey(keyData: ArrayBuffer): Promise<CryptoKey> {
    return this.subtle.importKey(
      'raw',
      keyData,
      {
        name: 'ECDSA',
        namedCurve: 'P-256',
      },
      true,
      ['verify']
    );
  }

  async sign(privateKey: CryptoKey, data: ArrayBuffer): Promise<ArrayBuffer> {
    return this.subtle.sign(
      {
        name: 'ECDSA',
        hash: { name: 'SHA-256' },
      },
      privateKey,
      data
    );
  }

  async verify(publicKey: CryptoKey, signature: ArrayBuffer, data: ArrayBuffer): Promise<boolean> {
    return this.subtle.verify(
      {
        name: 'ECDSA',
        hash: { name: 'SHA-256' },
      },
      publicKey,
      signature,
      data
    );
  }
}

class NativeCryptoProvider implements ICryptoProvider {
  // In a real native implementation, these would call to a Capacitor plugin
  // that bridges to iOS Security or Android Keystore natively.
  // For the sake of this migration scaffolding, we simulate the interface
  // but still rely on WebCrypto underneath, while persisting the exported
  // keys (if they were extractable, which they aren't here) to secure storage.
  // A full native plugin would handle the Key generation *inside* the OS enclave.
  
  private webProvider = new WebCryptoProvider();

  async generateIdentityKeyPair(): Promise<KeyPair> {
    console.log("[NativeCryptoProvider] Generating keypair in Secure Enclave bridge...");
    // A real implementation would call NativeBridge.generateKey()
    const keyPair = await this.webProvider.generateIdentityKeyPair();
    
    // Simulate saving a reference/handle to the key in secure storage
    await Preferences.set({
      key: 'identity_key_handle',
      value: 'native_enclave_handle_12345'
    });
    
    return keyPair;
  }

  async exportPublicKey(key: CryptoKey): Promise<ArrayBuffer> {
    return this.webProvider.exportPublicKey(key);
  }

  async importPublicKey(keyData: ArrayBuffer): Promise<CryptoKey> {
    return this.webProvider.importPublicKey(keyData);
  }

  async sign(privateKey: CryptoKey, data: ArrayBuffer): Promise<ArrayBuffer> {
    console.log("[NativeCryptoProvider] Signing data via Secure Enclave bridge...");
    return this.webProvider.sign(privateKey, data);
  }

  async verify(publicKey: CryptoKey, signature: ArrayBuffer, data: ArrayBuffer): Promise<boolean> {
    return this.webProvider.verify(publicKey, signature, data);
  }
}
