/// Client-side E2EE observability for the engine.
/// Tracks decryption failures, ratchet desyncs, timing metrics.
/// Never logs plaintext, keys, or user content.

class E2EEMetrics {
  static final List<Map<String, dynamic>> _buffer = [];
  static const int _maxBuffer = 100;

  static void trackEvent(String event, {
    String? groupId,
    String? sessionId,
    String? error,
    int? durationMs,
  }) {
    final metric = {
      'event': event,
      if (groupId != null) 'group_id': groupId,
      if (sessionId != null) 'session_id': sessionId,
      if (error != null) 'error': error,
      if (durationMs != null) 'duration_ms': durationMs,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _buffer.add(metric);
    if (_buffer.length > _maxBuffer) _buffer.removeAt(0);

    // Critical events
    if (event == 'decryption_failed' || event == 'ratchet_desync') {
      _reportCritical(metric);
    }
  }

  static void _reportCritical(Map<String, dynamic> metric) {
    // Sentry integration point
    // TODO: Sentry.captureMessage('E2EE: ${metric['event']}');
  }

  static void trackEncryptTime(String groupId, int durationMs) {
    trackEvent('encrypt_complete', groupId: groupId, durationMs: durationMs);
  }

  static void trackDecryptTime(String groupId, int durationMs) {
    trackEvent('decrypt_complete', groupId: groupId, durationMs: durationMs);
  }

  static void trackDecryptFailure(String groupId, String sessionId, String error) {
    trackEvent('decryption_failed', groupId: groupId, sessionId: sessionId, error: error);
  }

  static List<Map<String, dynamic>> getRecentMetrics() => List.from(_buffer);
}
