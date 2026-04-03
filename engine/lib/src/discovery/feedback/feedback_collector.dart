/// Feedback collection for user-reported issues.
///
/// Wraps [ErrorCapture] with user-facing feedback submission
/// and @hello prompt generation. Pure Dart — no Flutter imports.

import 'package:e2ee_chat_sdk/src/discovery/feedback/error_capture.dart';
import 'package:e2ee_chat_sdk/src/discovery/models/error_report.dart';

/// Collects user feedback and correlates it with recent errors.
///
/// Works with [ErrorCapture] to enrich feedback reports with
/// automatically captured error context. Also generates @hello
/// prompts for conversational feedback collection.
class FeedbackCollector {
  /// Creates a [FeedbackCollector] backed by the given [ErrorCapture].
  FeedbackCollector(this._errorCapture);

  final ErrorCapture _errorCapture;

  /// Submits a user-described feedback report.
  ///
  /// If [context] is provided, it is sanitized before storage.
  /// Returns the created [ErrorReport].
  ErrorReport submitFeedback({
    required String message,
    Map<String, dynamic>? context,
  }) {
    return _errorCapture.capture(
      errorType: 'user_feedback',
      errorMessage: message,
      context: {
        'source': 'user_feedback',
        if (context != null) ...context,
      },
    );
  }

  /// Returns the most recent error report (within 5 minutes),
  /// or `null` if none exists.
  ///
  /// Useful for checking if there's a recent error to reference
  /// in an @hello feedback conversation.
  ErrorReport? getRecentError() {
    return _errorCapture.getRecent();
  }

  /// Builds an @hello prompt for feedback collection.
  ///
  /// If [recentError] is provided, the prompt references the specific
  /// error to help the user describe what happened. Otherwise, a
  /// generic feedback prompt is returned.
  ///
  /// Returns a string in @hello's cool-friend persona style.
  String buildHelloFeedbackPrompt(ErrorReport? recentError) {
    if (recentError != null) {
      return 'i saw that ${recentError.errorType} just happened. '
          'can you tell me what you were trying to do?';
    }

    return 'what went wrong? describe what happened and '
        "i'll file a report.";
  }
}
