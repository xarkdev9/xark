/// ═══════════════════════════════════════════════════════════════════
/// DEMO V1 — Premium UI Showcase
///
/// Boots the MockChatEngine with the full xark9 premium UI:
/// - Spatial Search Bar (visionOS feel)
/// - Liquid Chat Composer (@hello AI morph)
/// - Zero-Box Chat Bubbles (smart corners, receipt morphing)
/// - Swipe-to-Reply Spring Physics
/// - Decision Board (Netflix PageView, gold burst)
///
/// Run: flutter run -t lib/demov1/demov1_main.dart -d macos
/// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'mock_chat_engine.dart';
import 'theme.dart';
import 'home_layout.dart';
import 'engine_error_listener.dart';

// ─── Providers ──────────────────────────────────────────────────────
final engineProvider = Provider<ChatEngine>((ref) => throw UnimplementedError());
final appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // V4 Matrix Simulation — rich demo data, no backend needed
  final engine = MockChatEngine();

  final container = ProviderContainer(
    overrides: [
      engineProvider.overrideWithValue(engine),
    ],
  );

  setupHeadlessErrorBus(container);

  runApp(UncontrolledProviderScope(
    container: container,
    child: const DemoV1App(),
  ));
}

class DemoV1App extends StatelessWidget {
  const DemoV1App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'hello — Demo V1',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        fontFamily: 'Inter',
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const HomeLayout(),
    );
  }
}
