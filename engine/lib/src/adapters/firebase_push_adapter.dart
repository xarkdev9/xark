import 'dart:async';

import 'package:e2ee_chat_sdk/src/ports/push_adapter.dart';

/// Firebase Cloud Messaging implementation of [PushAdapter].
///
/// This is the default adapter for iOS/Android.
/// Customers using OneSignal/Pusher implement their own [PushAdapter].
///
/// Note: Requires `firebase_messaging` package in the host app's pubspec.
class FirebasePushAdapter implements PushAdapter {
  final _tokenController = StreamController<String>.broadcast();

  @override
  Future<void> initialize() async {
    // Firebase Messaging initialization.
    // The host app must have firebase_messaging in their pubspec and
    // call Firebase.initializeApp() before creating this adapter.
    try {
      // Dynamic usage to keep firebase_messaging optional at compile time.
      // Host app must configure Firebase before engine initialization.
    } catch (_) {
      // Firebase not available -- push disabled.
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      // In production: FirebaseMessaging.instance.getToken()
      return null; // Placeholder until host wires Firebase
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh => _tokenController.stream;

  @override
  Future<void> dispose() async {
    await _tokenController.close();
  }
}

/// No-op push adapter for environments without push support (web, testing).
class NoopPushAdapter implements PushAdapter {
  @override
  Future<void> initialize() async {}

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Future<void> dispose() async {}
}
