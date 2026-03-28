import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'views/chat/chat_view.dart';
import 'providers/engine_error_listener.dart';
import 'views/home/home_layout.dart';
import 'engine_simulator/mock_chat_engine.dart';

final engineProvider = Provider<ChatEngine>((ref) => throw UnimplementedError());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The Bootloader is hijacked to run the local Phase 2 Matrix Simulation
  // instead of connecting to the literal Supabase backend. This enforces
  // strict local 120fps testing bounds for UI rendering physics.
  final engine = MockChatEngine();

  // Moving the Riverpod nervous system external to the Widget Tree
  final container = ProviderContainer(
    overrides: [
      engineProvider.overrideWithValue(engine),
    ],
  );

  // Legacy consensus listener removed. The ActionCardWidget now handles this directly.

  setupHeadlessErrorBus(container);

  runApp(UncontrolledProviderScope(
    container: container,
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(engineProvider).resume();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(engineProvider).suspend();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Hello OS V2',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        fontFamily: 'Inter', 
      ),
      routes: {
        '/chat': (context) => const ChatView(),
      },
      home: const HomeLayout(),
    );
  }
}
