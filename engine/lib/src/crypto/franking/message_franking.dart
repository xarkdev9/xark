/// Cryptographic Message Franking for E2EE spam reporting.
/// Exposes per-message key for moderation without breaking E2EE.

class FrankingReport {
  final String messageId;
  final String groupId;
  final String reporterId;
  final String reportedUserId;
  final String messageKey; // base64 per-message key
  final String ciphertext; // base64
  final String? ratchetHeader;
  final String reason; // spam, harassment, illegal, other
  final int timestamp;

  const FrankingReport({
    required this.messageId,
    required this.groupId,
    required this.reporterId,
    required this.reportedUserId,
    required this.messageKey,
    required this.ciphertext,
    this.ratchetHeader,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'message_id': messageId,
    'group_id': groupId,
    'reporter_id': reporterId,
    'reported_user_id': reportedUserId,
    'message_key': messageKey,
    'ciphertext': ciphertext,
    if (ratchetHeader != null) 'ratchet_header': ratchetHeader,
    'reason': reason,
    'timestamp': timestamp,
  };
}

abstract class MessageFranking {
  /// Create a franking report by extracting the per-message key.
  Future<FrankingReport?> createReport({
    required String messageId,
    required String groupId,
    required String reportedUserId,
    required String reason,
  });
}
