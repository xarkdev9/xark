# Spec 7: White-Label SDK Conversion + 100 Validation Tests

**Date:** 2026-03-28
**Scope:** Convert hello_engine → e2ee_chat_sdk white-label SDK + 100 tests (50 stress + 50 crypto)
**Mode:** YOLO overnight, multi-agent parallel execution

---

## Task 1: BrandConfig + Package Rename
- Rename package hello_engine → e2ee_chat_sdk
- Create BrandConfig class with appName, aiName, aiEndpoint, pushChannelId
- Replace ALL hardcoded 'hello' with brand config references
- MessageType.hello → MessageType.ai
- DB key alias: hello_db_encryption_key → e2ee_chat_db_key
- Method channel: com.hello.push_decrypt → com.e2ee_chat.push_decrypt
- Barrel file: chat_engine.dart → e2ee_chat.dart

## Task 2: Transport Adapter (Wire Strangler Fig Ports)
- SupabaseMessageGateway implementing MessageGateway
- SupabaseRealtimeGateway implementing RealtimeGateway
- SupabaseTransientQueue implementing TransientQueue
- ChatEngineImpl accepts adapters via config
- supabase_flutter becomes optional

## Task 3: Push Adapter
- PushAdapter interface
- FirebasePushAdapter implementation
- firebase_messaging becomes optional

## Task 4: AI Adapter
- AIAdapter interface
- SSEAIAdapter implementation
- streamHelloResponse delegates to adapter

## Task 5: Extract Decision Engine
- ChatEngineDecisions mixin/extension
- Core ChatEngine = messaging only

## Task 6: 100 Validation Tests (50 stress + 50 crypto)
- Run against live Supabase using .env.local credentials
- Save results to docs/test-results/2026-03-28-sdk-validation.md
