import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip.dart';
import 'mock_data.dart';

/// Source of truth for trips. Mock-backed when [kUseMockData] is true.
final tripsProvider = Provider<List<Trip>>((ref) {
  if (kUseMockData) return mockTrips;
  return const <Trip>[];
});
