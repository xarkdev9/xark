# Spec 6: Backend Completion — 17 Pending Tasks

**Date:** 2026-03-27
**Scope:** All remaining backend tasks to make the app testable on real mobile devices
**Platform:** Engine (Dart), Native (iOS/Android), Web API integration

---

## Sub-Project A: Engine Public API Extension (12 methods)

Add methods to `engine/lib/src/public_api/chat_engine.dart` (abstract class) and implement in `engine/lib/src/chat_engine_impl.dart`.

### Methods to Add

1. **`Future<UserProfile> getProfile(String userId)`** — Query users table via engine transport
2. **`Future<void> updateProfile({String? displayName, Uint8List? photo})`** — Update users table + upload photo to Firebase Storage
3. **`Future<List<DeviceInfo>> getDevices()`** — Wrap `DeviceRegistry.getUserDevices(config.userId)`
4. **`Future<void> unlinkDevice(int deviceId)`** — Wrap `DeviceRegistry.unlinkDevice(deviceId)`
5. **`Stream<List<HelloResponseChunk>> streamHelloResponse({required String prompt, required String groupId})`** — SSE client to `/api/hello`, manages auth token, parses SSE events
6. **`Future<List<DecisionItem>> getDecisionItems(String groupId)`** — Query decision_items + reactions via engine transport
7. **`Future<void> reactToItem(String itemId, String signal)`** — Insert reaction via engine transport
8. **`Future<InviteLink> generateInvite()`** — Call `/api/invite` via engine transport
9. **`Future<JoinResult> claimInvite(String code)`** — Call `/api/invite/claim` via engine transport
10. **`Future<String> getDisplayName(String userId)`** — Cache-backed user name lookup
11. **`Future<Conversation> createGroup({required String title, String? atmosphere})`** — Call `/api/local-action` with `create_space`
12. **`Future<void> lockItem(String itemId, CommitmentProof proof)`** — Green-Lock via engine transport

### New Types to Add

```dart
class UserProfile {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String? phone;
}

class HelloResponseChunk {
  final String text;
  final bool done;
}

class DecisionItem {
  final String id;
  final String groupId;
  final String title;
  final String? description;
  final String? category;
  final String state;
  final double weightedScore;
  final double agreementScore;
  final Map<String, String> reactions; // userId → signal
  final bool isLocked;
  final String? photoUrl;
}

class InviteLink {
  final String code;
  final String url;
}

class JoinResult {
  final String groupId;
  final String accessToken;
}

class CommitmentProof {
  final String type;
  final String value;
  final String submittedBy;
}
```

### Implementation Pattern

Each method follows the same pattern:
1. Add abstract method to `ChatEngine`
2. Implement in `ChatEngineImpl` using `_transport` (SupabaseClientWrapper) or direct HTTP
3. For streams, use `StreamController` fed by HTTP/SSE responses
4. For cached lookups (displayName), use an in-memory LRU cache backed by Drift

---

## Sub-Project B: SQLCipher Database Encryption

### Current State
`DatabaseFactory.create()` returns `AppDatabase(WebDatabase('chat_engine'))` — unencrypted.

### Target State
- Platform-native encrypted database via `drift_sqflite` + SQLCipher
- Encryption key: random 256-bit key generated on first launch
- Key stored in iOS Keychain / Android Keystore (hardware-backed, non-extractable)
- Web fallback: IndexedDB (browser manages encryption)
- Optional biometric app lock (separate from DB encryption)

### Changes

**`engine/lib/src/persistence/database/database_factory.dart`** — Complete rewrite:
```dart
class DatabaseFactory {
  static Future<AppDatabase> create({Uint8List? encryptionKey}) async {
    if (kIsWeb) {
      return AppDatabase(WebDatabase('chat_engine'));
    }
    // Native: use SQLCipher via drift_sqflite
    final dbPath = await getDatabasePath();
    return AppDatabase(NativeDatabase.createInBackground(
      File(dbPath),
      setup: (db) {
        if (encryptionKey != null) {
          db.execute("PRAGMA key = '${hex.encode(encryptionKey)}'");
        }
      },
    ));
  }
}
```

**`engine/lib/src/crypto/keys/database_key_manager.dart`** — New file:
```dart
class DatabaseKeyManager {
  static const _keyAlias = 'hello_db_encryption_key';

  /// Get or generate the database encryption key.
  /// Stored in platform keychain (non-extractable).
  static Future<Uint8List> getOrCreateKey() async {
    final storage = FlutterSecureStorage();
    final existing = await storage.read(key: _keyAlias);
    if (existing != null) return base64Decode(existing);

    // Generate new 256-bit key
    final key = Uint8List(32);
    final random = Random.secure();
    for (int i = 0; i < 32; i++) key[i] = random.nextInt(256);

    await storage.write(key: _keyAlias, value: base64Encode(key));
    return key;
  }
}
```

**`engine/lib/src/chat_engine_impl.dart`** — Modify initialize():
```dart
// Before: final db = await DatabaseFactory.create();
// After:
final dbKey = kIsWeb ? null : await DatabaseKeyManager.getOrCreateKey();
final db = await DatabaseFactory.create(encryptionKey: dbKey);
```

**`engine/pubspec.yaml`** — Add `sqflite_sqlcipher` or `sqlcipher_flutter_libs` dependency.

### Optional Biometric App Lock

Separate from DB encryption. Added to engine as a utility:
```dart
class AppLockManager {
  static Future<bool> authenticate({String reason = 'Unlock hello'}) async {
    final auth = LocalAuthentication();
    final canCheck = await auth.canCheckBiometrics;
    if (!canCheck) return true; // No biometrics = no lock
    return auth.authenticate(localizedReason: reason);
  }
}
```

UI calls this before `engine.initialize()` if the user has enabled app lock in settings. The engine doesn't enforce it — the UI does.

---

## Sub-Project C: Auth Flow Wiring

### Current State
`auth_flow_page.dart` uses `_mockNetworkCall()` — a 1500ms `Future.delayed`.

### Target State
Real Firebase Phone OTP → `/api/phone-auth` → JWT → engine re-init with real token.

### Changes

**`engine/lib/src/auth/auth_service.dart`** — New file:
```dart
class AuthService {
  final Uri _serverBaseUrl;

  AuthService(this._serverBaseUrl);

  /// Exchange Firebase ID token for Supabase-compatible JWT
  Future<AuthResult> authenticateWithFirebase(String firebaseIdToken) async {
    final response = await http.post(
      _serverBaseUrl.resolve('/api/phone-auth'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': firebaseIdToken}),
    );
    if (response.statusCode != 200) throw AuthException(response.body);
    final data = jsonDecode(response.body);
    return AuthResult(
      accessToken: data['accessToken'],
      userId: data['userId'],
      isNewUser: data['isNewUser'] ?? false,
    );
  }
}

class AuthResult {
  final String accessToken;
  final String userId;
  final bool isNewUser;
}
```

This is called from the UI's auth flow, BEFORE engine.initialize(). The UI gets the JWT, then passes it as `authToken` to `ChatEngineConfig`.

---

## Sub-Project D: Push Decryption Native Bridge

### Current State
iOS NSE + Android Service exist as stubs. `PushDecryptor` exists in engine. Not connected.

### Changes

**`engine/lib/src/notifications/push_method_channel.dart`** — New file:
```dart
class PushMethodChannel {
  static const _channel = MethodChannel('com.hello.push_decrypt');

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'decryptPush') {
        final payload = PushPayload.fromMap(call.arguments as Map<String, dynamic>);
        final result = await decryptPushPayload(payload);
        return result.toMap();
      }
      return null;
    });
  }
}
```

**iOS NSE (`app/ios/NotificationServiceExtension/NotificationService.swift`)** — Wire to Flutter method channel via App Group shared state.

**Android Service (`app/android/.../HelloMessagingService.kt`)** — Wire to headless Dart isolate via `FlutterEngine` in background.

---

## Build Order & Parallelism

```
PARALLEL GROUP 1:
  Agent 1: Sub-Project B (SQLCipher) — database_factory.dart, database_key_manager.dart, pubspec
  Agent 2: Sub-Project A, Part 1 (6 methods) — getProfile, updateProfile, getDevices, unlinkDevice, getDisplayName, createGroup
  Agent 3: Sub-Project A, Part 2 (6 methods) — streamHelloResponse, getDecisionItems, reactToItem, generateInvite, claimInvite, lockItem

SEQUENTIAL (after Group 1):
  Agent 4: Sub-Project C (Auth) — auth_service.dart, wiring
  Agent 5: Sub-Project D (Push Bridge) — method channel, native wiring

Agents 4+5 can run in parallel since they touch different files.
```
