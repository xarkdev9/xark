import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chat_engine/chat_engine.dart';
import 'screens/conversation_screen.dart';
import 'providers/consensus_listener.dart';
import 'providers/engine_error_listener.dart';

final engineProvider = Provider<ChatEngine>((ref) => throw UnimplementedError());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the E2EE engine with real Supabase credentials.
  // These connect to the same backend as the React xark9 app.
  final engine = await ChatEngineImpl.initialize(
    ChatEngineConfig(
      authToken: const String.fromEnvironment('AUTH_TOKEN', defaultValue: ''),
      userId: const String.fromEnvironment('USER_ID', defaultValue: 'name_ram'),
      deviceId: 99, // Flutter device — distinct from React's device_id=1
      pushToken: '',
      serverBaseUrl: Uri.parse(
        const String.fromEnvironment(
          'SERVER_URL',
          defaultValue: 'https://ldnsxwkkxwztqyqkyuqa.supabase.co',
        ),
      ),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
    ),
  );

  // Moving the Riverpod nervous system external to the Widget Tree
  final container = ProviderContainer(
    overrides: [
      engineProvider.overrideWithValue(engine),
    ],
  );

  container.listen(
    consensusListenerProvider('default_space'),
    (previous, next) {
      if (next == true) {
        // Target 13: The "Gold Burst" Trigger (Social Physics)
        HapticFeedback.heavyImpact();
        
        // Target 14: The Global Lock State updated immediately
        container.read(globalLockProvider.notifier).lock();
      }
    },
    fireImmediately: true,
  );

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
      home: const ConversationScreen(),
    );
  }
}
