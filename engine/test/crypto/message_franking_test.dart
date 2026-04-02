import 'package:flutter_test/flutter_test.dart';
import 'package:e2ee_chat_sdk/src/crypto/franking/message_franking.dart';

void main() {
  group('FrankingReport', () {
    test('toJson produces correct structure', () {
      final report = FrankingReport(
        messageId: 'msg_123',
        groupId: 'group_456',
        reporterId: 'user_alice',
        reportedUserId: 'user_bob',
        messageKey: 'base64key==',
        ciphertext: 'base64ct==',
        reason: 'spam',
        timestamp: 1711555200000,
      );

      final json = report.toJson();
      expect(json['message_id'], 'msg_123');
      expect(json['group_id'], 'group_456');
      expect(json['reporter_id'], 'user_alice');
      expect(json['reported_user_id'], 'user_bob');
      expect(json['message_key'], 'base64key==');
      expect(json['reason'], 'spam');
    });

    test('FrankingReport fields are immutable', () {
      final report = FrankingReport(
        messageId: 'msg_1',
        groupId: 'g_1',
        reporterId: 'r_1',
        reportedUserId: 'ru_1',
        messageKey: 'key',
        ciphertext: 'ct',
        reason: 'harassment',
        timestamp: 1000,
      );
      expect(report.messageId, 'msg_1');
      expect(report.reason, 'harassment');
    });
  });
}
