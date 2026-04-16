import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'cosmos_sender_model.dart';

/// Discrete phases of the 1700ms reward sequence.
/// Consumed by widgets that need to know "am I pulsing now" or
/// "is the ascent starting" without running their own timers.
enum RewardPhase {
  /// Not running — idle.
  idle,

  /// t = 0 → 700ms: levitation (avatar lifts +7pt then eases back)
  /// and plasma infusion (ColorFiltered srcATop sweep through palette)
  /// both run concurrently.
  infusing,

  /// t = 1000 → 1700ms: ascent (gradient stops flip, avatar drifts up
  /// ~60pt and dissolves) and handoff (next queue avatar scales 48→140
  /// into foreground slot).
  ascending,
}

/// Tracks the current reward phase + plasma infusion progress + ascent
/// progress. Constructed by _HomePageState and consumed by the reward
/// layers (ForegroundAvatar's infusion layer + atmosphere pulse + queue
/// promotion).
///
/// IMPORTANT: driven by a Flutter `Ticker` (not `Timer.periodic`) so the
/// sequence stays synced to the display's vsync signal. On 120Hz
/// ProMotion displays (8.33ms refresh), an event-loop Timer guarantees
/// micro-stutters and frame tearing.
class RewardController extends ChangeNotifier {
  RewardController({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;

  RewardPhase _phase = RewardPhase.idle;
  double _infusionProgress = 0.0; // 0 → 1 during infusing
  double _ascentProgress = 0.0;   // 0 → 1 during ascending
  PendingSender? _lockedForeground;
  List<PendingSender>? _lockedQueue;
  Duration? _startAt; // elapsed at which start() was called

  RewardPhase get phase => _phase;
  double get infusionProgress => _infusionProgress;
  double get ascentProgress => _ascentProgress;
  PendingSender? get lockedForeground => _lockedForeground;
  List<PendingSender>? get lockedQueue => _lockedQueue;
  bool get isAnimating => _phase != RewardPhase.idle;

  /// Start the 1700ms sequence. Snapshots the current foreground +
  /// queue so build() can read them instead of re-watching providers
  /// (which would flash to the next person the moment the action
  /// is optimistically applied).
  void start({
    required PendingSender foreground,
    required List<PendingSender> queue,
  }) {
    _lockedForeground = foreground;
    _lockedQueue = queue;
    _phase = RewardPhase.infusing;
    _infusionProgress = 0.0;
    _ascentProgress = 0.0;
    _startAt = null; // set on first tick so elapsed=0 anchors correctly
    if (!_ticker.isActive) _ticker.start();
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    _startAt ??= elapsed;
    final ms = (elapsed - _startAt!).inMilliseconds;

    if (ms < 700) {
      _phase = RewardPhase.infusing;
      _infusionProgress = (ms / 700).clamp(0.0, 1.0);
      _ascentProgress = 0.0;
    } else if (ms < 1000) {
      // Hold between 700ms and 1000ms — avatar at rest, infusion
      // receding, waiting for ascent
      _phase = RewardPhase.infusing;
      _infusionProgress = 1.0 - ((ms - 700) / 300).clamp(0.0, 1.0);
      _ascentProgress = 0.0;
    } else if (ms < 1700) {
      _phase = RewardPhase.ascending;
      _infusionProgress = 0.0;
      _ascentProgress = ((ms - 1000) / 700).clamp(0.0, 1.0);
    } else {
      // Done — release
      _phase = RewardPhase.idle;
      _infusionProgress = 0.0;
      _ascentProgress = 0.0;
      _lockedForeground = null;
      _lockedQueue = null;
      _startAt = null;
      _ticker.stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
