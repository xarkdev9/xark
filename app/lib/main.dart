import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'views/home/home_layout.dart';
import 'views/auth/auth_flow_page.dart';

import 'providers/engine_error_listener.dart';
import 'theme.dart';
import 'src/mock_chat_engine.dart';

// ─── Global Providers ───────────────────────────────────────────────
final engineProvider = Provider<ChatEngine>((ref) => throw UnimplementedError());
final appNavigatorKey = GlobalKey<NavigatorState>();

// ─── Boot Configuration ─────────────────────────────────────────────
// Set to false to use MockChatEngine for UI testing without backend.
// Set to true for bare-metal E2EE engine boot with real Supabase.
const bool _useLiveEngine = false;

// Environment variables (injected via --dart-define or .env)
const String _serverUrl = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'https://ldnsxwkkxwztqyqkyuqa.supabase.co',
);
const String _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ChatEngine engine;

  if (_useLiveEngine) {
    // ═══════════════════════════════════════════════════════════════
    // PHASE 3: BARE-METAL ENGINE BOOT
    // ═══════════════════════════════════════════════════════════════
    //
    // The bootloader initializes the real e2ee_chat_sdk engine:
    // 1. SQLCipher database mounts (encryption key from platform Keychain)
    // 2. Crypto isolate spawns (dedicated background thread for Signal ops)
    // 3. Transport layer connects (SupabaseClientWrapper + Realtime)
    // 4. Sync coordinator starts (outbox drain, watermark gap fill)
    //
    // AuthService is called BEFORE engine init to obtain the JWT.
    // For now, we use a placeholder token — the auth flow will
    // replace this with a real Firebase OTP → JWT exchange.
    //
    // The engine manages ALL backend communication. The UI never
    // touches Supabase, Firebase, or any HTTP endpoint directly.
    // ═══════════════════════════════════════════════════════════════

    engine = await ChatEngineImpl.initialize(
      ChatEngineConfig(
        authToken: const String.fromEnvironment('AUTH_TOKEN', defaultValue: ''),
        userId: const String.fromEnvironment('USER_ID', defaultValue: 'name_ram'),
        deviceId: 99, // Flutter client — distinct from React's device_id=1
        pushToken: '',
        serverBaseUrl: Uri.parse(_serverUrl),
        supabaseAnonKey: _supabaseAnonKey,
        brand: const BrandConfig(
          appName: 'hello',
          aiName: '@hello',
          aiEndpoint: '/api/hello',
          pushChannelId: 'hello_messages',
          pushChannelName: 'Messages',
          fallbackSenderName: 'hello',
        ),
      ),
    );
  } else {
    // Mock simulation for UI testing without backend
    // ignore: avoid_relative_lib_imports
    final mock = await _createMockEngine();
    engine = mock;
  }

  // ─── Riverpod Nervous System ────────────────────────────────────
  final container = ProviderContainer(
    overrides: [
      engineProvider.overrideWithValue(engine),
    ],
  );

  // ─── Headless Error Bus ─────────────────────────────────────────
  setupHeadlessErrorBus(container);

  // ─── Launch ─────────────────────────────────────────────────────
  runApp(UncontrolledProviderScope(
    container: container,
    child: const HelloApp(),
  ));
}

/// Mock engine factory — lazy import to avoid pulling mock code into prod builds
Future<ChatEngine> _createMockEngine() async {
  return MockChatEngine();
}

// ═══════════════════════════════════════════════════════════════════
// App Root
// ═══════════════════════════════════════════════════════════════════

class HelloApp extends ConsumerStatefulWidget {
  const HelloApp({super.key});

  @override
  ConsumerState<HelloApp> createState() => _HelloAppState();
}

class _HelloAppState extends ConsumerState<HelloApp> with WidgetsBindingObserver {
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
    final engine = ref.read(engineProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        // Reconnects WebSocket, drains outbox, syncs gaps
        engine.resume();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Pauses sync, keeps push alive
        engine.suspend();
        break;
      case AppLifecycleState.detached:
        // Full teardown, secure key wipe
        engine.dispose();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'hello',
      theme: ThemeData(
        scaffoldBackgroundColor: HelloColors.voidBg,
        fontFamily: 'Inter',
        // Zero-Box: strip all Material defaults
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      routes: {
        '/home': (context) => const HomeLayout(),
        '/auth': (context) => const AuthFlowPage(),
      },
      home: const HomeLayout(),
    );
  }
}
