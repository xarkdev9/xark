// ignore_for_file: prefer_const_constructors

import 'package:e2ee_chat_sdk/src/discovery/feedback/error_capture.dart';
import 'package:e2ee_chat_sdk/src/discovery/feedback/feedback_collector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Scenario: Search times out, user reports', () {
    late ErrorCapture errorCapture;
    late FeedbackCollector collector;

    setUp(() {
      errorCapture = ErrorCapture();
      collector = FeedbackCollector(errorCapture);
    });

    test('full feedback flow: timeout, capture, prompt, user report', () {
      // Step 1: A search timeout error is captured.
      final errorReport = errorCapture.capture(
        errorType: 'search_timeout',
        errorMessage: 'Search request timed out after 30 seconds',
        context: {
          'screen': 'explore',
          'action': 'search',
        },
      );

      expect(errorReport.errorType, 'search_timeout');
      expect(errorReport.context['screen'], 'explore');
      expect(errorReport.context['action'], 'search');

      // Step 2: getRecentError returns the error.
      final recent = collector.getRecentError();
      expect(recent, isNotNull);
      expect(recent!.errorType, 'search_timeout');

      // Step 3: buildHelloFeedbackPrompt references "search_timeout".
      final prompt = collector.buildHelloFeedbackPrompt(recent);
      expect(prompt, contains('search_timeout'));

      // Step 4: User submits feedback with description.
      final feedbackReport = collector.submitFeedback(
        message: 'search was stuck',
      );

      // Step 5: Report has error type and user message.
      expect(feedbackReport.errorType, 'user_feedback');
      expect(feedbackReport.errorMessage, 'search was stuck');
      expect(feedbackReport.context['source'], 'user_feedback');
    });

    test('privacy: context does not contain sensitive keys', () {
      // Capture an error with sensitive data in context.
      errorCapture.capture(
        errorType: 'search_timeout',
        errorMessage: 'Timeout',
        context: {
          'screen': 'explore',
          'action': 'search',
          'authToken': 'secret-bearer-token',
          'apiKey': 'sk-123456',
          'password': 'hunter2',
        },
      );

      final recent = errorCapture.getRecent();
      expect(recent, isNotNull);

      // Sensitive keys should have been stripped by sanitizeContext.
      expect(recent!.context.containsKey('authToken'), isFalse);
      expect(recent.context.containsKey('apiKey'), isFalse);
      expect(recent.context.containsKey('password'), isFalse);

      // Safe keys should remain.
      expect(recent.context['screen'], 'explore');
      expect(recent.context['action'], 'search');
    });
  });
}
