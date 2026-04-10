# PHASE 1 FRONTEND MANIFEST

This document defines the exact architectural state of the frontend Phase 1 integration. It serves as the authoritative handoff manual for backend engineers initiating Phase 2 (Multi-device, Push Notifications, App Lock) of the E2EE Flutter client.

## Section 1: UI & Performance Doctrines (CRITICAL)

The frontend operates under strict visual and physical doctrines to maintain a 120fps "Apple-Scale" premium experience.

*   **Zero-Box Doctrine**: The UI categorically rejects standard Material design containers, explicit 1px borders, generic drop shadows (`BoxShadow`), and standard cards. Contrast is established through mathematical spacing, typography, and optical filters (e.g., `BackdropFilter` with `PathFillType.evenOdd`).
*   **No-Bold Mandate**: Font weights strictly max out at 400 (`FontWeight.w400`). Visual hierarchy is established exclusively through extreme typographic scaling (e.g., `HelloTypography.hero`) and opacity mutations, never through bold text.
*   **Physics and Haptics over Widgets**: Standard UI responses like `ElevatedButton` and Material ripples (`InkWell`) are banned. Interactions are built natively using raw `GestureDetector` inputs bound to `SpringSimulation` physics to simulate physical mass. Interactions are coupled tight with explicitly timed `HapticFeedback` (e.g., `selectionClick()` and `heavyImpact()`).

## Section 2: Engine Integration State (fe2ee)

The frontend successfully crossed the Reality Bridge, securely binding its UI to the `package:chat_engine/chat_engine.dart` backend engine.

*   **Bootloader Initialization**: `ChatEngine.initialize()` acts as the synchronous bootloader within `main.dart`, successfully initializing the engine instance with environmental variables (tokens, user IDs, Supabase credentials) before Riverpod hooks the dependency tree.
*   **Lifecycle Awareness**: A global `WidgetsBindingObserver` listens for `AppLifecycleState` events. The engine natively receives `.suspend()` and `.resume()` commands, ensuring battery and socket efficiency during background execution.
*   **Global Headless Error Bus**: An external error listener (`providers/engine_error_listener.dart`) actively traps `engine.errors`. It enforces security by handling core engine failures globally (e.g., trapping `AuthTokenExpired` to trigger a hard wipe and router purge to `/login`).
*   **Reactive Stream Pipelining**: The legacy mocked frontend state was abolished. Riverpod connects raw engine data (such as mapping `engine.conversations` to `StreamProvider` wrappers). The UI reacts automatically without manual controller syncing.

## Section 3: Screen-by-Screen Architectural Breakdown

*   **Auth Flow (Welcome -> Phone -> OTP)**: Operates entirely as a single-page state machine utilizing Riverpod state flags. State transitions utilize smooth 400ms `ImageFilter.blur` sweeps. The Typographic OTP field operates natively by overlaying massive text over a hidden, heavily constrained `TextField` engine to intercept native keyboard events safely.
*   **Spatial Home Screen**: Eradicates the standard `BottomNavigationBar`. Tab navigation relies on a `PageController` mathematically mapped to an `AnimatedBuilder`, shifting the scale and opacity of raw typographic header words ("Chats", "Groups", "Memories") natively in exact lockstep with user scrolling.
*   **Chats Tab**: Streams directly from the backend conversation pipeline. Adheres to the Zero-Box doctrine via edge-to-edge 56x56 avatars, zero vertical dividers, and unread statuses mapped natively to an 8x8 glowing Rose (`#D4536B`) dot indicator instead of numbered red badges.
*   **Chat View**: Implements a highly optimized, `reverse: true` message feed directly attached to the E2EE delivery sink. The composer enforces the `@hello` intent boundary: the string natively targets an `AnimatedContainer` that organically morphs the UI into `#D4536B` for feedback but **never** sends E2EE contextual history into an AI backend.
*   **Social Physics (Decision Board)**: Constructed via a Netflix-style `PageView.builder` at an `0.85` viewport fraction ensuring adjacent cards "peek." Tap dynamics invoke `SpringSimulation` scaling physics. At an `80%` consensus limit, the system fires a Gold Burst: triggering a heavy haptic impact, establishing local constraint locks, and structurally dimming all surrounding suboptimal cards to 30% opacity via global locking mechanisms.
*   **Cryptographic Handshake (Sesame QR)**: Replaced standard UI boxes with an infinitely executing loop simulating the camera gradient feed. An optical mask built using a pure `CustomClipper` and `BackdropFilter` (15 sigma) creates an inverted clear window. Upon physical interaction (a successful scan), the viewport mathematically halts, the UI flashes the verification payload color (Rose `#D4536B` 40%), and locks a 1.5-second `Future.delayed` key distribution simulation.

## Section 4: Phase 2 Hooks (What Frontend Needs Next)

The frontend architecture comprises active stubs pre-configured to intercept the Phase 2 backend logic:

*   **App Lock**: The UI architecture currently maps global interactions. We anticipate catching an engine state or `BiometricUnavailable` (or active lock intent) emitted by `engine.errors` or a stream, waiting to aggressively route the user into a Pin/FaceID cryptographic gateway.
*   **Multi-Device Synchronization**: The `Cryptographic Handshake` currently pauses against a `Future.delayed(1500ms)` simulation. This mock immediately awaits replacement with the native `fe2ee` multi-device key exchange trigger.
*   **Push Notifications (FCM/APNs)**: The platform natively catches active E2EE messages via `chat_engine` while active. We await structured routing mechanisms to securely intercept headless push payloads in the background globally, bypassing OS preview data leaks and safely surfacing decrypted alerts locally to the user frame.

## Section 5: WHAT NEEDS VALIDATION
1. The Media Pipeline & Memory Fortress (CRITICAL)
You completely removed the custom crypto isolate and wired the media directly to the engine, but this isn't in the manifest. The backend team needs to know:

The Hook: The UI calls engine.downloadMedia(metadata) and listens to the progress stream.

The Memory Rule: The UI explicitly waits for progress.localPath and uses FileImage(File(localPath)). They need to know you are strictly forbidding MemoryImage to prevent Out-of-Memory (OOM) crashes.

The Visuals: The UI relies on the base64 inlineThumbnail for an instant blur, followed by a 300ms AnimatedCrossFade once the file hits the disk.

2. Delivery Receipts & Presence
The manifest mentions the Rose (#D4536B) unread dot for the chat list, but it misses the individual message status inside the ChatView.

Receipts: The UI needs to map session.receipts to the MessageStatus enum (sending, sent, delivered, read) to drive the visual ticks (or whatever Zero-Box equivalent you design) on the message bubbles.

Presence: The UI needs to listen to session.presence to show "online" or "last seen" states in the 1:1 chat app bar.

3. Pagination (The loadMore Hook)
The ChatView correctly notes the reverse: true list and the live stream, but the default stream only yields the latest 50 messages.

The Hook: The backend needs to know how the UI triggers session.loadMore(limit: 50) when the user scrolls to the top of the feed to inject older messages into the view.

4. Contact Discovery (Phone Hashing)
The Auth Flow mentions entering the phone number and routing to the Home screen, but it skips the discovery phase.

The Hook: There needs to be a stub or note explaining where the frontend will call engine.discoverContacts(phoneHashes) to match the user's local address book with registered fe2ee users.