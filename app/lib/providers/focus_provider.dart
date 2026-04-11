import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/trip.dart';
import 'mock_data.dart';
import 'trips_provider.dart';

/// The id of the currently-pinned focus trip. Nullable so "no focus"
/// is a valid state. Defaults to [kMockFocusTripId] on first boot.
final focusTripIdProvider =
    StateProvider<String?>((ref) => kMockFocusTripId);

/// Resolves the focus trip id to the actual [Trip] object, or null
/// if no focus is set / the id doesn't match.
final focusTripProvider = Provider<Trip?>((ref) {
  final id = ref.watch(focusTripIdProvider);
  if (id == null) return null;
  final trips = ref.watch(tripsProvider);
  for (final t in trips) {
    if (t.id == id) return t;
  }
  return null;
});
