import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../main.dart';
import 'consensus_listener.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void setupHeadlessErrorBus(ProviderContainer container) {
  final engine = container.read(engineProvider);
  
  engine.errors.listen((error) {
    if (error is KeyVerificationFailed) {
      // Step 5 Protocol: Trap KeyVerificationFailed to mutate globalLockProvider
      container.read(globalLockProvider.notifier).lock('system_error');
    } else if (error is AuthTokenExpired) {
      // Step 5 Protocol: Trap AuthTokenExpired to trigger a router purge to /login
      appNavigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  });
}
