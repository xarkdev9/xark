/// Web implementation of hardware key wrapping using WebCrypto.
/// Uses a non-extractable AES-256-GCM key stored in the CryptoKey store.

let wrappingKey: CryptoKey | null = null;

export async function initializeWrappingKey(): Promise<void> {
  if (wrappingKey) return;
  // Generate non-extractable wrapping key
  wrappingKey = await crypto.subtle.generateKey(
    { name: 'AES-GCM', length: 256 },
    false, // NOT extractable — browser enforces this
    ['encrypt', 'decrypt'],
  );
}

export async function wrapKey(plaintext: Uint8Array): Promise<Uint8Array> {
  if (!wrappingKey) throw new Error('Wrapping key not initialized');
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    wrappingKey,
    plaintext,
  );
  // Format: iv(12) + ciphertext + tag
  const result = new Uint8Array(12 + ciphertext.byteLength);
  result.set(iv);
  result.set(new Uint8Array(ciphertext), 12);
  return result;
}

export async function unwrapKey(wrapped: Uint8Array): Promise<Uint8Array> {
  if (!wrappingKey) throw new Error('Wrapping key not initialized');
  const iv = wrapped.slice(0, 12);
  const ciphertext = wrapped.slice(12);
  const plaintext = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv },
    wrappingKey,
    ciphertext,
  );
  return new Uint8Array(plaintext);
}

export async function isHardwareAvailable(): Promise<boolean> {
  // WebCrypto non-extractable keys are software-backed but enforced
  // by the browser
  return typeof crypto !== 'undefined' && typeof crypto.subtle !== 'undefined';
}

export async function deleteWrappingKey(): Promise<void> {
  wrappingKey = null;
}
