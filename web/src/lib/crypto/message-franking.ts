/// Cryptographic Message Franking for E2EE spam reporting.
/// When a user reports a message, the client unwraps ONLY that
/// message's encryption key and sends it to the moderation server.
/// The server can then decrypt only the reported message.
/// All other messages remain E2EE-protected.

export interface FrankingReport {
  messageId: string;
  groupId: string;
  reporterId: string;
  reportedUserId: string;
  /** The AES key used to encrypt this specific message */
  messageKey: string; // base64
  /** The encrypted ciphertext (from message_ciphertexts) */
  ciphertext: string; // base64
  /** The ratchet header (needed to derive the same key) */
  ratchetHeader?: string;
  reason: 'spam' | 'harassment' | 'illegal' | 'other';
  timestamp: number;
}

/**
 * Generate a franking report for a specific message.
 * This extracts the per-message key from the local ratchet state
 * so moderators can decrypt ONLY this message.
 */
export async function createFrankingReport(params: {
  messageId: string;
  groupId: string;
  reportedUserId: string;
  reason: FrankingReport['reason'];
}): Promise<FrankingReport | null> {
  try {
    // 1. Look up the message in the decrypted cache
    // 2. Get the per-message key from the ratchet session
    // 3. Package with the ciphertext for server verification

    // The key insight: Double Ratchet derives a unique key per message.
    // We can expose ONE key without compromising any other messages.
    // The server verifies: decrypt(ciphertext, messageKey) produces
    // a valid plaintext matching the reported content.

    return {
      messageId: params.messageId,
      groupId: params.groupId,
      reporterId: '', // Set by caller
      reportedUserId: params.reportedUserId,
      messageKey: '', // TODO: Extract from ratchet session
      ciphertext: '', // TODO: Fetch from message_ciphertexts
      reason: params.reason,
      timestamp: Date.now(),
    };
  } catch {
    return null;
  }
}

/**
 * Submit a franking report to the moderation server.
 */
export async function submitFrankingReport(report: FrankingReport): Promise<boolean> {
  try {
    const response = await fetch('/api/report', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(report),
    });
    return response.ok;
  } catch {
    return false;
  }
}
