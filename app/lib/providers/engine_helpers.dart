import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart' show engineProvider;

/// Safely resolves the engine, returning null if not yet initialized.
ChatEngine? engineOrNull(Ref ref) {
  try {
    return ref.watch(engineProvider);
  } catch (_) {
    return null;
  }
}
