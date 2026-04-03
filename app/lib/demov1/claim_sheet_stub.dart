import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub for deep link interceptor in demo mode
final deepLinkInterceptorProvider =
    NotifierProvider<_DeepLinkNotifier, bool>(() => _DeepLinkNotifier());

class _DeepLinkNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void trigger(bool value) => state = value;
}
