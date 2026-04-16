/// Error report model for the feedback system.
///
/// Captures contextual error information for debugging
/// and @hello-assisted feedback collection. Pure Dart — no Flutter imports.

/// A captured error report with sync state.
class ErrorReport {
  /// Creates an [ErrorReport].
  const ErrorReport({
    required this.id,
    required this.errorType,
    required this.errorMessage,
    this.context = const {},
    this.userDescription,
    required this.occurredAt,
    this.synced = false,
  });

  /// Unique identifier for this report.
  final String id;

  /// Machine-readable error type (e.g. "network_timeout", "parse_error").
  final String errorType;

  /// Human-readable error message.
  final String errorMessage;

  /// Sanitized context data (no keys, tokens, or plaintext).
  final Map<String, dynamic> context;

  /// Optional user-provided description of what happened.
  final String? userDescription;

  /// When the error occurred.
  final DateTime occurredAt;

  /// Whether this report has been synced to the server.
  final bool synced;

  /// Creates a copy with the given fields replaced.
  ErrorReport copyWith({
    bool? synced,
    String? userDescription,
  }) {
    return ErrorReport(
      id: id,
      errorType: errorType,
      errorMessage: errorMessage,
      context: context,
      userDescription: userDescription ?? this.userDescription,
      occurredAt: occurredAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ErrorReport && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ErrorReport('
        'id: $id, '
        'errorType: $errorType, '
        'synced: $synced, '
        'occurredAt: $occurredAt)';
  }
}
