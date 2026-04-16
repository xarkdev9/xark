// ignore_for_file: prefer_const_constructors

import 'package:e2ee_chat_sdk/src/discovery/feedback/error_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ErrorCapture capture;

  setUp(() {
    capture = ErrorCapture();
  });

  group('ErrorCapture — basic capture', () {
    test('capture creates report with correct fields', () {
      final report = capture.capture(
        errorType: 'network_timeout',
        errorMessage: 'Request timed out after 30s',
        context: {'screen': 'explore', 'action': 'search'},
      );

      expect(report.errorType, 'network_timeout');
      expect(report.errorMessage, 'Request timed out after 30s');
      expect(report.context['screen'], 'explore');
      expect(report.context['action'], 'search');
      expect(report.synced, isFalse);
      expect(report.occurredAt, isA<DateTime>());
    });

    test('capture generates unique IDs', () {
      final report1 = capture.capture(
        errorType: 'error_a',
        errorMessage: 'First error',
      );
      final report2 = capture.capture(
        errorType: 'error_b',
        errorMessage: 'Second error',
      );

      expect(report1.id, isNot(equals(report2.id)));
    });
  });

  group('ErrorCapture — report queries', () {
    test('pendingReports returns all reports', () {
      capture.capture(errorType: 'a', errorMessage: 'msg a');
      capture.capture(errorType: 'b', errorMessage: 'msg b');
      capture.capture(errorType: 'c', errorMessage: 'msg c');

      expect(capture.pendingReports, hasLength(3));
    });

    test('unsyncedReports returns only unsynced', () {
      final r1 = capture.capture(errorType: 'a', errorMessage: 'msg a');
      capture.capture(errorType: 'b', errorMessage: 'msg b');

      capture.markSynced(r1.id);

      final unsynced = capture.unsyncedReports;
      expect(unsynced, hasLength(1));
      expect(unsynced.first.errorType, 'b');
    });

    test('markSynced updates report', () {
      final report = capture.capture(
        errorType: 'test',
        errorMessage: 'test msg',
      );

      expect(capture.pendingReports.first.synced, isFalse);

      capture.markSynced(report.id);

      expect(capture.pendingReports.first.synced, isTrue);
    });
  });

  group('ErrorCapture — getRecent', () {
    test('getRecent returns report within timeframe', () {
      capture.capture(
        errorType: 'recent_error',
        errorMessage: 'Just happened',
      );

      final recent = capture.getRecent(window: Duration(minutes: 5));

      expect(recent, isNotNull);
      expect(recent!.errorType, 'recent_error');
    });

    test('getRecent returns null when no recent reports', () {
      // Empty capture — no reports at all.
      final recent = capture.getRecent(window: Duration(minutes: 5));
      expect(recent, isNull);
    });
  });

  group('ErrorCapture — FIFO eviction', () {
    test('FIFO eviction at 100 reports (oldest removed)', () {
      // Fill up to max.
      for (var i = 0; i < maxReports; i++) {
        capture.capture(
          errorType: 'type-$i',
          errorMessage: 'msg-$i',
        );
      }

      expect(capture.pendingReports, hasLength(maxReports));

      final firstId = capture.pendingReports.first.id;

      // Add one more — should evict the oldest.
      capture.capture(
        errorType: 'overflow',
        errorMessage: 'This should evict the oldest',
      );

      expect(capture.pendingReports, hasLength(maxReports));
      expect(capture.pendingReports.first.id, isNot(equals(firstId)));
      expect(capture.pendingReports.last.errorType, 'overflow');
    });
  });

  group('ErrorCapture — sanitizeContext', () {
    test('removes "token" keys', () {
      final sanitized = ErrorCapture.sanitizeContext({
        'authToken': 'secret-123',
        'screen': 'explore',
      });

      expect(sanitized.containsKey('authToken'), isFalse);
      expect(sanitized['screen'], 'explore');
    });

    test('removes "key" keys', () {
      final sanitized = ErrorCapture.sanitizeContext({
        'apiKey': 'abc-def',
        'encryptionKey': 'xyz',
        'screen': 'home',
      });

      expect(sanitized.containsKey('apiKey'), isFalse);
      expect(sanitized.containsKey('encryptionKey'), isFalse);
      expect(sanitized['screen'], 'home');
    });

    test('removes "password" keys', () {
      final sanitized = ErrorCapture.sanitizeContext({
        'userPassword': 'hunter2',
        'action': 'login',
      });

      expect(sanitized.containsKey('userPassword'), isFalse);
      expect(sanitized['action'], 'login');
    });

    test('removes "plaintext" keys', () {
      final sanitized = ErrorCapture.sanitizeContext({
        'plaintextMessage': 'Hello world',
        'category': 'chat',
      });

      expect(sanitized.containsKey('plaintextMessage'), isFalse);
      expect(sanitized['category'], 'chat');
    });

    test('removes "taste" keys', () {
      final sanitized = ErrorCapture.sanitizeContext({
        'tasteProfile': {'weights': {}},
        'screen': 'discover',
      });

      expect(sanitized.containsKey('tasteProfile'), isFalse);
      expect(sanitized['screen'], 'discover');
    });

    test('truncates long strings to 200 chars', () {
      final longString = 'a' * 500;
      final sanitized = ErrorCapture.sanitizeContext({
        'description': longString,
      });

      expect(
        (sanitized['description'] as String).length,
        maxContextStringLength,
      );
    });

    test('preserves safe keys', () {
      final sanitized = ErrorCapture.sanitizeContext({
        'screen': 'explore',
        'action': 'search',
        'category': 'restaurants',
        'errorCode': 408,
      });

      expect(sanitized['screen'], 'explore');
      expect(sanitized['action'], 'search');
      expect(sanitized['category'], 'restaurants');
      expect(sanitized['errorCode'], 408);
    });
  });
}
