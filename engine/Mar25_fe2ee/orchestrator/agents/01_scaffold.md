# Agent 01 — Project Scaffold

## Your Role
You are the **Scaffold Agent**. You set up the entire project structure, pubspec.yaml, analysis options, and build configuration. You write no business logic — only structure, config, and empty placeholder files with correct package declarations.

## Project Location
`~/fe2ee/` — this is an existing empty Flutter project. Work inside it.

## Task

### 1. Convert to a Flutter package
Update `pubspec.yaml` to:
```yaml
name: chat_engine
description: Production-grade E2EE Flutter chat engine. Headless — no UI code.
version: 0.1.0
publish_to: none

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: '>=3.19.0'

dependencies:
  flutter:
    sdk: flutter
  # Crypto
  cryptography: ^2.7.0
  # Persistence
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.0
  drift_sqflite: ^2.2.0
  flutter_secure_storage: ^9.0.0
  # Networking
  supabase_flutter: ^2.8.0
  firebase_storage: ^12.3.0
  # Serialization
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0
  # IDs
  uuid: ^4.4.0
  # Notifications
  firebase_messaging: ^15.0.0
  # Utils
  rxdart: ^0.27.7
  path_provider: ^2.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  drift_dev: ^2.18.0
  very_good_analysis: ^6.0.0
  mocktail: ^1.0.0
  shelf: ^1.4.0
  shelf_web_socket: ^2.0.0
```

### 2. Create analysis_options.yaml
```yaml
include: package:very_good_analysis/analysis_options.yaml
analyzer:
  exclude:
    - '**/*.g.dart'
    - '**/*.freezed.dart'
```

### 3. Create the full directory structure
Create these directories and a `.gitkeep` or minimal placeholder dart file in each:

```
lib/
  chat_engine.dart                    ← barrel file (empty export stubs for now)
  src/
    crypto/
      x3dh/
      ratchet/
      keys/
      crypto.dart                     ← internal barrel
    transport/
      supabase_client.dart          ← Supabase REST + Realtime wrapper
      firebase_storage_client.dart   ← Firebase Storage for E2EE media
      transport.dart
    persistence/
      database/
      repositories/
      persistence.dart
    sync/
      sync.dart
    media/
      media.dart
    notifications/
      notifications.dart
    contacts/
      contacts.dart                     ← Phase 2 stub only
    devices/
      devices.dart                      ← Phase 2 stub only
    domain/
      models/
      repositories/
      use_cases/
      domain.dart
    observer/
      observer.dart

test/
  crypto/
  transport/
  persistence/
  domain/
  integration/
  helpers/
    mock_server.dart                  ← stub only
    test_helpers.dart                 ← stub only

ios/
  NotificationServiceExtension/
    NotificationService.swift         ← stub with TODO

android/
  app/src/main/kotlin/.../
    MessagingService.kt               ← stub with TODO

orchestrator/
  tracker/
    TRACKER.md                        ← copy from TRACKER_INIT.md
```

### Phase 2 Stub Files

Create `lib/src/contacts/contacts.dart` with this exact content:
```dart
/// Contact discovery — Phase 2.
/// Hashed phone number lookup and profile key distribution.
/// See CLAUDE.md §Contact Discovery and §Profile Metadata Encryption.
library;

// TODO(phase2): Implement ContactDiscovery and ProfileKeyDistributor.
// Dependencies: crypto layer (profile_crypto.dart), transport layer (api_client.dart).
```

Create `lib/src/devices/devices.dart` with this exact content:
```dart
/// Device management — Phase 2.
/// Device registry, linking protocol, and multi-device key rotation.
/// See CLAUDE.md §Multi-Device Architecture.
library;

// TODO(phase2): Implement DeviceRegistry, DeviceLinkingProtocol, and KeyRotationService.
// Dependencies: crypto layer (key_store.dart), transport layer (api_client.dart).
```

### 4. Create lib/chat_engine.dart barrel (stub)
```dart
/// E2EE Flutter Chat Engine
/// Public API — the only file external packages should import.
library chat_engine;

// Will be populated by Agent 10 (Public API Agent)
// Stubs here to allow other agents to reference types

export 'src/domain/domain.dart';
export 'src/observer/observer.dart';
```

### 5. Run
```bash
cd ~/fe2ee
flutter pub get
dart analyze --fatal-infos 2>&1 | head -50
```

Report any pub get failures as FAILED. Analysis warnings are acceptable.

## Output (return this JSON exactly)

```json
{
  "agent": "scaffold",
  "step": "01",
  "status": "success|failed",
  "duration_minutes": 0,
  "files_created": [],
  "files_modified": ["pubspec.yaml", "analysis_options.yaml"],
  "tests_passed": 0,
  "tests_total": 0,
  "warnings": [],
  "errors": [],
  "context_for_next": "Project scaffolded at ~/fe2ee. pubspec.yaml locked. flutter pub get succeeded. Directory structure created. Key paths: lib/src/crypto/, lib/src/domain/, lib/src/persistence/, lib/src/transport/, lib/src/sync/, lib/src/media/. Next agent should begin writing domain models into lib/src/domain/models/."
}
```
