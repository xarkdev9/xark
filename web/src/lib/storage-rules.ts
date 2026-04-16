/// Firebase Storage security rules documentation.
/// The actual rules are in app/firebase-storage.rules.
///
/// Key security model:
/// - E2EE media blobs are stored under /groups/{groupId}/
/// - Only authenticated users with group membership can read/write
/// - Membership verified via custom JWT claim 'group_ids'
/// - 2GB max file size (WhatsApp parity)
/// - Profile photos under /profiles/{userId}/ (write = own only)
///
/// The server never sees the plaintext — security comes from the
/// AES key being delivered via E2EE Double Ratchet, not from storage rules.
/// Storage rules are defense-in-depth against direct URL access.

export const STORAGE_PATHS = {
  groupMedia: (groupId: string, mediaId: string) => `groups/${groupId}/${mediaId}`,
  profilePhoto: (userId: string) => `profiles/${userId}/photo`,
} as const;
