/// Error capture and sanitization for the feedback system.
///
/// Captures contextual error information, sanitizes it to remove
/// sensitive data, and manages a bounded report queue.
/// Pure Dart — no Flutter imports.

import 'package:uuid/uuid.dart';

import 'package:e2ee_chat_sdk/src/discovery/models/error_report.dart';

/// Maximum number of stored error reports before FIFO eviction.
const int maxReports = 100;

/// Keys that are considered sensitive and must be removed from context.
const List<String> sensitiveKeys = [
  'token',
  'key',
  'password',
  'plaintext',
  'taste',
];

/// Maximum length for string values in sanitized context.
const int maxContextStringLength = 200;

/// Captures and manages error reports with privacy sanitization.
class ErrorCapture {
  /// Creates an [ErrorCapture].
  ErrorCapture();

  final List<ErrorReport> _reports = [];
  final Uuid _uuid = const Uuid();

  /// Captures an error with the given type, message, and optional context.
  ///
  /// Context is sanitized to remove sensitive keys before storage.
  /// Returns the created [ErrorReport].
  ErrorReport capture({
    required String errorType,
    required String errorMessage,
    Map<String, dynamic> context = const {},
  }) {
    final report = ErrorReport(
      id: _uuid.v4(),
      errorType: errorType,
      errorMessage: errorMessage,
      context: sanitizeContext(context),
      occurredAt: DateTime.now(),
    );

    _reports.add(report);

    // FIFO eviction at max capacity.
    while (_reports.length > maxReports) {
      _reports.removeAt(0);
    }

    return report;
  }

  /// Returns all pending reports.
  List<ErrorReport> get pendingReports => List.unmodifiable(_reports);

  /// Returns only unsynced reports.
  List<ErrorReport> get unsyncedReports =>
      _reports.where((r) => !r.synced).toList();

  /// Marks a report as synced.
  void markSynced(String reportId) {
    final index = _reports.indexWhere((r) => r.id == reportId);
    if (index != -1) {
      _reports[index] = _reports[index].copyWith(synced: true);
    }
  }

  /// Returns the most recent report within the given timeframe,
  /// or null if no report exists within that window.
  ErrorReport? getRecent({Duration window = const Duration(minutes: 5)}) {
    if (_reports.isEmpty) return null;

    final cutoff = DateTime.now().subtract(window);
    for (var i = _reports.length - 1; i >= 0; i--) {
      if (_reports[i].occurredAt.isAfter(cutoff)) {
        return _reports[i];
      }
    }
    return null;
  }

  /// Sanitizes a context map by removing sensitive keys and truncating
  /// long string values.
  static Map<String, dynamic> sanitizeContext(Map<String, dynamic> context) {
    final sanitized = <String, dynamic>{};

    for (final entry in context.entries) {
      // Remove entries whose key contains any sensitive keyword.
      final keyLower = entry.key.toLowerCase();
      var isSensitive = false;
      for (final sensitiveKey in sensitiveKeys) {
        if (keyLower.contains(sensitiveKey)) {
          isSensitive = true;
          break;
        }
      }
      if (isSensitive) continue;

      // Truncate long string values.
      if (entry.value is String) {
        final str = entry.value as String;
        sanitized[entry.key] =
            str.length > maxContextStringLength
                ? str.substring(0, maxContextStringLength)
                : str;
      } else {
        sanitized[entry.key] = entry.value;
      }
    }

    return sanitized;
  }
}
