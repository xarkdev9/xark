import 'package:flutter_riverpod/legacy.dart';

/// Persists the active card index on the decision board home
/// across widget disposal, navigation pushes, and engine rebuilds.
/// 0 = Chats, 1 = Groups, 2 = Decisions.
final homeActiveCardIndexProvider = StateProvider<int>((ref) => 0);
