# Discovery Engine + Feedback System Design Spec

**Date:** 2026-04-02
**Status:** Approved
**Scope:** Instagram-style recommendation engine + contextual error/feedback reporting

## Overview

Two integrated systems built into the hello engine:

1. **Discovery Engine** — taste-driven recommendation feed with three UI layers (explore tab, stories carousel, in-feed suggestion cards). Powered by a hybrid seeded catalog + Gemini enrichment + pluggable third-party providers. Ranking happens on-device for maximum privacy.

2. **Feedback System** — contextual error cards that appear inline when something fails, plus @hello conversational bug reporting. Auto-captures error context, user adds optional description.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Architecture | Engine mixin (`ChatEngineDiscovery`) | Security boundary enforced — UI never talks to backend directly |
| Ranking location | On-device (engine) | Taste data never leaves device — maximum privacy |
| Content sourcing | Server-side provider registry | Add providers (Google Places, Yelp) without engine/app updates |
| Data model | Hybrid: seeded catalog + Gemini enrichment | Fast initial load from DB, AI adds personalization layer |
| Social proof | Not included | E2EE prevents reading other groups' decisions. L3 only. |
| Feedback trigger | Contextual error cards + @hello conversation | Cards catch the moment, @hello makes reporting natural |
| Privacy | No message content, no taste data, no keys in reports | Error reports contain only generic codes + device info |
| UI platform | Flutter only | Single frontend strategy |
| Offline support | SQLCipher cache with 6h TTL | Stale cache better than empty screen |

---

## 1. System Architecture

```
Flutter App (app/)
├── DiscoveryCarousel (home top)
├── ExploreTab (browse/search)
├── DiscoverySuggestionCard (inside group boards)
├── ErrorCard + FeedbackSheet
│
└── Engine — ChatEngineDiscovery mixin
    ├── TasteRanker (local, private)
    ├── DiscoveryCache (SQLCipher, TTL)
    └── FeedbackCollector (offline-first)
        │
        │ HTTPS (DiscoveryAdapter port)
        ▼
Web API (web/src/app/api/discovery/)
├── /feed, /explore, /carousel, /item/[id], /enrich
├── /feedback, /feedback/[id]
└── ProviderRegistry
    ├── SeededCatalogProvider (Supabase, priority 0)
    ├── GeminiEnrichmentProvider (priority 1)
    ├── ApifyScrapingProvider (priority 2)
    └── Future: GooglePlaces, Yelp, Booking.com
```

**Data flow:** Server sources raw content → Engine fetches + caches locally → Engine ranks using local taste profile → App renders personalized feed.

**Feedback flow:** Failure occurs → Engine emits error → App shows ErrorCard inline → User taps "Report" or tells @hello → Engine submits with auto-attached context.

---

## 2. Engine Module — ChatEngineDiscovery Mixin

### Public API

```dart
mixin ChatEngineDiscovery on ChatEngine {
  // Streams
  Stream<List<DiscoveryItem>> get discoveryFeed;
  Stream<List<CarouselCard>> get carouselItems;
  Stream<DiscoveryState> get discoveryState;   // loading | ready | error | offline

  // Explore
  Future<List<DiscoveryItem>> explore({
    String? query, DiscoveryCategory? category,
    String? location, int limit = 20, int offset = 0,
  });
  Future<DiscoveryItemDetail> getItemDetail(String itemId);

  // Group context
  Future<List<DiscoveryItem>> getSuggestionsForGroup(String groupId, {int limit = 3});

  // Actions
  Future<void> addToDecisionBoard(String groupId, DiscoveryItem item);
  Future<void> dismissItem(String itemId);
  Future<void> saveItem(String itemId);

  // Feedback
  Future<void> reportError(ErrorReport report);
  Future<void> submitFeedback(String message, {Map<String, dynamic>? context});
  Stream<List<ErrorReport>> get pendingReports;
}
```

### Models

```dart
enum DiscoveryCategory { restaurants, hotels, activities, destinations, dayPlans, experiences }
enum DiscoveryState { loading, ready, error, offline }

class DiscoveryItem {
  String id, title, subtitle?, category, imageUrl?, description?;
  double? price; String? currency, location;
  Map<String, dynamic> metadata;
  double tasteScore;          // 0.0-1.0, ranked locally
  String? tasteReason;        // "Matches your preference for seafood"
  String source;              // "gemini", "catalog", "google_places"
  DateTime fetchedAt;
}

class CarouselCard {
  String id, title, subtitle?, imageUrl?, heroColor;
  DiscoveryCategory category;
  List<DiscoveryItem> items;
  String curationType;        // "trending", "seasonal", "taste_match", "editorial"
}

class DiscoveryItemDetail extends DiscoveryItem {
  String? longDescription, website, phone, aiSummary;
  List<String> imageUrls, tags;
  Map<String, String>? hours;
  double? rating; int? reviewCount;
}

class ErrorReport {
  String id, errorType, errorMessage;
  Map<String, dynamic> context;
  String? userDescription;
  DateTime occurredAt;
  bool synced;
}
```

### TasteRanker (on-device)

Scores items 0.0-1.0 using local taste profile. Never sends taste data to server.

Scoring factors:
1. **Hard constraint filter** (pass/fail) — dietary, allergies → non-matching items excluded entirely
2. **Category affinity** (×0.35) — from reaction history implicit_weights
3. **Price affinity** (×0.25) — derived from reactions on priced items
4. **Tag affinity** (×0.25) — matched tags weighted by reaction count
5. **Diversity boost** (×0.10) — prevents monotonous feeds (5 Italian → boost non-Italian)
6. **Recency decay** (×0.05) — dismissed items penalized for 7 days

Group context: uses `intersectTasteProfiles()` (existing) — unions allergies, intersects dietary, averages weights.

### Taste Signal Updates

| Action | Weight |
|--------|--------|
| `addToDecisionBoard` | +3 |
| `saved` | +2 |
| `viewed` (detail opened) | +0.5 |
| `dismissed` | -2 |
| Scrolled past | 0 |

### DiscoveryCache (SQLCipher)

- 6-hour TTL (configurable)
- Offline-first: stale cache served when no network
- Same encrypted DB as messages
- Max cache: pruned on expired TTL

---

## 3. Server API + Provider System

### Endpoints

```
POST /api/discovery/feed         — personalized feed (categories, location, groupId?, limit, offset)
POST /api/discovery/explore      — search/browse (query, category, location, priceRange, limit)
GET  /api/discovery/carousel     — curated carousel cards
GET  /api/discovery/item/[id]    — item detail
POST /api/discovery/enrich       — Gemini AI summaries for item batch
POST /api/discovery/feedback     — submit error/bug report
GET  /api/discovery/feedback/[id]— report status
GET  /api/discovery/providers/health — provider status dashboard
```

### Provider Interface

```typescript
interface DiscoveryProvider {
  name: string;
  priority: number;
  supports: DiscoveryCategory[];
  search(params): Promise<RawDiscoveryItem[]>;
  getDetail(externalId: string): Promise<RawDiscoveryItemDetail | null>;
  healthCheck(): Promise<{ status: 'ok' | 'degraded' | 'down' }>;
}
```

### Built-in Providers

| Provider | Priority | Source | Categories |
|----------|----------|--------|------------|
| SeededCatalogProvider | 0 | Supabase `discovery_items` table | All |
| GeminiEnrichmentProvider | 1 | Gemini 2.5 Flash (existing 3-tier) | All, strongest for day_plans |
| ApifyScrapingProvider | 2 | Existing Apify integration | restaurants, hotels, activities |

Future providers (add without engine/app changes): GooglePlaces, TripAdvisor, Booking.com, Yelp.

### Provider Resolution

1. SeededCatalog returns instant results from DB
2. Gemini + Apify run in parallel
3. Results merged + deduplicated (title + location fuzzy match)
4. App shows catalog results first, enriches as more arrive

### Database Tables

```sql
discovery_items          — seeded catalog (title, category, location, metadata, source, rating)
discovery_feedback       — error/bug reports (user_id, type, context, status)
discovery_actions        — user actions for taste signals (user_id, item_id, action)
```

- RLS: `auth.jwt()->>'sub'` pattern
- Indexes on category, location, source, user_id

---

## 4. Flutter UI — Three Discovery Layers

### Layer 1: Discovery Carousel (Home Screen Top)

- Horizontal scroll, 80% viewport width per card
- Full-bleed image + gradient + title
- Tap → DiscoveryDetailSheet
- Swipe-to-dismiss → taste signal
- Auto-refreshes daily, cached offline
- Empty state: hidden entirely

### Layer 2: Explore Tab (Dedicated Screen)

- Search bar (debounced 300ms) + category chips
- Grid of DiscoveryItem cards, infinite scroll
- Pull-to-refresh
- Empty query → taste-ranked "For You" feed
- Category + location filters combinable

### Layer 3: In-Feed Suggestion Cards (Group Context)

- Appears inside group decision board
- "@hello suggests" label, styled distinctly
- 1-3 items relevant to group context
- "Add to board" → converts to DecisionItem
- Triggers: < 3 items in category, high-scoring matches, consensus stalling
- Max 1 suggestion card per group per session

### Feedback UI

- **ErrorCard**: inline, non-blocking, "Something went wrong · Report this · Retry"
- **FeedbackSheet**: bottom sheet, pre-filled context, optional description, offline-queued

### Widget Inventory (10 widgets)

| Widget | Type | Location |
|--------|------|----------|
| DiscoveryCarousel | Stateless | Home top |
| CarouselCardTile | Stateless | Inside carousel |
| ExploreTab | Stateful | Bottom nav |
| ExploreSearchBar | Stateful | Top of explore |
| CategoryChips | Stateless | Below search |
| DiscoveryItemCard | Stateless | Grid/list item |
| DiscoveryDetailSheet | Stateful | Bottom sheet |
| DiscoverySuggestionCard | Stateless | Inside group board |
| ErrorCard | Stateless | Inline at failure |
| FeedbackSheet | Stateful | Bottom sheet |

---

## 5. Taste Ranking Algorithm

### Scoring Formula

```
tasteScore = constraintPass
           × (categoryAffinity × 0.35)
           × (priceAffinity × 0.25)
           × (tagAffinity × 0.25)
           × (diversityBoost × 0.10)
           × (recencyDecay × 0.05)
```

- Hard constraints are binary pass/fail (allergies, dietary)
- Category affinity from `implicit_weights` (reaction history)
- Price affinity from reaction patterns on priced items
- Tag affinity from matched tags weighted by reaction count
- Diversity boost prevents monotonous feeds (1.0-1.2x)
- Recency decay penalizes dismissed (0.0 for 7 days) and recently viewed (0.8)

### Group Context

Uses existing `intersectTasteProfiles()`: union allergies, intersect dietary, average weights. Items scoring > 0.6 for ALL members get agreement bonus.

---

## 6. Error Capture + Feedback Pipeline

### Error Types

| Error Type | Trigger |
|-----------|---------|
| `message_failed` | Message send fails |
| `search_timeout` | Discovery search exceeds 15s |
| `payment_link_broken` | Xpensly payment link fails |
| `media_failed` | Upload/download fails |
| `ai_timeout` | @hello response exceeds 60s |
| `sync_failed` | Offline queue drain fails |
| `encryption_error` | Key exchange or decrypt fails |
| `discovery_empty` | Feed returns 0 results |
| `unknown` | Unhandled exception |

### Flow

1. Engine catches error → creates ErrorReport → stores in SQLCipher
2. Emits on `engine.errors` stream
3. App shows ErrorCard inline (user-facing errors only)
4. User taps "Report" → FeedbackSheet → `engine.reportError()`
5. Or user says "@hello something broke" → @hello collects context conversationally
6. Reports sync to server when online (retry every 5 min)

### @hello Integration

- "@hello something broke" triggers feedback intent (Tier 1 regex)
- @hello checks for recent ErrorReport (last 5 min)
- If found: references the error, asks for description
- If not: asks what happened
- Files report with auto-attached context

### Privacy Guards

**NEVER captured:** message content, taste profiles, encryption keys/state, group member lists.
**Captured:** error type, error code, screen, action, device info, truncated search query (50 chars), stack trace.

### Storage

- Local: 100 max reports, 30-day retention, FIFO eviction
- Server: `discovery_feedback` table, status lifecycle (received → triaging → resolved)

---

## 7. Testing Strategy

| Tier | Scope | Count | Runtime |
|------|-------|-------|---------|
| Engine unit (Dart) | Ranker, cache, models, error capture, taste signals | ~35 | < 3s |
| API integration (TS) | Provider registry, endpoints, feedback API | ~15 | < 10s |
| Widget (Flutter) | All 10 widgets | ~15 | < 5s |
| Scenario | Personalized feed, group discovery, offline, feedback flow, @hello feedback | ~8 | < 5s |
| **Total** | | **~73** | **< 25s** |

### Key Scenarios

- **Personalized feed**: vegetarian user → no meat, Italian ranked highest, dismiss 3 Italian → diversity boost
- **Group discovery**: 1 vegetarian + 1 nut allergy → exclude meat AND nuts, seafood ranked high
- **Offline**: cache populated online → feed renders offline → actions sync when reconnected
- **Feedback flow**: search timeout → ErrorCard → Report → verify no PII in report
- **@hello feedback**: trigger error → "@hello something broke" → references error → files report
