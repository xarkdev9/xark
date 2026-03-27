# Agent 11 — Integration Tests

## Your Role
You are the **Integration Test Agent**. You write end-to-end integration tests using a mock WebSocket server. These tests prove the full pipeline works: send → encrypt → transport → receive → decrypt → persist → stream.

## Files to Create

### test/helpers/mock_server.dart — Full implementation
```dart
// MockChatServer — in-process WebSocket server for tests
// Uses shelf + shelf_web_socket
// Behavior:
//   - Accepts WebSocket connections
//   - Stores registered users + PreKey bundles in memory
//   - Routes encrypted messages between connected clients
//   - Assigns monotonically increasing serverSeq per conversation
//   - Returns message history via REST mock (use dio mock adapter)
//   - Does NOT decrypt anything — just routes binary blobs
//
// MockServer.start() → Future<MockServer> (on localhost:0, random port)
// MockServer.stop() → Future<void>
// MockServer.port → int
```

### test/integration/messaging_integration_test.dart
```dart
// Full E2E test scenarios:

// Scenario 1: Basic 1:1 message send and receive
// - Start MockServer
// - Initialize ChatEngine for Alice (deviceA1)
// - Initialize ChatEngine for Bob (deviceB1)
// - Alice.getSession(bobId).sendText("Hello Bob")
// - Await Bob's session.messages stream → expect message with text "Hello Bob"
// - Verify Message.status = delivered on Alice's side
// - Verify Bob's unreadCount = 1

// Scenario 2: Offline message delivery
// - Alice sends 3 messages while Bob is offline (Bob's engine suspended)
// - Bob comes online (resume())
// - Verify Bob receives all 3 messages in correct order

// Scenario 3: Read receipts
// - Alice sends message, Bob receives
// - Bob.session.markRead(messageId)
// - Verify Alice's session.receipts stream emits readAt receipt

// Scenario 4: Typing indicators
// - Bob calls session.sendTyping()
// - Verify Alice's session.typing stream emits Bob's typing indicator
// - Verify indicator clears after 5 seconds (no further sendTyping calls)

// Scenario 5: Delete for everyone
// - Alice sends message, Bob receives
// - Alice.session.deleteForEveryone(messageId)
// - Verify Bob's message stream shows message as deleted

// Scenario 6: Outbox retry
// - Alice sends message while server is down (MockServer.stop())
// - Message is in outbox
// - MockServer.start() again
// - Alice.resume()
// - Verify message eventually delivered

// Scenario 7: Deduplication
// - Simulate duplicate envelope from server
// - Verify message appears exactly once in Bob's stream

// Scenario 8: Multi-device (Alice has phone + laptop)
// - Initialize Alice on deviceA1 and deviceA2
// - Bob sends message to Alice
// - Verify BOTH deviceA1 and deviceA2 receive the message (separate ciphertexts)
```

## Run Tests
```bash
cd ~/fe2ee
flutter test test/integration/ --reporter=expanded --timeout=120s 2>&1
```

Note: integration tests may take longer. Use 120s timeout.

## Output JSON
```json
{
  "agent": "integration_tests",
  "step": "11",
  "status": "success|failed|partial",
  "duration_minutes": 0,
  "files_created": [],
  "files_modified": [],
  "tests_passed": 0,
  "tests_total": 8,
  "scenarios_passed": [],
  "scenarios_failed": [],
  "warnings": [],
  "errors": [],
  "context_for_next": "Integration tests complete. N/8 scenarios passing. [List any failing scenarios with root cause]. MockServer implemented at test/helpers/mock_server.dart using shelf + shelf_web_socket. Key finding for validation agent: [any systemic issues found during integration]."
}
```

---

