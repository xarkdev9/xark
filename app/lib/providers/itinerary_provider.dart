import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/itinerary_event.dart';
import 'mock_data.dart';

final itineraryProvider = Provider<List<ItineraryEvent>>((ref) {
  if (kUseMockData) return mockItinerary;
  return const <ItineraryEvent>[];
});
