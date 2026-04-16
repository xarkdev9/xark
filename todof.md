# todof.md — Complete Roadmap from Steve/Elon Feedback

Cross-referenced against actual codebase state as of 2026-04-14.

---

## LEGEND

- HAVE = working code exists, feature is functional
- PARTIAL = code exists but incomplete, stubbed, or not wired end-to-end
- MISSING = no code, needs to be built from scratch

---

## 1. PRODUCT IDENTITY & POSITIONING

### 1a. Kill the jargon — stop calling it an OS
**Status: MISSING (non-tech action)**

Steve: "Drop the ego. It is not an OS. Stop using jargon that makes you feel smart."

What exists: The codebase uses "hello" consistently as the brand name (xark references were purged in the night shift). But documentation still references "Spatial OS", "social consensus infrastructure", "AI-native encrypted messenger."

What to do:
- Rewrite the App Store / Play Store listing copy. One line: "Hello: The decision layer for group chat."
- Rewrite the landing page at gethello.ai. Kill all architecture language. Speak to the human.
- Rewrite DESIGN.md product context section — remove "social operating system" framing
- Audit all user-facing strings in the app for jargon (search for "spatial", "consensus", "ledger", "sovereignty")

### 1b. Define the one-sentence pitch
**Status: MISSING (non-tech action)**

The feedback converges on: "Hello is the decision layer for group chat."

Not: "spatial OS for social consensus"
Not: "AI-native encrypted messenger"
Not: "social operating system for real-life coordination"

What to do:
- Lock this sentence. Put it in CLAUDE.md line 1.
- Every feature decision passes through: "does this make the decision layer better?"

### 1c. Stop overbuilding — four things only
**Status: PARTIAL**

The feedback says the winning v1 does exactly four things exceptionally well:
1. Collect options — HAVE (decision items, add_item_sheet concept from Gen 3, @hello AI suggestions)
2. Vote fast — HAVE (Love It / Works For Me / Not For Me reaction system, heart-sort ranking)
3. Lock decisions — HAVE (consensus engine at 80%, state flows, green-lock commitment)
4. Show live status — PARTIAL (settlement_page shows amounts, trip_page shows pending count, but there is no single "status dashboard" view that answers "what's booked, what's pending, who owns what")

What to do:
- Build a "Status View" — one screen that shows: locked items (booked), pending items (needs votes), assigned items (who's doing what), settlement summary (who owes whom)
- This is the "one place to know what is booked" that users actually want
- It could be the HOME tab content or a section within the Plans view

---

## 2. GO-TO-MARKET & GROWTH

### 2a. Web Voter View — zero-install voting link
**Status: MISSING**

Steve: "If an organizer says 'download this app,' three out of six friends will say 'no, just text me the Airbnb link.' Your entire viral loop dies right there."

What exists:
- Invite system generates 128-bit hex codes (web/src/app/api/invite/route.ts)
- PWA manifest exists with share target
- Service worker caches app shell
- But there is NO web page where a non-app-user can view options and vote

What to do:
- Build a web voting page at /vote/[code] or /v/[code]
- The page shows: trip name, list of options with photos, vote buttons (Love/Works/Pass)
- No account required. Voter identified by phone number or name entry
- Votes sync to the same decision items the app users see
- After voting, show a "Want to see the full trip? Get hello" prompt
- This is the single most important growth feature. It removes the #1 adoption blocker.

### 2b. Apple App Clip
**Status: MISSING**

No iOS App Clip target exists. No NSAppClip entry in Info.plist.

What to do:
- Create an App Clip target in Xcode
- The clip shows: trip name, decision items, vote buttons
- Triggered by: NFC tag, QR code, or iMessage link
- Size limit: 15MB (must strip engine, crypto, full app — just voting UI + network calls)
- This is iOS-specific but covers the highest-value demographic

### 2c. Android Instant App
**Status: MISSING**

No Instant App configuration in AndroidManifest.xml.

What to do:
- Configure instant app module
- Same scope as App Clip — voting-only surface
- Lower priority than web voter view (web covers both platforms)

### 2d. Onboarding for the "High-Coordination Node"
**Status: PARTIAL**

What exists:
- Auth flow (Firebase OTP → engine bootstrap) — HAVE
- Playground/demo data concept (seed_data.dart) — HAVE
- Taste onboarding in auth flow (collects free text) — HAVE

What's missing:
- No guided onboarding that shows the organizer "here's how to create a trip, invite friends, collect votes"
- No "Create your first trip" CTA after auth completes
- No template picker (weekend plan, trip, dinner, wedding)
- The old React code had space_templates.ts with 6 templates — not surfaced in Flutter UI

What to do:
- Post-auth, show a template picker: "What are you planning?" → Trip / Dinner / Weekend / Wedding / Party / Open
- Pre-populate a group with the selected template
- Show a share sheet immediately: "Invite your group" with link/QR/contacts
- The first 60 seconds must deliver the "10x reduction in pain" Steve demands

---

## 3. CORE PRODUCT FEATURES

### 3a. Collect options
**Status: PARTIAL**

What exists:
- Decision items model (DecisionItem in engine)
- @hello AI suggests items (web/src/app/api/hello/ orchestrator)
- Decision cards render in the feed (decision_card_small, decision_card_hero)
- Discovery detail sheet for viewing an item

What's missing:
- No "Add Item" button or sheet in the current Flutter app (Gen 3 had add_item_sheet.dart with engine.encryptPayload + addDecisionItem — that code is in the backup but NOT ported to Gen 4)
- No way for a user to manually add a hotel/restaurant/activity to the group
- @hello AI results are not surfaced in the Flutter app (the API works, the UI doesn't invoke it)

What to do:
- Port add_item_sheet.dart from Gen 3 backup
- Add a [+] button on the Plans tab or inside group_page.dart's plans view
- Wire to engine.addDecisionItem() for manual adds
- Wire to /api/hello for AI-powered search ("find hotels near Zurich under $200")

### 3b. Vote fast
**Status: HAVE (mostly)**

What exists:
- 3-reaction system: Love It (+5), Works For Me (+1), Not For Me (-3)
- Vote buttons in decision_card_small, decision_page, decision_sheet
- heart-sort.ts / algo ranking engine (232 tests passing)
- Voting calls HelloHaptic.tap()

What's incomplete:
- Votes are local setState in some widgets (decision_card_small) — they don't persist to the engine
- The decision_page.dart has vote buttons that should call engine.reactToItem() but currently only do local state

What to do:
- Wire all vote buttons to engine.reactToItem(itemId, signal) via a provider
- Optimistic update: update UI immediately, sync to server in background
- Show vote counts from real data (currently hardcoded agreementScore)

### 3c. Lock decisions
**Status: HAVE (backend)**

What exists:
- Consensus engine (algo/src/engine/consensus-engine.ts) — auto-lock at 80%
- Web consensus subscription (web/src/lib/consensus.ts) — real-time Postgres CDC
- State flows (BOOKING_FLOW: proposed→ranked→locked→claimed→purchased)
- Green lock commitment (algo/src/engine/green-lock.ts)
- Flutter consensus_banner.dart and liquid_fire_consensus_burst.dart exist

What's incomplete:
- The Flutter consensus UI (banner + burst animation) is not wired to real consensus events
- No real-time subscription from the Flutter app to consensus state changes
- The gold burst celebration concept exists but _triggerGoldBurst() is dead code in decision_card.dart

What to do:
- Wire consensus_banner.dart to engine consensus events
- Fire liquid_fire_consensus_burst.dart when a decision crosses 80%
- Show the locked state visually on cards (gold border, checkmark, "LOCKED" badge)
- Haptic: HelloHaptic.celebrate() on lock

### 3d. Show live status
**Status: PARTIAL**

What exists:
- Trip page shows: destination, dates, member count, pending decisions
- Settlement page shows: who owes whom, amounts
- Itinerary page shows: day-by-day schedule
- Home feed has priority-scored awareness cards

What's missing:
- No single "dashboard" or "status board" that answers all four user questions at once:
  1. What options exist? (items list)
  2. What's the vote status? (scores, who voted)
  3. What's booked? (locked items)
  4. Who owns what? (assigned tasks, settlement)

What to do:
- Build a PlansOverview widget (the Gen 3 _OverviewDashboard concept)
- Shows: settled count / total, top-voted items, who hasn't voted, settlement summary
- This is the "one place to know what is booked" — the core product promise

---

## 4. MONETIZATION

### 4a. Layer 1 — Booking affiliate links (not native checkout)
**Status: PARTIAL**

Elon: "Do not build native checkout. Use simple affiliate web-redirects for v1. Let Delta handle the credit card liability."

What exists:
- Flight client (web/src/lib/intelligence/fli-client.ts) — searches flights
- Hotel/activity search (searchapi-client.ts, apify-client.ts) — finds options
- Stripe checkout exists at web/src/app/api/xpensly/checkout/ — this is the native checkout Elon says to AVOID
- Deep link generation (web/src/lib/intelligence/deep-links.ts) — generates booking URLs

What to do:
- For v1: use deep-links.ts affiliate URLs to redirect users to Booking.com, Delta, Airbnb
- Do NOT build native Stripe checkout for travel bookings
- Earn affiliate commission from redirects (Booking.com pays 25-40% commission)
- The Stripe checkout in xpensly/ is fine for expense SETTLEMENT (splitting costs between friends) — that's different from booking checkout

### 4b. Layer 2 — Settlement ledger (keep but simplify)
**Status: HAVE**

Elon: "Moving money is a commodity. Terrible unit economics."

What exists:
- xpensly_core (30 source files, 69 tests) — full split calculator, settlement engine, debt simplifier, currency converter
- xpensly_ui (9 themed widgets, 16 tests) — Flutter settlement UI
- xpensly REST API (20 route handlers) — trip management + calculations
- Payment providers: Venmo, UPI, PayPal, Stripe, Razorpay adapters

What to do:
- Keep the split calculator — it's useful and differentiating
- Do NOT build custom payment processing. Generate Venmo/UPI deep links (already exists in web/src/lib/ledger.ts: generateVenmoLink, generateUPILink)
- Remove Stripe-based payment processing for v1 — let users pay each other directly via Venmo/UPI links
- The xpensly feature is a retention tool, not a revenue driver

### 4c. Layer 3 — @hello Concierge subscription (PRIMARY revenue)
**Status: HAVE (backend) / MISSING (monetization)**

Elon: "Selling a $10-$20/month SaaS subscription to the Organizer so they can use Gemini to instantly draft itineraries and hunt for reservations is pure software margin (90%+)."

What exists:
- Full AI orchestration pipeline (web/src/lib/intelligence/orchestrator.ts)
- 3-tier routing: gemini-local → gemini-search → apify
- Itinerary generation (itinerary-generator.ts)
- Taste intersection (taste-intersection.ts) — group dietary/budget constraints
- Tool registry (8 tools: restaurant, hotel, flight, activity, etc.)
- Rate limiting at /api/hello (10 requests/minute, fail-closed — already cost-protected)

What's missing:
- No subscription/paywall system
- No "free tier" vs "premium tier" distinction
- No Stripe subscription billing
- No usage tracking per user

What to do:
- Free tier: 5 @hello queries per trip (enough to try it)
- Premium ($9.99/month or $79.99/year): unlimited @hello, priority response, advanced itinerary generation
- Implement via RevenueCat (Flutter SDK) or Stripe billing
- Gate at the API level: check user subscription status before executing AI query
- This is the #1 revenue priority

---

## 5. UI / UX

### 5a. No-Bold Mandate — readability concern
**Status: HAVE (enforced, 0 violations)**

Steve: "If an exhausted dad can't read the flight terminal because you insisted on w300, you aren't a visionary designer, you're an arrogant one."

What exists:
- No-bold mandate fully enforced: zero FontWeight.w500+ violations
- 8-level type scale with w400 primary and w300 secondary
- Inter font bundled

What to do:
- Test readability on real devices in bright sunlight
- If body text at w400 / 17px is hard to read, consider bumping to 18px rather than adding weight
- The constraint is valid IF the size scale compensates. Monitor user testing feedback.

### 5b. Glass hierarchy — clarity concern
**Status: HAVE (3-tier system)**

Steve: "If your visual system becomes too ambient, too cinematic, too anti-structure, you will sabotage clarity."

What exists:
- Whisper (14), Veil (20), Curtain (24) — codified in HelloGlass
- All BackdropFilter values use named constants
- Dark mode adjusts glass fills automatically

What to do:
- User test the glass surfaces. Can users instantly distinguish "this is a button" from "this is background"?
- If glass surfaces feel too similar, increase the contrast between tiers (make Curtain more opaque)
- The plasma brand system already differentiates action surfaces — validate it works in practice

### 5c. Zero-Box Doctrine — scan speed concern
**Status: HAVE (enforced)**

Steve: "In a high-density coordination app, users need fast scanning, confidence, and obvious state."

What exists:
- No card borders on content cards
- Glass containers only for functional necessity (bubbles, modals, inputs)

What to do:
- When real data flows through the feed, test: can users scan 15 items and identify the urgent one in under 3 seconds?
- If not, consider adding subtle state indicators (color-coded left edge on cards, status icons)
- The empty state widgets now exist — but "loaded with 50 items" state needs density testing

---

## 6. ENGINEERING

### 6a. E2EE — fully implemented
**Status: HAVE**

What exists:
- Signal Protocol: X3DH, Double Ratchet, Sender Keys (engine/lib/src/crypto/)
- Streaming AEAD for media (64KB chunks, AES-256-GCM)
- PQXDH hybrid (X25519 + stubbed Kyber-1024)
- SQLCipher encrypted local DB
- 33 test files in engine/test/

What to do:
- Replace StubKyber with real Kyber-1024 (1568-byte public keys) when a Dart Kyber library matures
- Commission a security audit before public launch
- The E2EE is correctly positioned as infrastructure, not a user-facing selling point (per feedback: "Customers do not care")

### 6b. Contact discovery
**Status: MISSING**

What exists:
- engine/lib/src/contacts/ has a file but it's empty/commented TODO

What to do:
- Implement truncated SHA-256 phone hash lookup (first 10 bytes)
- Server maintains hash table of registered users
- Client hashes contacts locally, sends hashes, receives intersection
- Rate-limit discovery requests to prevent enumeration
- This is required for the "invite your friends" flow

### 6c. Push notification decryption
**Status: PARTIAL (stub)**

What exists:
- Firebase messaging service worker (web/public/firebase-messaging-sw.js) — stub decryptAndNotify()
- Engine notifications module (engine/lib/src/notifications/) — interface defined
- Push payload is E2EE-safe: only encryptedPayload + recipientDeviceId

What's missing:
- iOS Notification Service Extension (Swift) — not built
- Android FirebaseMessagingService (Kotlin) — not built
- Web SW decryption — TODO stubs, shows "You may have new messages"

What to do:
- Build iOS NSE: decrypt payload from shared Keychain, show sender name + preview
- Build Android service: decrypt in background worker, post local notification
- Complete web SW: access IndexedDB keystore, decrypt, show real content
- Until this is done, push notifications show generic "New message" — functional but poor UX

### 6d. Profile key encryption
**Status: MISSING**

What exists:
- CLAUDE.md documents the Profile Key concept (random 32-byte symmetric key, shared with contacts)
- engine/lib/src/crypto/ has no profile/ subdirectory

What to do:
- Implement ProfileKeyManager in engine crypto layer
- Encrypt display_name, photo_url, status with profile key before upload
- Distribute profile key to contacts via E2EE message
- Rotate on contact removal
- Lower priority — cosmetic metadata protection, not message security

### 6e. Multi-device (Sesame protocol)
**Status: PARTIAL (interfaces only)**

What exists:
- DeviceRegistry and DeviceLinking abstract interfaces (engine/lib/src/devices/)
- Web crypto device-registry.ts (TypeScript interface)
- Device linking page with real camera scanner (app/lib/views/settings/device_linking_page.dart)
- 5-device limit trigger defined

What's missing:
- No concrete Supabase-backed device registry implementation
- No QR-based key transfer protocol
- No sender key rotation on device unlink

What to do:
- Implement DeviceRegistryImpl backed by Supabase user_devices table
- Build QR linking flow: primary device generates QR with encrypted session transfer
- On device unlink: rotate all sender keys, notify group members
- This blocks multi-device usage (phone + laptop) — important for retention

### 6f. Offline-first / Outbox
**Status: HAVE (implemented)**

What exists:
- OutboxProcessor with exponential backoff (engine/lib/src/sync/)
- OutboxWorker with ratchet-order serial drain
- Web outbox (web/src/lib/crypto/outbox.ts) with IndexedDB queue
- WatermarkSync for gap detection

What to note:
- OutboxWorker and WatermarkSync are passed null in ChatEngineImpl.initialize() — the legacy OutboxProcessor runs instead
- To activate the production-grade sync: wire OutboxWorker and WatermarkSync in initialize()

### 6g. Performance on web
**Status: HAVE (measured)**

What exists:
- Performance overlay toggle in main.dart
- HelloGlass cap at sigma 24 (below 30 crash ceiling)
- Lazy animation (2-4 tickers instead of 60)
- flutter build web succeeds

What to do:
- Profile on real low-end Android devices (not just web)
- Monitor BackdropFilter frame budget during scroll
- Consider reducing card glass from veilSigma (20) to whisperSigma (14) if scroll jank appears

---

## 7. LEGAL & COMPLIANCE

### 7a. Privacy policy
**Status: MISSING**

Required for App Store / Play Store submission. Must cover:
- E2EE data handling (server never sees plaintext)
- Phone number collection (for auth + contact discovery)
- AI data usage (@hello reads last 15 messages on invocation only — no passive listening)
- Push notification data
- Third-party services: Firebase, Supabase, Gemini, Apify, SearchAPI

### 7b. Terms of service
**Status: MISSING**

Standard ToS for a consumer messaging app. Must cover:
- Acceptable use
- Content moderation (E2EE means server can't moderate — how is abuse handled?)
- Account termination
- Data deletion rights (GDPR Article 17)

### 7c. GDPR / Data protection
**Status: PARTIAL**

What exists:
- tombstone_message RPC for GDPR deletion with partition-pruned ciphertext removal
- E2EE means server stores only ciphertext — limited personal data exposure

What's missing:
- No data export feature (GDPR Article 20 — right to portability)
- No account deletion flow in the app UI
- No cookie consent for the web app
- No DPA (Data Processing Agreement) with Supabase / Firebase / Gemini

### 7d. App Store / Play Store readiness
**Status: MISSING**

What's needed:
- Privacy policy URL (required for submission)
- App screenshots (5+ per device class)
- App description and keywords
- Age rating questionnaire
- Content rating (messaging app = 12+ or 17+ depending on content moderation approach)
- Review guidelines compliance (no placeholder "Coming in v1.1" features visible to reviewers)

---

## 8. MARKETING & LAUNCH

### 8a. Landing page
**Status: HAVE (gethello.ai exists on Vercel)**

What to do:
- Rewrite copy: "Hello: The decision layer for group chat"
- Show the four-thing promise: collect, vote, lock, status
- Demo video showing a real trip being planned (not architecture diagrams)
- Waitlist signup or TestFlight link

### 8b. Demo / Playground mode
**Status: PARTIAL**

What exists:
- seed_data.dart has mock conversations, trips, decisions
- Web playground.ts has 4 demo spaces with 17 hotel items
- Space templates exist (web/src/lib/space-templates.ts) — 6 templates

What's missing:
- No guided demo flow in the Flutter app
- No "Try without signing up" path
- The old React usePlaygroundChoreography hook (guided demo sequencing) was not ported

What to do:
- Build a "Try Hello" button on the landing page that opens the web voter view with demo data
- In the app: offer a "Skip sign-up, explore a demo trip" option on the auth screen
- Pre-populate with a realistic demo trip (Swiss Alps, 6 friends, 12 decision items at various vote states)

### 8c. TestFlight / Beta distribution
**Status: MISSING**

What to do:
- Set up TestFlight for iOS
- Set up Firebase App Distribution or Google Play internal testing for Android
- Recruit 20-50 beta testers from real friend groups planning real trips
- Collect feedback on: does the voting actually reduce planning chaos?

### 8d. Social proof / Content
**Status: MISSING**

What to do:
- Create before/after content: "This is your WhatsApp group chat with 400 messages about where to eat. This is the same decision in Hello: 3 options, 6 votes, done."
- Short-form video for TikTok/Instagram: screen recording of a real trip being planned
- No paid ads initially — the product demo IS the marketing

---

## 9. INFRASTRUCTURE & OPS

### 9a. Error monitoring
**Status: MISSING**

What exists:
- error_card.dart and feedback_sheet.dart for user-facing errors
- Engine error taxonomy (ChatEngineError sealed class)

What's missing:
- No Sentry / Crashlytics / error reporting service
- No server-side error monitoring for the 53 API routes
- feedback_sheet.dart submits nothing (fake delay, feedback discarded)

What to do:
- Add Sentry (Flutter + web)
- Wire feedback_sheet.dart to actually submit reports (POST to /api/feedback or Sentry user feedback)
- Add Vercel analytics or PostHog for product analytics

### 9b. Analytics
**Status: MISSING**

What to do:
- Track: trips created, decisions added, votes cast, consensus reached, messages sent
- Track: time from "group created" to "first decision locked"
- Track: invite conversion rate (link sent → app opened → vote cast)
- Use PostHog, Amplitude, or Mixpanel
- Privacy-safe: no plaintext content in analytics, only event counts

### 9c. CI/CD
**Status: PARTIAL**

What exists:
- Vercel deployment for web (project linked)
- GitHub repo at xarkdev9/xark (remote: new-origin)
- flutter build web works

What's missing:
- No GitHub Actions for Flutter tests / analysis
- No automated iOS/Android build pipeline
- No pre-merge checks

What to do:
- GitHub Actions: dart analyze + flutter test on every PR
- Fastlane for iOS (TestFlight uploads)
- Fastlane or Gradle for Android (Play Store internal track)

---

## 10. PRIORITY ORDER

Based on the feedback, here is the order that maximizes impact:

### Phase 1: Make it work (2 weeks)
1. Wire all vote buttons to engine.reactToItem() (not just local state)
2. Build the "Add Item" sheet (port from Gen 3)
3. Wire consensus celebration (banner + burst + haptic on 80% lock)
4. Build the Status Overview widget ("what's booked, what's pending")

### Phase 2: Make it shareable (2 weeks)
5. Build the Web Voter View (/v/[code] — zero install voting)
6. Build the post-auth onboarding flow (template picker → create group → invite)
7. Wire contact discovery (hashed phone lookup)
8. Fix push notifications (at minimum: show "Message from [name]" instead of generic)

### Phase 3: Make it sustainable (2 weeks)
9. Build @hello premium subscription (RevenueCat + API gating)
10. Implement booking affiliate deep links (not native checkout)
11. Set up error monitoring (Sentry) and analytics (PostHog)
12. Privacy policy + Terms of Service

### Phase 4: Make it launchable (2 weeks)
13. TestFlight + Firebase App Distribution beta
14. App Store / Play Store listing preparation
15. Landing page rewrite
16. Demo / playground mode for new users
17. Security audit of E2EE layer

### Later (post-launch)
18. iOS App Clip for voting
19. Profile key encryption
20. Multi-device Sesame protocol (full implementation)
21. Real Kyber-1024 KEM (replace StubKyber)
22. Native push decryption (iOS NSE, Android service)
23. Data export (GDPR portability)
