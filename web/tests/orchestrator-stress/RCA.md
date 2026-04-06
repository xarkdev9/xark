# ROOT CAUSE ANALYSIS: @hello Latency & Intent Fragility

**Date:** 2026-04-05
**Author:** Claude Opus 4.6
**Based on:** 100-scenario stress test (real API calls, real latency data)
**Results file:** `web/tests/orchestrator-stress/results.json`

---

## Test Summary

| Metric | Value |
|--------|-------|
| Total Scenarios | 100 |
| Overall Pass Rate | 77% (77 PASS, 23 FAIL, 0 CRASH) |
| Avg Latency | 10,563ms |
| P50 Latency | 7,881ms |
| P95 Latency | 36,428ms |
| P99 Latency | 45,076ms |
| Security Leaks | 0 |

---

## 1. Execution Flow Map

```
User -> /api/hello/route.ts -> [Sequential Waterfall]

PHASE 1: PRE-ORCHESTRATOR (route.ts:44-266)
  +- [AWAIT] verifyAuth()                          ~50ms
  +- [AWAIT] supabase membership check             ~100ms
  +- [AWAIT] fetchMessages(limit:15)               ~200ms
  +- [AWAIT] Promise.all([                         ~800ms cap
  |    spaceRow, groundingContext,
  |    tasteProfiles (800ms timeout), senderRow
  |  ])
  +- [AWAIT] supabase.insert(phantom receipt)      ~100ms
  +- Total pre-orchestrator:                       ~1.2s

PHASE 2: INTENT PARSING (orchestrator.ts:146-151)
  +- [AWAIT] provider.parseIntent()                ~3-8s (Gemini 2.5 Pro)
  |    +- Builds NEW GoogleGenerativeAI instance    (ai-provider.ts:112)
  |    +- Sends: system prompt (~4000 tokens)
  |    |         + conversation history (up to 15 msgs)
  |    |         + dynamic context (~500 tokens)
  |    |         + 12 function declarations
  |    +- Waits for complete response (no streaming)
  +- Total intent parsing:                         ~3-8s

PHASE 3: TOOL EXECUTION (orchestrator.ts:282-517)
  +- [IF gemini-search tier]:
  |    +- [AWAIT] provider.localSearch()            ~3-8s (2nd Gemini call)
  |    +- [IF empty -> AWAIT] provider.groundedSearch() ~5-15s (3rd Gemini call)
  |    +- Total gemini-search:                     ~6-23s
  |
  +- [IF fli tier]:
  |    +- [AWAIT] getCachedFlights() (Redis)       ~50ms
  |    +- [AWAIT] fetch(/api/fli) (10s timeout)    ~2-10s (Python cold start + API)
  |    +- [IF empty -> AWAIT] SearchAPI fallback   ~2-5s
  |    +- Total fli:                               ~2-15s
  |
  +- [IF searchapi tier]:
  |    +- [AWAIT] searchHotels/Flights/Local()     ~2-5s
  |    +- Total searchapi:                         ~2-5s
  |
  +- [IF apify tier]:
  |    +- [AWAIT] runActor() (sync, blocks)        ~15-40s
  |    +- [IF empty -> AWAIT] generateJson() retry ~3-8s (4th Gemini call)
  |    +- [IF still empty -> AWAIT] runActor() #2  ~15-40s
  |    +- Total apify worst case:                  ~33-88s
  |
  +- [IF itinerary trigger]:
       +- [AWAIT] generateSkeleton() (Gemini)      ~5-10s
       +- [AWAIT] validateDaySlots() (seq per day) ~2-15s
       |    +- Per day: Distance Matrix API + possible Gemini re-prompt
       +- [AWAIT] fillSlots() (seq per slot)       ~10-30s
       |    +- Per slot: SearchAPI call (sequential, not parallel)
       +- Total itinerary:                         ~17-55s

PHASE 4: SYNTHESIS (orchestrator.ts:504-507) -- Apify path only
  +- [AWAIT] provider.synthesize()                 ~3-8s (5th Gemini call!)
  +- Total synthesis:                              ~3-8s

PHASE 5: POST-RESPONSE (route.ts:349-406) -- via after()
  +- [PARALLEL] fetchPexelsUrl() per result        ~0-3s (not blocking)
  +- supabase.upsert(decision_items)               ~200ms (not blocking)
  +- Total: 0 (non-blocking, runs after response)
```

---

## 2. The Latency Leak Table

| Step | File:Line | Measured Time | Root Cause | Potential Gain |
|------|-----------|---------------|------------|----------------|
| GeminiProvider re-instantiates model per parseIntent | `ai-provider.ts:112-122` | ~200ms wasted | Creates new `GoogleGenerativeAI` + `getGenerativeModel` on EVERY call instead of reusing the constructor model. The `systemInstruction` requires a new model instance but the `GoogleGenerativeAI` client should be cached. | ~100-200ms |
| Gemini 2.5 Pro for ALL intent parsing | `ai-provider.ts:114` | 3-8s per call | Pro model is 2-3x slower than Flash for simple intent routing. A one-word prompt like "coffee" doesn't need Pro. | **2-5s** (use Flash for intent, Pro for synthesis only) |
| System prompt is ~4,000 tokens | `orchestrator.ts:525-654` | Adds ~1-2s to every Gemini call | 130 lines of routing rules, 40+ examples, voice rules. Gemini processes ALL of this on every single request. | **1-2s** (trim to essentials, cache static prompt via Gemini context caching API) |
| gemini-search tier: sequential local then grounded | `orchestrator.ts:302-306` | 6-23s | `localSearch()` is awaited first (3-8s). If it returns 0 results, `groundedSearch()` is awaited second (5-15s). These are SEQUENTIAL. | **3-8s** (run both in parallel, take first non-empty) |
| fli Python cold start | `fli-client.ts:63-75` | 2-10s on localhost, 404 on dev | The Python function runs at `/api/fli` which doesn't exist in the Next.js dev server. On Vercel, it's a separate runtime with 2-3s cold start even with keep-warm. | **2-5s** (ensure warm; on localhost, skip fli entirely) |
| fli then SearchAPI then Apify triple waterfall | `orchestrator.ts:328-408` | 10s wasted per flight search | fli fails (10s timeout) then SearchAPI (2-5s) then Apify (15-40s). Each tier waits for the previous to completely fail before trying the next. | **8-10s** (race fli and SearchAPI simultaneously) |
| Itinerary fillSlots is sequential per slot | `itinerary-generator.ts:210-260` | 10-30s | Each slot calls `searchForSlot()` one at a time. A 5-day trip with 15 slots = 15 sequential SearchAPI calls. | **8-25s** (Promise.all on all slot fills) |
| Itinerary geospatial validation is sequential per day | `itinerary-generator.ts:135-170` | 2-15s | `validateDaySlots()` is called per day sequentially. Each day's Distance Matrix calls are parallel, but days are sequential. | **1-10s** (parallel all days) |
| Synthesis is a FULL Gemini Pro call | `orchestrator.ts:505-507` | 3-8s | After tool results arrive, a SEPARATE Gemini call generates the human-readable summary. This adds 3-8s to every Apify-tier request. | **3-8s** (skip synthesis for search results -- use a static template like the SearchAPI tier does) |
| Self-healing retry: Gemini + Apify + Gemini again | `orchestrator.ts:466-480` | 20-50s worst case | On empty results: (1) Gemini generates loosened params (3-8s), (2) Apify retries (15-40s). This is a hidden 20-50s penalty on the failure path. | **20-50s** (remove self-healing retry for V1 -- 503s are common, retrying makes it worse) |
| Dynamic prompt includes 5 pre-computed dates | `orchestrator.ts:681-686` | ~50 tokens wasted per call | 5 `Date()` computations + formatting in every dynamic prompt. Minor token cost but unnecessary complexity. | Negligible |

### Theoretical Minimum Latency (if everything parallelized + Flash for intent)

| Path | Current | Optimized |
|------|---------|-----------|
| Happy hotel search | 1.2s + 5s + 5s = **11.2s** | 0.8s + 2s + 2s = **4.8s** |
| Happy local search | 1.2s + 5s + 8s = **14.2s** | 0.8s + 2s + 3s = **5.8s** |
| Happy flight search | 1.2s + 5s + 12s = **18.2s** | 0.8s + 2s + 3s = **5.8s** |
| Direct response | 1.2s + 5s = **6.2s** | 0.8s + 2s = **2.8s** |
| Itinerary (5 days) | 1.2s + 5s + 35s = **41.2s** | 0.8s + 2s + 10s = **12.8s** |

---

## 3. The Intent Fragility Map

| Failure Mode | Current Prompt/Logic | Why It Fails | Required Change |
|---|---|---|---|
| **Emoji -> Itinerary over-trigger** | `generate_itinerary` description: "what would X days in Y look like" | `tool-registry.ts:183-195`: The description is too broad. Emojis like hotel/plane/food contain travel-related Unicode characters. Gemini interprets them as a multi-intent travel planning request, matching `generate_itinerary`'s description "plan our trip." | Add negative examples to function description: "Do NOT use for emoji-only messages, single words, or gibberish. ONLY use when user explicitly says 'plan', 'itinerary', 'build a plan', 'what would N days look like'." |
| **"Airbnb" -> fails to map to hotel** | `tool-registry.ts:69-81`: hotel description says "hotels, stays, resorts, airbnb, lodging, accommodation" | Test [45]: "airbnb in Santorini with caldera view" returned `reason` (GARBAGE_FALLBACK). The issue is NOT the tool description -- it's a Gemini 503 error. The error fallback at `orchestrator.ts:273-279` catches the 503 and returns GARBAGE_FALLBACK. | This is a **reliability issue**, not a mapping issue. Fix: retry once on 503, or downgrade to Flash for the retry. |
| **"Coffee" -> empty search** | System prompt line 577: "'coffee' -> FAST (local_*)" | Test [42]: Gemini correctly called `search_local_restaurant`. But `localSearch()` returned 0 results, then `groundedSearch()` also returned 0. The query "best coffee shops" in "San Diego" should return results -- this is a Gemini knowledge gap, not a routing failure. | The routing was CORRECT. The issue is Gemini's local knowledge being unreliable for common queries. Fix: add SearchAPI `google_local` as a fallback for the `gemini-search` tier (currently the fallback chain goes `local -> grounded -> give up`; it should go `local -> grounded -> SearchAPI local`). |
| **"bars tonight" -> GARBAGE_FALLBACK** | System prompt line 577: "'bars tonight' -> FAST" | Test [47]: Gemini 503 again. Same root cause as "Airbnb." Not an intent mapping failure. | 503 retry with backoff. |
| **"hotels hotels hotels..." -> GARBAGE_FALLBACK** | `isGarbageResponse()` at `orchestrator.ts:26-34` | The repetition detector at line 32: if any word appears >5 times, it's flagged as garbage. "hotels" repeated 10 times triggers this. But the garbage gate runs on the LLM's RESPONSE, not the user's INPUT. The real issue: Gemini returned a response where a word was repeated >5 times (likely echoing the input), and the garbage gate caught it. | **The garbage gate is too aggressive.** It catches legitimate responses that contain repeated words. Fix: only apply the repetition check to synthesis responses (Apify tier), not to direct `respond_to_user` function calls. |
| **"find hotels find flights..." -> itinerary** | `generate_itinerary` description too broad | Same as emoji trigger. Multi-intent messages match the "plan" concept. | Tighten `generate_itinerary` trigger to require explicit plan/itinerary keywords. |
| **"book the marriott" -> hotel search** | System prompt line 601: "hotels -> hotel tool" | Test [51]: User said "book" which implies a specific hotel, not a search. But the system prompt says "MUST use [hotel tool] for ANY lodging request." Gemini correctly interpreted "marriott" as a lodging term. The test's expected_tool was wrong -- the AI's behavior is actually reasonable (search for Marriott availability). | **No code change needed.** The test expectation was wrong. |
| **No `generate_itinerary` in routing examples** | `orchestrator.ts:615-641` | The routing examples section lists 25 examples but NONE show `generate_itinerary` or `modify_itinerary`. Gemini has the function declarations but no examples of when to use them. | Add routing examples for both new functions. |

---

## 4. File-Level "Red Zones"

### CRITICAL (Fix first -- directly causes latency/fragility)

| File | Lines | Issue |
|------|-------|-------|
| `ai-provider.ts` | 112-122 | **Re-instantiates GoogleGenerativeAI on every parseIntent call.** Creates a new client + model per request instead of reusing the constructor model. |
| `ai-provider.ts` | 114 | **Uses Pro for ALL calls including intent parsing.** Intent routing for "coffee" doesn't need Pro -- Flash is 3x faster and equally accurate for function calling. |
| `orchestrator.ts` | 302-306 | **Sequential local -> grounded search.** Both Gemini calls are awaited in series. Should race in parallel. |
| `orchestrator.ts` | 504-507 | **Unnecessary synthesis call.** SearchAPI/fli tiers skip synthesis (return immediately with results). Apify tier wastes 3-8s on a Gemini call to generate a one-line summary that could be a template. |
| `orchestrator.ts` | 465-480 | **Self-healing retry on Apify empty results.** Fires another Gemini call + Apify call on failure. In practice, this turns a 20s failure into a 50s failure. |
| `orchestrator.ts` | 525-654 | **4,000-token system prompt sent on every request.** Includes 40+ routing examples. Gemini Context Caching could eliminate this overhead. |
| `itinerary-generator.ts` | 210-260 | **Sequential slot filling.** 15 slots x 2-5s each = 30-75s. Should be `Promise.all`. |
| `tool-registry.ts` | 183-195 | **`generate_itinerary` description too broad.** Triggers on emojis and multi-intent messages. |

### HIGH (Fix second -- contributes to unreliability)

| File | Lines | Issue |
|------|-------|-------|
| `orchestrator.ts` | 273-279 | **503 errors return GARBAGE_FALLBACK with no retry.** Gemini Pro 503s are transient. One retry with 1s backoff would recover most of them. |
| `orchestrator.ts` | 16-37 | **Garbage gate too aggressive.** Repetition threshold (>5 same words) catches legitimate responses. Should only apply to synthesis, not function call responses. |
| `fli-client.ts` | 41-44 | **`getFliBaseUrl()` returns `localhost:3000` in dev.** The Python function only works on Vercel. Dev testing always fails with 404, wasting 10s on the timeout. |
| `orchestrator.ts` | 328-368 | **fli tier failure causes 10s timeout before fallback.** `AbortSignal.timeout(10000)` means every dev-mode flight search wastes 10s before falling through to SearchAPI. |

### MEDIUM (Polish -- minor gains)

| File | Lines | Issue |
|------|-------|-------|
| `orchestrator.ts` | 615-641 | **No examples for `generate_itinerary` or `modify_itinerary`** in the routing examples section. Gemini has to guess when to use them. |
| `ai-provider.ts` | 7 | **45s timeout is too generous.** If Gemini hasn't responded in 15s, it's likely 503'd or stuck. Reduce to 15-20s for intent parsing. |
| `itinerary-generator.ts` | 135-170 | **Geospatial validation runs sequentially per day.** Should parallelize across all days. |
| `orchestrator.ts` | 681-686 | **5 pre-computed dates in every dynamic prompt.** Minor token waste (~50 tokens) but unnecessary complexity. |

---

## 5. Top 10 Slowest Requests (from stress test)

| ID | Latency | Category | Tool | Prompt |
|----|---------|----------|------|--------|
| 28 | 45,076ms | edge_case | itinerary | Emoji string (travel emojis) |
| 27 | 42,679ms | edge_case | itinerary | "find hotels find flights find restaurants..." |
| 37 | 39,139ms | edge_case | reason | "hotels hotels hotels..." (garbage gate) |
| 42 | 37,984ms | function_calling | search | "coffee" (local+grounded both empty) |
| 59 | 36,428ms | function_calling | itinerary | "plan our trip to Bali for 5 days" (correct but slow) |
| 63 | 32,509ms | api_failure | search | "restaurants in Narnia" |
| 4 | 24,933ms | happy_path | local_activity | "sunset spots in Big Sur" |
| 71 | 23,730ms | api_failure | flight | "flights from ABC123 to XYZ789" |
| 8 | 22,889ms | happy_path | local_activity | "things to do in Barcelona" |
| 49 | 22,387ms | function_calling | general | "find a restaurant but make it a hotel" |

---

## 6. Latency by Tier (from stress test)

| Tier | Avg | P95 | Count |
|------|-----|-----|-------|
| apify | 23,730ms | 23,730ms | 1 |
| gemini-search | 19,863ms | 24,933ms | 12 |
| none (crashes) | 16,416ms | 37,984ms | 5 |
| google-hotels | 14,426ms | 45,076ms | 14 |
| google-search | 10,237ms | 22,387ms | 7 |
| google-flights | 8,769ms | 11,670ms | 4 |
| direct (no search) | 6,706ms | 17,074ms | 57 |

---

## 7. Itinerary Over-Triggers (3 false positives)

| ID | Prompt | Latency | Why it triggered |
|----|--------|---------|-----------------|
| 27 | "find hotels find flights find restaurants find activities find everything all at once" | 42,679ms | Multi-intent parsed as "plan the whole trip" |
| 28 | Emoji string with hotel/plane/food emojis | 45,076ms | Travel emojis interpreted as trip planning intent |
| 59 | "plan our trip to Bali for 5 days" | 36,428ms | **Correct trigger** -- this is a legitimate itinerary request |

---

## 8. Recommended Fix Priority

### Week 1: Latency (biggest user impact)

1. **Use Flash for intent parsing, Pro for synthesis only** -- saves 2-5s per request
2. **Parallelize local + grounded search** -- saves 3-8s on gemini-search tier
3. **Parallelize itinerary slot filling** -- saves 8-25s on itinerary generation
4. **Remove Apify self-healing retry** -- prevents 20-50s penalty on failure path
5. **Skip synthesis for search results** -- saves 3-8s on Apify tier

### Week 2: Reliability

6. **Add 503 retry with 1s backoff** -- recovers most transient Gemini failures
7. **Add SearchAPI fallback to gemini-search tier** -- prevents empty results on common queries
8. **Reduce fli timeout to 5s** -- cuts dev-mode flight search penalty in half
9. **Skip fli on localhost** -- detect `!process.env.VERCEL_URL` and go straight to SearchAPI

### Week 3: Intent Quality

10. **Tighten generate_itinerary trigger** -- add negative examples, require explicit keywords
11. **Add routing examples for itinerary/modify** -- 3-4 examples in system prompt
12. **Relax garbage gate** -- don't apply repetition check to function call responses
13. **Trim system prompt** -- remove redundant examples, target <2000 tokens
