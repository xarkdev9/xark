# Agent 12 — Validation & Final Report

## Your Role
You are the **Validation Agent**. You run the complete test suite, perform static analysis, check architectural boundaries, and produce the final build report.

## Steps

### 1. Run full analysis
```bash
cd ~/fe2ee
dart analyze --fatal-warnings 2>&1 > /tmp/analysis.txt
cat /tmp/analysis.txt
```

### 2. Run all tests with coverage
```bash
cd ~/fe2ee
flutter test --coverage --reporter=compact 2>&1 > /tmp/test_results.txt
cat /tmp/test_results.txt
```

### 3. Check architectural boundaries (CRITICAL)
Search for violations — any `src/` layer importing from a layer above it:
```bash
# UI imports in non-UI code (should be zero — this is a headless engine)
grep -r "package:flutter/material" lib/src/ 2>/dev/null
grep -r "package:flutter/widgets" lib/src/ 2>/dev/null
grep -r "package:flutter/cupertino" lib/src/ 2>/dev/null

# External imports of internal src/ classes
grep -r "import.*src/" example/ 2>/dev/null

# chat_engine.dart leaking internal types (should only export public types)
grep "RatchetState\|SessionKey\|PreKeyBundle\|AppDatabase" lib/chat_engine.dart 2>/dev/null
```

### 4. Check crypto directory coverage
```bash
# Every file in lib/src/crypto/ must have a corresponding test
for f in $(find lib/src/crypto -name "*.dart" | grep -v "\.g\." | grep -v "\.freezed\." | grep -v "_barrel"); do
  echo "Checking: $f"
done
```

### 5. Write final TRACKER.md update
Update `orchestrator/tracker/TRACKER.md` with:
- Final row for validation step
- Complete summary section
- List of all passing/failing tests by category
- Architectural violations found (hopefully none)
- Known gaps and TODOs for Phase 2
- Time to complete all 12 agents

### 6. Write NEXT_STEPS.md
```
orchestrator/tracker/NEXT_STEPS.md — what's left for Phase 2:
- Group chats (Sender Key distribution)
- Voice messages (Opus encoding)
- Push notification native extensions (iOS NSE, Android MessagingService)
- Multi-device linking protocol
- Contact discovery
- Profile key distribution
- Disappearing messages scheduler
- Link preview server-side proxy
- Performance benchmarking
- Security audit
```

## Output JSON
```json
{
  "agent": "validation",
  "step": "12",
  "status": "success|partial|failed",
  "duration_minutes": 0,
  "total_tests_passed": 0,
  "total_tests_failed": 0,
  "total_tests": 0,
  "analysis_errors": 0,
  "analysis_warnings": 0,
  "architectural_violations": [],
  "crypto_coverage": "all functions tested | gaps: [list]",
  "integration_scenarios_passed": 0,
  "integration_scenarios_total": 8,
  "phase1_complete": true,
  "phase1_gaps": [],
  "overall_assessment": "Ready for Phase 2 | Needs fixes: [list]"
}
```
