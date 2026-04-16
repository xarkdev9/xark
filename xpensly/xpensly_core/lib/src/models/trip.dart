import 'member.dart';
import 'split_mode.dart';

/// A named phase within a trip (e.g., "Tokyo", "Osaka", "Kyoto").
class TripPhase {
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  const TripPhase({
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  @override
  String toString() =>
      'TripPhase(name: $name, start: $startDate, end: $endDate)';
}

/// Configuration settings for a trip's expense splitting behavior.
class TripSettings {
  final bool simplifyDebts;
  final SplitMode defaultSplitMode;
  final String baseCurrency;

  const TripSettings({
    this.simplifyDebts = true,
    this.defaultSplitMode = SplitMode.equal,
    this.baseCurrency = 'USD',
  });

  @override
  String toString() =>
      'TripSettings(simplify: $simplifyDebts, mode: $defaultSplitMode, '
      'currency: $baseCurrency)';
}

/// A trip that groups expenses, members, and phases together.
class Trip {
  final String id;
  final String? groupId;
  final String title;
  final String baseCurrency;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<TripPhase> phases;
  final List<String> categories;
  final List<Member> members;
  final TripSettings settings;

  const Trip({
    required this.id,
    this.groupId,
    required this.title,
    required this.baseCurrency,
    this.startDate,
    this.endDate,
    this.phases = const [],
    this.categories = const [],
    required this.members,
    required this.settings,
  });

  @override
  String toString() =>
      'Trip(id: $id, title: $title, currency: $baseCurrency, '
      'members: ${members.length}, phases: ${phases.length})';
}
