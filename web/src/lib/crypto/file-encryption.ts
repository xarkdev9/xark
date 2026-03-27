// XARK OS v2.0 — File Encryption (Symmetric-Blob Pattern)
// AES-256-GCM encrypt/decrypt for media files before Firebase upload.
// Uses native Web Crypto API (crypto.subtle). Client-side only.
//
// Flow: File -> encryptFile() -> { encryptedBlob, aesKeyBase64, ivBase64 }
//       encryptedBlob -> Firebase Storage (server never sees plaintext)
//       aesKeyBase64 + ivBase64 -> sent inside DecryptedMessage.mediaUrl via Double Ratchet
//
// Decrypt: Firebase download -> decryptFile() -> object URL for <img>/<video>

const AES_ALGO = 'AES-GCM';
const AES_KEY_BITS = 256;
const IV_BYTES = 12; // AES-GCM standard IV length

/** Base64 encode a Uint8Array */
function toB64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

/** Base64 decode to Uint8Array */
function fromB64(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export interface EncryptedFile {
  /** AES-GCM encrypted blob — upload this to Firebase Storage */
  encryptedBlob: Blob;
  /** Base64-encoded 256-bit AES key — send via E2EE channel */
  aesKeyBase64: string;
  /** Base64-encoded 12-byte IV — send via E2EE channel */
  ivBase64: string;
}

/**
 * Encrypt a file with a one-time AES-256-GCM key.
 *
 * Generates a fresh random key and IV for each file. The encrypted blob
 * is safe to upload to untrusted storage (Firebase). The key and IV must
 * be transmitted via the E2EE message channel (Double Ratchet / Sender Key).
 */
export async function encryptFile(file: File): Promise<EncryptedFile> {
  // Generate one-time AES key (extractable so we can export the raw bytes)
  const aesKey = await crypto.subtle.generateKey(
    { name: AES_ALGO, length: AES_KEY_BITS },
    true, // extractable — we need to export and send via E2EE
    ['encrypt', 'decrypt']
  );

  // Generate random IV (slice to get a clean ArrayBuffer-backed Uint8Array)
  const iv = new Uint8Array(crypto.getRandomValues(new Uint8Array(IV_BYTES)).buffer.slice(0));

  // Read file into ArrayBuffer
  const plaintext = await file.arrayBuffer();

  // Encrypt
  const ciphertext = await crypto.subtle.encrypt(
    { name: AES_ALGO, iv: iv as BufferSource },
    aesKey,
    plaintext
  );

  // Export AES key as raw bytes -> base64
  const rawKey = await crypto.subtle.exportKey('raw', aesKey);
  const aesKeyBase64 = toB64(new Uint8Array(rawKey));
  const ivBase64 = toB64(iv);

  // Wrap ciphertext as Blob (preserves binary for Firebase upload)
  const encryptedBlob = new Blob([ciphertext], { type: 'application/octet-stream' });

  return { encryptedBlob, aesKeyBase64, ivBase64 };
}

/**
 * Decrypt an encrypted blob back to a usable object URL.
 *
 * Downloads the encrypted blob from Firebase, decrypts with the AES key
 * and IV received via the E2EE message channel, and returns a blob URL
 * suitable for <img src> or <video src>.
 *
 * The caller is responsible for revoking the URL via URL.revokeObjectURL()
 * when the component unmounts to prevent memory leaks.
 */
export async function decryptFile(
  encryptedBlob: Blob,
  aesKeyBase64: string,
  ivBase64: string,
  mimeType: string
): Promise<string> {
  // Import AES key from base64
  const rawKey = fromB64(aesKeyBase64).buffer.slice(0) as ArrayBuffer;
  const aesKey = await crypto.subtle.importKey(
    'raw',
    rawKey,
    { name: AES_ALGO, length: AES_KEY_BITS },
    false, // non-extractable — decrypt only
    ['decrypt']
  );

  // Read encrypted blob into ArrayBuffer
  const ciphertext = await encryptedBlob.arrayBuffer();

  // Decrypt
  const iv = new Uint8Array(fromB64(ivBase64).buffer.slice(0));
  const plaintext = await crypto.subtle.decrypt(
    { name: AES_ALGO, iv: iv as BufferSource },
    aesKey,
    ciphertext
  );

  // Create decrypted blob with the original MIME type
  const decryptedBlob = new Blob([plaintext], { type: mimeType });

  return URL.createObjectURL(decryptedBlob);
}
