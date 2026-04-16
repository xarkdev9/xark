// ignore_for_file: prefer_const_constructors

import 'package:e2ee_chat_sdk/src/discovery/feedback/error_capture.dart';
import 'package:e2ee_chat_sdk/src/discovery/feedback/feedback_collector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ErrorCapture errorCapture;
  late FeedbackCollector collector;

  setUp(() {
    errorCapture = ErrorCapture();
    collector = FeedbackCollector(errorCapture);
  });

  group('FeedbackCollector — submitFeedback', () {
    test('submitFeedback creates report with user message', () {
      final report = collector.submitFeedback(
        message: 'The search page keeps loading forever',
      );

      expect(report.errorType, 'user_feedback');
      expect(report.errorMessage, 'The search page keeps loading forever');
      expect(report.context['source'], 'user_feedback');
    });
  });

  group('FeedbackCollector — getRecentError', () {
    test('getRecentError returns recent error from ErrorCapture', () {
      errorCapture.capture(
        errorType: 'search_timeout',
        errorMessage: 'Search timed out after 30s',
      );

      final recent = collector.getRecentError();

      expect(recent, isNotNull);
      expect(recent!.errorType, 'search_timeout');
    });

    test('getRecentError returns null when no recent errors', () {
      final recent = collector.getRecentError();
      expect(recent, isNull);
    });
  });

  group('FeedbackCollector — buildHelloFeedbackPrompt', () {
    test('buildHelloFeedbackPrompt references recent error type', () {
      final error = errorCapture.capture(
        errorType: 'search_timeout',
        errorMessage: 'Search timed out',
        context: {'screen': 'explore'},
      );

      final prompt = collector.buildHelloFeedbackPrompt(error);

      expect(prompt, contains('search_timeout'));
    });

    test('buildHelloFeedbackPrompt gives generic message when no recent error',
        () {
      final prompt = collector.buildHelloFeedbackPrompt(null);

      expect(prompt, isNot(contains('search_timeout')));
      // Should be a generic prompt asking the user to describe the issue.
      expect(prompt.isNotEmpty, isTrue);
    });
  });
}
