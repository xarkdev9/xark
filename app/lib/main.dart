import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'views/home/home_layout.dart';
import 'views/auth/auth_flow_page.dart';
import 'views/home/decision_board/plasma/plasma.dart';
import 'providers/engine_error_listener.dart';
import 'theme.dart';

/// Custom scroll behavior that enables horizontal drag gestures on
/// all pointer device types — critical for TabBarView swipe to work
/// on Flutter Web (mouse + trackpad) in addition to touch.
class _DragEverywhereScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

// ─── Global Providers ───────────────────────────────────────────────
final engineProvider = Provider<ChatEngine>((ref) => throw UnimplementedError());
final appNavigatorKey = GlobalKey<NavigatorState>();

// ─── Environment ────────────────────────────────────────────────────
const String serverUrl = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'https://ldnsxwkkxwztqyqkyuqa.supabase.co',
);
const String _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

// ─── Mutable Container ─────────────────────────────────────────────
// The container is created at startup. The engine override is applied
// after auth completes (deferred init).
late ProviderContainer _container;

/// Called by the auth flow after Firebase OTP + AuthService JWT exchange.
/// Boots the engine with real credentials and wires the error bus.
Future<void> initializeEngine({
  required WidgetRef ref,
  required String authToken,
  required String userId,
}) async {
  final engine = await ChatEngineImpl.initialize(
    ChatEngineConfig(
      authToken: authToken,
      userId: userId,
      deviceId: 99, // Flutter client — distinct from React's device_id=1
      pushToken: '',
      serverBaseUrl: Uri.parse(serverUrl),
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

  // Override the engine provider with the real instance
  _container.updateOverrides([
    engineProvider.overrideWithValue(engine),
  ]);

  setupHeadlessErrorBus(_container);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  _container = ProviderContainer();

  runApp(UncontrolledProviderScope(
    container: _container,
    child: const HelloApp(),
  ));
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
    try {
      final engine = ref.read(engineProvider);
      switch (state) {
        case AppLifecycleState.resumed:
          engine.resume();
          break;
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
          engine.suspend();
          break;
        case AppLifecycleState.detached:
          engine.dispose();
          break;
        default:
          break;
      }
    } catch (_) {
      // Engine not yet initialized — ignore lifecycle events
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlasmaClock(
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'hello',
        scrollBehavior: _DragEverywhereScrollBehavior(),
        theme: ThemeData(
          scaffoldBackgroundColor: HelloColors.voidBg,
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
        routes: {
          '/home': (context) => const HomeLayout(),
          '/auth': (context) => const AuthFlowPage(),
        },
        home: const HomeLayout(), // Decision board — Netflix-style decision rails
      ),
    );
  }
}

/// Handles resuming an existing Firebase session.
/// Re-exchanges the Firebase token for a fresh Supabase JWT,
/// boots the engine, then navigates to home.
class _ResumeSession extends ConsumerStatefulWidget {
  const _ResumeSession();

  @override
  ConsumerState<_ResumeSession> createState() => _ResumeSessionState();
}

class _ResumeSessionState extends ConsumerState<_ResumeSession> {
  @override
  void initState() {
    super.initState();
    _resumeAuth();
  }

  Future<void> _resumeAuth() async {
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      if (idToken == null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/auth');
        }
        return;
      }

      final authService = AuthService(Uri.parse(serverUrl));
      final result = await authService.authenticateWithFirebase(
        firebaseIdToken: idToken,
      );

      if (!mounted) return;

      await initializeEngine(
        ref: ref,
        authToken: result.accessToken,
        userId: result.userId,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (_) {
      // Token expired or server unreachable — send to auth
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: HelloColors.inkPrimary,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}
