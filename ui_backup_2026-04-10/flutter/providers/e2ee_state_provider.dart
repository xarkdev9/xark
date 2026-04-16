import 'package:flutter_riverpod/flutter_riverpod.dart';

class E2EEState {
  final bool isReady;
  final bool isGeneratingKeys;
  final int? deviceId;

  const E2EEState({
    this.isReady = false,
    this.isGeneratingKeys = false,
    this.deviceId,
  });

  E2EEState copyWith({
    bool? isReady,
    bool? isGeneratingKeys,
    int? deviceId,
  }) {
    return E2EEState(
      isReady: isReady ?? this.isReady,
      isGeneratingKeys: isGeneratingKeys ?? this.isGeneratingKeys,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}

class E2EEStateNotifier extends Notifier<E2EEState> {
  @override
  E2EEState build() {
    return const E2EEState();
  }

  void markReady(int id) {
    state = state.copyWith(isReady: true, deviceId: id);
  }

  void setGenerating(bool generating) {
    state = state.copyWith(isGeneratingKeys: generating);
  }
}

final e2eeStateProvider = NotifierProvider<E2EEStateNotifier, E2EEState>(() {
  return E2EEStateNotifier();
});
