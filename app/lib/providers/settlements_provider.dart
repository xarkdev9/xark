import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/settlement.dart';
import 'mock_data.dart';

final settlementsProvider = Provider<List<Settlement>>((ref) {
  if (kUseMockData) return mockSettlements;
  return const <Settlement>[];
});
