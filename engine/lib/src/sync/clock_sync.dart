// hello OS v2.0 — Clock Sync Utility
// NTP-lite clock synchronization via HTTP Date header.
// Compensates for device clock drift to keep UUIDv7 timestamps
// within the server's 5-minute skew tolerance window.

import 'dart:io';
import 'package:http/http.dart' as http;

class ClockSync {
  int _deltaMs = 0;
  final Uri _serverBaseUrl;

  ClockSync(this._serverBaseUrl);

  int get deltaMs => _deltaMs;
  int get correctedNowMs => DateTime.now().millisecondsSinceEpoch + _deltaMs;

  Future<void> sync() async {
    try {
      final before = DateTime.now().millisecondsSinceEpoch;
      final response = await http.head(_serverBaseUrl.resolve('/api/hello'));
      final after = DateTime.now().millisecondsSinceEpoch;

      final dateHeader = response.headers['date'];
      if (dateHeader == null) return;

      final serverTime = HttpDate.parse(dateHeader).millisecondsSinceEpoch;
      final rtt = (after - before) ~/ 2;
      _deltaMs = serverTime - before - rtt;
    } catch (_) {
      // Clock sync failure is non-fatal — use device time
    }
  }
}
