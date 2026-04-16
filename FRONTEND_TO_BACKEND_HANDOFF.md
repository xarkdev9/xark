# Frontend to Backend Handoff

## Section 1: The Architectural Contract

**UI Doctrines**:
- **Zero-Box Doctrine**: UI elements must completely avoid generic borders, Material containers, or standard visible bounding boxes. Deeply immersive layouts utilizing blurs and negative space are enforced.
- **No-Bold Mandate**: All typography is strictly confined to `w400` weights or lower. Emphasized elements must rely on size and localized color tinting.
- **120fps physics**: Heavy `AnimationControllers`, physics-based `SpringSimulation` envelopes, and localized haptics are strictly measured.

> [!WARNING]
> **CRITICAL MANDATE FOR BACKEND AGENT**: You are strictly forbidden from modifying UI layout, `GestureDetector` physics, `SpringSimulation` curves, or animation durations. Your sole job is to swap out our mocked Riverpod providers replacing them natively with internal `fe2ee` engine API calls and streams.

---

## Section 2: Fully Wired & Operational Components

The following components are fully bound directly natively to the live `chat_engine`:
- **Auth Flow**: The complete sequence (`Welcome` -> `Phone` -> `OTP`).
- **Spatial Home**: Functional interfaces bridging `Chats`, `Groups`, and the `EncryptedImageView` `Memories` grid. 
- **Chat View**: The spatial `E2EE message feed`, supporting `Delivery Receipts`, natively localized `Typing Indicators`, `Presence` streams, and scroll-driven `Pagination`.

---

## Section 3: Mocked Components (Action Required by Backend)

The specific modules documented below have complete UI and physical interaction architectures constructed, but are reliant locally on simulated Riverpod streams. 

### Identity Suite
- **Files**: `settings_page.dart`, `profile_edit.dart`, `device_list.dart`
- **Current State**: Using entirely generic internal Riverpod mock data providers (`ProfileNotifier`, `DeviceNotifier`).
- **Backend Requirement**: Build and expose the precise RPC bindings traversing `engine.getProfile()`, `engine.updateProfile()`, `engine.getDevices()`, and `engine.unlinkDevice()`.

### AI Spotlight
- **Files**: `spotlight_sheet.dart`
- **Current State**: Simulating SSE boundaries using a looping `Stream.periodic` Riverpod generator payload.
- **Backend Requirement**: Complete the backend protocol and expose `engine.streamHelloResponse(prompt, groupId)` natively connecting to the SSE endpoint layer.

### Decision Board
- **Files**: `action_carousel_page.dart`
- **Current State**: Complete UI executing interaction and physical bounds logic natively relying on simulated action data.
- **Backend Requirement**: Enable and bind the `engine.getDecisionItems(groupId)` logic along with the active vote state mutation `engine.react(itemId)`.

### Social Growth Flow
- **Files**: `invite_surface.dart`, `claim_sheet.dart`
- **Current State**: Operating flawlessly via DeepLink global state simulators bridging complex animation matrices smoothly.
- **Backend Requirement**: Wire the action commands executing `engine.generateInvite()` mapping back onto the deep link payload executing `engine.processJoinRequest()`.

---

## Section 4: The Database Encryption Blocker

> [!CAUTION]
> The Biometric Vault functionality remains entirely suspended because the raw engine initializes an unencrypted standard `WebDatabase`.

**Directive to Backend Agent**: Upgrade the engine resolving against `drift_sqflite` alongside `SQLCipher`. Configure `DatabaseFactory.create()` to accept a symmetric encryption key derived completely from the underlying OS Secure Enclave / Keystore logic natively.

---

## Section 5: Native Push Decryption Scaffolding

> [!IMPORTANT]
> The UI scaffolding is verified and ready. The primary bridge implementations bounding the native iOS `NotificationServiceExtension` and the identical counterpart Android `FirebaseMessagingService` logic must be actively written. This logic must successfully boot the headless Dart core isolate intercepting background deliveries strictly resolving local execution payload decryptions.
