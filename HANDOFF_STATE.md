# HANDOFF_STATE: Phase 2 Project Context
> **Generated:** 2026-04-02
> **Role:** Lead Systems Architect

## Section 1: The Project Identity & Doctrines
The `hello` app is an End-to-End Encrypted (E2EE) messaging client built purely in Flutter. All incoming AI agents MUST adhere unconditionally to these immutable UI rules:
- **Zero-Box Doctrine**: No borders, no explicit box boundaries, no shadows. Interfaces must flatly float.
- **No-Bold Mandate**: `FontWeight.w400` is the absolute maximum weight allowed. Emphasis is derived entirely from size, spacing, or opacity shifts.
- **Liquid Physics**: Traditional Material ripples are outright banned. Interactions must rely purely on Apple-scale `SpringSimulation` momentum, breathing opacities, and fluid gestural sweeps.

## Section 2: The Core Architecture (The Map)
**`ARCHITECTURE_MAP.md` is the absolute ground truth for this ecosystem.**
The `e2ee_chat_sdk` defines the underlying contracts. Before generating ANY code or modifying providers, you MUST read `ARCHITECTURE_MAP.md` completely. It delineates the separation of concerns between our E2EE Core, Data Flow loops, and Frontend Presentation layers.

## Section 3: What We Just Built (Current State)
We successfully phased out the legacy mock setups and deployed the **V4 Matrix Simulation Ecosystem**.

1. **The Native Bindings**: We built `MockChatEngine` (located in `app/lib/src/mock_chat_engine.dart`). It rigidly adheres to the `ChatEngine` and `ChatEngineDecisions` abstracts from the root SDK, completely bypassing the need for a live backend while allowing rigorous local testing.
2. **The Trojan E2EE Payload**: We sidestepped the crypto isolates purely for visual UI testing. We achieved this by stuffing high-quality Unsplash image URLs inside the `EncryptedImageView` JSON schemas using hijacked `MediaMetadata` keys.
3. **The Spatial UI**:
   - `SpaceLayout` governs the horizontal carousel, allowing seamless swiping between a group's `ChatView` and the `PossibilityHorizon` (The Decision Board).
   - `@hello AI Spotlight`: We scaffolded the UI breathing physics and streaming AI token chunks, visually routing them via the `ChatEngine.streamHelloResponse` RPC.

## Section 4: The Simulation Status
The environment is currently fully operational, robust, and completely local:
- **The 60fps Heartbeat**: Yes, it is fully active. A `Timer.periodic` loop constantly injects background noise. It drives live typing indicators, morphs message receipts successfully (Sent → Delivered → Read), and smoothly inflates "Consensus Glow" agreement metrics for the interactive cards.
- **Data Seed**: Over 20 chat environments, including legacy 1:1 and rich Group threads padding the timeline. The "Bali Trip" and "Sarah's 30th" spaces are actively injecting opulent Decision Items (Flights, St. Regis Hotels, Michelin-starred Restaurants) dynamically, complete with Unsplash media structures hooked right into the `ActionCardWidget`.
- **UI Integrity Fix**: After overcoming critical Web Socket streaming blanks, all SDK streams are exclusively piped natively through caching `BehaviorSubject` arrays (`rxdart`). It ensures massive data flows mount frictionlessly inside the complex web interfaces. 

## Section 5: Next Immediate Objectives
**To the Incoming Agent:**
1. **Premium UI Migration**: We successfully built the Data Engine, but the Flutter UI is currently lacking the premium `xark9` UI tokens (iMessage-styled Home Search Bar, intricate `@xark` ChatInput with liquid border). Begin migrating these precise UI artifacts into the newly stabilized Flutter streams.
2. **Phase 3 Route (Isolates)**: If the layout constraints are fully met, the next step involves waking up the genuine Cryptographic Isolate channels mapped in the `ARCHITECTURE_MAP.md`.
