# 9PM Goal — Deep Code Review & Status Report

Last updated: 2026-04-13

---

## THE VERDICT

The UI is a polished visual prototype. It is not functional software. Every screen renders. Nothing works. The visual craftsmanship is high — plasma gradients, spring animations, glassmorphic sheets, smart corner radii on chat bubbles. But underneath: mock data baked into widget bodies, onSend callbacks that show toasts, a search bar that doesn't accept input, vote buttons that forget on scroll, and a BottomBar that's commented out entirely. This is a demo reel, not an app.

---

## FOUR GENERATIONS OF UI

Gen 1 — hello_archive/xark9_original/. Next.js + React + Capacitor. Retired. 60 source files. Dark theme. "Xark OS" branding. Had working E2EE chat, decisions, AI, auth.

Gen 2 — hello_archive/chatF_original/. Flutter. Retired. 21 files. Engine integration shell. First Flutter port.

Gen 3 — ui_backup_2026-04-10/flutter/. Flutter. Retired. ~65 files. Full-featured. Real engine wiring. demov2 system. Discovery, settings, AI spotlight, invites.

Gen 4 — app/lib/views/home/decision_board/. Flutter. Current. ~40 files. Visual rework with plasma/glass. All mock data. Nothing wired.

The current web app at web/src/ has a production-grade backend (53 API routes, 27 crypto modules, full AI pipeline) but zero frontend — no pages, no components, no hooks. The old React components that powered it were removed and never replaced.

---

## CHAT READINESS

Can a user start a new 1:1 chat today? No. On Flutter, the "New Chat" button closes the sheet and does nothing. On web, there is no UI at all.

Can a user send a message in an existing chat? No. On Flutter, the send button shows a toast. On web, there is no chat page.

Is the engine capable of sending E2EE messages? Yes — the encrypt/send/persist pipeline for text is genuinely implemented. But no UI layer calls it.

Is the PWA ready for iOS and Android? No. The manifest points to /login which doesn't exist. The service worker caches /galaxy which doesn't exist. There are zero page components.

---

## ENGINE LAYER STATUS

ChatEngineImpl.initialize() — IMPLEMENTED. Full wiring: Supabase, SQLCipher DB, crypto, sync, push.

X3DH key agreement — IMPLEMENTED. 3-DH fallback on OTK exhaustion works.

Double Ratchet encrypt/decrypt — IMPLEMENTED. XChaCha20-Poly1305, 1000-key skip dict, header encryption.

Sender Keys (group) — IMPLEMENTED. Ed25519 signing, ACK-based distribution.

SendMessageUseCase (text) — IMPLEMENTED. Two-phase ratchet commit, multi-device fan-out, X3DH bootstrap.

SupabaseClientWrapper — IMPLEMENTED. Key bundles, OTK, message POST, history fetch.

RealtimeListener — IMPLEMENTED. Postgres CDC + Broadcast subscriptions.

Message persistence (Drift) — IMPLEMENTED. Full CRUD, live watch queries, search.

connectionState stream — BUG. Not auto-wired from Realtime — only updates on manual resume().

errors stream — DEAD. _errorController is never .add()-ed anywhere.

Typing indicators — STUBBED. publishTyping() has empty body; receive stream never populated.

Presence — STUBBED. publishPresence() has empty body.

RealtimeReceipts — STUBBED. Abstract interface only — zero concrete implementation.

OutboxWorker / WatermarkSync — DEAD CODE. Passed null in initialize() — never instantiated.

sendMedia() — STUBBED. Sends raw text [media:filename], no AES encrypt/upload.

react() — STUBBED. Sends raw text [$emoji:$messageId] through ratchet.

getKeyFingerprint() — STUBBED. Returns 30-byte zero array.

Web persistence — HARD CRASH. database_factory_stub.dart throws UnsupportedError.

---

## FLUTTER APP STATUS (23 modified files reviewed line-by-line)

### Critical Bugs (will break in production)

main.dart:190 — authToken: 'offline_token' with no kReleaseMode guard. Ships hardcoded credentials to production. No assert, no flag check.

main.dart:55 — deviceId: 99 hardcoded. Two devices both register as device 99, corrupting the multi-device table and hitting the 5-device limit trigger.

main.dart:189-191 — Engine init failure silently swallowed (catch (_) {}). User navigates to a broken home screen with no error indication. Every provider throws UnimplementedError.

main.dart:129 — engine.dispose() on AppLifecycleState.detached without nulling the reference. If iOS keeps the process alive, future engine.resume() calls hit a disposed engine.

chat_bubble.dart:218-234 — Conditional Positioned inside Stack with gesture recognizer — exactly CLAUDE.md landmine #9. Shifts child indices during swipe, causing unnecessary RenderObject remounts every time _dragOffset crosses -10.

feed_item.dart:45 — DecisionSmallFeedItem.id uses item.hashCode where item is nullable. All null-item decisions get the same ID (decs_2011786707), colliding in cardKeyRegistry.

search_sheet.dart:27-28 — Triple bare _ wildcard parameters — Dart 3.7+ syntax. May fail to compile on older stable Flutter/Dart versions.

_card_shell.dart:104-115 — All AnimationControllers run unconditionally on every card. _ringController.repeat() and _unreadController.repeat() fire in initState for ALL cards, not just focused/unread ones. 20+ cards = 40+ unnecessary tickers per frame.

chat_bubble.dart:140-151 — _buildCornerRadii() has isLastInGroup ? inner : inner — both branches return the same value. The conditional is a no-op copy-paste bug. Solo messages get wrong corner radii.

focus_hero_card.dart:59-70 — Image.network('') on empty photoUrl crashes at Uri.parse before errorBuilder can catch it. No empty-string guard.

### No-Bold Mandate Violations (w400 max, weights 500-900 forbidden)

13 violations across 4 files.

decision_card_hero.dart:95 — w800, live tag.
decision_card_hero.dart:107 — w600, card title.
focus_hero_card.dart:101 — w800, "YOUR FOCUS" eyebrow.
focus_hero_card.dart:124 — w700, destination title.
focus_hero_card.dart:148 — w800, days countdown.
focus_hero_card.dart:158 — w800, members count.
focus_hero_card.dart:172 — w800, pending count.
settlement_card.dart:158 — w800, "PAY" button.
home_page.dart:389 — w700, selected avatar label.
home_page.dart:388 — w500, unselected avatar label.
chat_bubble.dart:195-200 — w500, time header.
liquid_intent_handle.dart:262 — w800, "HOME" label (cross-file).

focus_hero_card.dart alone has 5 violations and is the worst offender.

### Design Rule Violations

Zero-Box (no borders on content cards) — _card_shell.dart:222-226 has a 0.5px white border on every card via DecoratedBox.

Brand color restraint (plasma on ~28 action surfaces only) — _card_shell.dart:260-280 ambient pulse uses hardcoded 0xFFFF385C (not plasma system).

Brand color restraint — decision_card_hero.dart:151-163 CTA button uses flat HelloColors.accent instead of PlasmaFill.

Brand color restraint — group_card.dart:80-101 PlasmaTint on informational "ACTIVE" eyebrow label (passive surface).

Plasma system — settlement_card.dart:131 shadow uses 0xFFFF5A00, undocumented color outside HelloColors.

Plasma system — decision_sheet.dart:405 uses 0xFFFFB380 hardcoded in constellation hero, not in HelloColors.

### Dead Code

bottom_bar.dart (291 lines) — Entire file is dead. Commented out at decision_board_page.dart:102-109. The glass pill bar, tab chip, search field, mic/send button, compose button — none of it renders.

new_chat_sheet.dart — Only reachable from BottomBar, which is commented out. Even if it weren't dead, all three onTap handlers are Navigator.pop() — they close the sheet and do nothing.

decision_board_page.dart:70-73 — _switchToTab, only caller was BottomBar.

decision_board_page.dart:21-22 — new_chat_sheet.dart and search_sheet.dart imports never called.

decision_board_page.dart:33 — AutomaticKeepAliveClientMixin on root scaffold, meaningless at this tree level.

main.dart:8 — AuthFlowPage import never referenced (route maps to _ResumeSession instead).

floating_avatar.dart:17-19 — onTap: () {} empty handler, dead tap target.

floating_avatar.dart:21 — Hardcoded 'Ram', every user sees Ram's avatar.

group_card.dart:36-38 — initial variable computed and never used.

home_page.dart:1-3 — import 'package:rive/rive.dart' but Rive not used (CLAUDE.md says Rive replaced by ShaderMask).

home_page.dart:252-278 — _generateGemstoneColors returns 3 colors but only .first consumed.

dm_sheet.dart:220-221 — _isScrolledTop/_isScrolledBottom setState fires on every scroll frame but UI never reads them.

group_sheet.dart:237-238 — Same ghost scroll state, identical dead code in the copy.

### Performance Hazards

decision_board_page.dart:64-68 — 60fps provider writes. tabAnimationProvider updated every animation frame during swipe. All watchers rebuild at 60fps.

_card_shell.dart:104-115 — All 3 AnimationControllers run on every card always. Ring, unread, tap controllers all .repeat() in initState regardless of state. 20 cards = 60 tickers.

_card_shell.dart:204 — BackdropFilter(sigma: 30) at the WebGL crash ceiling. CLAUDE.md landmine #8. Inside TabBarView transition. Multiple cards applying 30px blur simultaneously during scroll.

home_page.dart:175-188 — Another BackdropFilter(sigma: 30) inside a tab transition view. Same WebGL OOM risk.

bottom_bar.dart:95-96 — ClipPath + BackdropFilter double compositing. Redundant clipping layer doubles rasterization cost (dead code currently, but if restored).

chat_bubble.dart:174-180 — LayoutBuilder on every bubble. Hundreds of layout passes per frame in a message list.

decision_card_small.dart:127-146 — 4 nested plasma widgets per active vote button. 12 PlasmaClockScope listener rebuilds per animation frame for 3 buttons.

dm_sheet.dart:220-221 and group_sheet.dart:237-238 — setState on every scroll frame for nothing. Ghost scroll tracking rebuilds entire sheet with no visual effect.

decision_board_page.dart:97 — MediaQuery.of(context) instead of MediaQuery.paddingOf(context). Subscribes to full MediaQueryData, rebuilds on keyboard/text-scale changes.

### Accessibility: Zero

Not a single Semantics widget exists in any of the 23 files. Every card, button, bubble, sheet, input, avatar, vote button, unread badge, and navigation element is invisible to screen readers. No tooltip, no semanticLabel, no excludeSemantics. VoiceOver/TalkBack users cannot use this app at all.

Hit targets below 44pt minimum: FloatingAvatar (36px), _CircleButton in BottomBar (36px), _VoteButton in decision_card_small (30x26px), unread dot in search_sheet (6px).

SnackBar text invisible: _card_factory.dart:30 — white text on #F0F0F0 background (1.3:1 contrast).

### Massive Duplication

_displayName() (ID to title-case) — 5 copies across dm_card, group_card, conversation_list_row, dm_sheet, group_sheet, search_sheet.

_MockMessage class — 3 copies across dm_sheet, dm_page, group_sheet (as _GroupMessage).

_SheetShell (glass scroll shell) — 2 copies, dm_sheet (177 lines) and group_sheet (177 lines), 89% verbatim identical.

Image.network + placeholder logic — 2 copies in decision_card_hero and focus_hero_card.

Avatar lookup system — 3 separate systems: home_page::_getAvatarImage, avatar_utils::getAvatarImagePath, chat_bubble::_senderNames.

Timestamp formatting — 3 copies in dm_card::_timestamp, conversation_list_row::_timestampText, and implicit in home_page.

Hardcoded Bali trip mock thread — 2 identical copies in dm_sheet and dm_page.

### Mock Data: Structural, Not Flag-Gated

The kUseMockData flag in mock_data.dart gates the providers. But the pages themselves have mock data baked into their widget bodies.

home_page.dart — 15 ZenithMock objects as a State field. No provider, no kUseMockData check.

dm_page.dart — _MockMessage list inline in build().

group_page.dart — _GroupMessage list inline in build().

dm_sheet.dart — _MockMessage list inline in build().

group_sheet.dart — _GroupMessage list inline in build().

chat_bubble.dart:65-80 — _senderNames hardcoded static map.

floating_avatar.dart:21 — getAvatarImagePath('Ram') hardcoded.

decision_sheet.dart:404 — 'HOTEL VOTE LIVE' hardcoded label.

Flipping kUseMockData = false will NOT make these pages show real data. Each page needs individual rewiring to watch engine streams.

### Keyboard Handling: Broken on All Sheets

All four sheets (dm_sheet, group_sheet, decision_sheet, search_sheet) use fixed heights (height = MediaQuery.of(context).size.height * N). None read MediaQuery.viewInsets.bottom. None use resizeToAvoidBottomInset. When the software keyboard appears, the keyboard covers the input bar on every phone-sized device.

### Three Disconnected Tab-Switching Systems

TabController drives TabBarView (working).

activeTabIndexProvider drives TabHeader + AmbientMesh (working).

LiquidIntentLayer._ActiveContent renders a static "HOME" chip with w800 font (no tab switching, violates no-bold).

BottomBar was the glue. It's commented out. Nothing connects the user to tab switching except the raw swipe gesture on TabBarView.

### HomePage Is an Island

It's the only tab page that is not a ConsumerWidget. It doesn't use Riverpod, doesn't check kUseMockData, doesn't use AutomaticKeepAliveClientMixin (violating CLAUDE.md's "all 4 pages" contract). Its 15 mock entries are a State field. It will need a complete rewrite to show real data.

### Voting Is Decorative

Both decision_card_small.dart and decision_sheet.dart have vote buttons that update local setState only. No engine call, no provider update, no persistence. The vote is lost on scroll (card dispose) or sheet dismiss. The progress bar and agreement score do not update when you vote — they still show the original mock value.

### Two Paths to the Same Conversation

openDmSheet() (bottom sheet via showGeneralDialog) and openDmPage() (full-screen CupertinoPageRoute) both exist. Both show the same mock data. Which one fires depends on where you tap from. Same for groups. No architectural decision documented.

### Search Sheet Doesn't Search

search_sheet.dart:160-189 — The search field is not a text field. It is a Container with static text. No TextField, no TextEditingController, no FocusNode. The search bar is a visual decoration that accepts no input. The list below always shows all conversations.

---

## WEB PWA STATUS

### What Exists and Works

PWA manifest — READY. Standalone, portrait, icons, share target.

iOS Safari meta tags — READY. apple-web-app-capable, splash screens, safe area.

Service worker (app shell) — READY. Network-first + cache fallback, share target intercept.

Chat API routes — READY. /api/message, /api/chat/start, /api/keys/* all implemented.

Rate limiting (proxy.ts) — READY. Token bucket on /api/message, sliding window on all others.

Realtime library — READY. messages.ts, typing-indicators.ts, realtime-receipts.ts complete.

Crypto library — READY. Full Signal Protocol in TypeScript, IndexedDB keystore, Argon2id.

Intelligence pipeline — READY. 3-tier AI routing (gemini-local, gemini-search, apify), 18 modules.

Domain logic — READY. heart-sort, consensus, claims, grounding, state-flows, ledger all functional.

53 API routes — ALL FUNCTIONAL. 33 non-xpensly + 20 xpensly. All with proper auth, validation, error handling.

### What's Missing

The entire frontend. Zero page components for any route. No /login, /home, /chat, /dm, /space. The manifest start_url: "/login" would 404.

No components directory. All 44 components listed in web/CLAUDE.md (HelloChat, DecisionBoard, AwarenessStream, PeopleDock, etc.) are documented but absent from the codebase. They were deleted and never replaced.

No hooks directory. All 11 hooks listed (useAuth, useE2EE, useHelloAI, etc.) are documented but absent.

Service worker caches /galaxy which doesn't exist (old route name).

Push decrypt is stub — decryptAndNotify() always shows "You may have new messages".

The app is a backend/API layer looking for a frontend.

---

## OLD REACT UI — WHAT IT COULD DO (Gen 1, fully functional)

44 components, 11 hooks, 18 pages. This was a fully functional app.

HelloChat.tsx (~350 lines) — Full E2EE chat: reverse-scroll, load-more, typing indicator, encrypted media inline, @hello AI messages with liquid-fire gradient, system messages. Wired to subscribeToMessages() + fetchMessages().

ChatInput.tsx (~280 lines) — Smart input: @hello detection morphs UI (glow, icon change), voice input via Web Speech API, multi-line expand, attachment picker, send with vibration.

DecisionBoard.tsx (~400 lines) — Category swim lanes, sorted items per lane, lock/claim actions, progress bars, consensus banners. Fully wired to Supabase realtime.

DecisionCard.tsx (~350 lines) — Photo card with animated rolling score counter, 3-reaction bar (Love/Works/Pass), spring physics on tap, booking URL bridge, lock celebration.

GalaxyLayout.tsx (~300 lines) — Home screen: stream mode (awareness feed) + split mode (2-column chat+decide). Tab animation. Group list with unread badges.

PeopleDock.tsx (~200 lines) — Horizontal avatar strip with awareness state (active/idle/away). Presence subscription via Supabase Broadcast.

AwarenessStream.tsx (~250 lines) — Priority-sorted feed cards: who needs flights, who hasn't voted, what's converging. Wired to fetchAwareness().

HelloPanel.tsx (~300 lines) — AI assistant panel: streaming responses, slot-based suggestions, inline decision item creation from AI results.

WelcomeScreen.tsx (~150 lines) — Animated brand splash with liquid-fire text. Tap to begin flow.

ConsensusBanner.tsx (~180 lines) — Celebratory banner on 80%+ agreement: confetti, gold glow, "Group agrees!" copy.

ConsensusTimer.tsx (~120 lines) — Countdown to lock expiration. Animated progress ring.

InlinePoll.tsx (~160 lines) — Live poll widget embedded in chat: animated fill bars, vote counts.

EncryptedMedia.tsx (~200 lines) — Decrypts AES-GCM images client-side, blur placeholder during decrypt, progressive reveal.

MemoriesView.tsx (~180 lines) — Cross-group photo gallery from encrypted media messages.

ItineraryView.tsx (~200 lines) — Day-by-day itinerary display with flight/hotel/activity blocks.

SpacePicker.tsx (~130 lines) — Multi-group dropdown for adding items to different groups.

LinkPreviewCard.tsx (~120 lines) — OG metadata card: image, title, domain, inline in chat.

LedgerPill.tsx (~100 lines) — Settlement summary pill: "You owe $120" / "Sarah owes you $80".

GlobalMesh.tsx (~80 lines) — Ambient animated background gradient (predecessor of AmbientMesh).

Avatar.tsx (~60 lines) — Avatar with online/offline indicator dot.

ThemeProvider.tsx (~40 lines) — React context for theme tokens.

React Hooks: useAuth (full Firebase + Supabase JWT), useE2EE (key gen, session establishment, encrypt/decrypt), useHelloAI (@hello invocation, streaming), useHandshake (consensus subscription, auto-lock), useReactions (add/remove, optimistic update), useVoiceInput (Web Speech API), useKeyboard (software keyboard tracking), useDisplayName (ID to name resolution), useDeviceTier (performance tier detection), usePlaygroundChoreography (demo sequencing), useWhispers (@hello proactive suggestions).

React Pages: /login (673 lines, full phone OTP with 4 phases), /galaxy (home with stream/split modes), /space/[id] (group view with chat + decisions), /share (PWA share target), /j/[token] (invite join), /s/[code] (invite share), /demo (playground onboarding).

---

## OLD FLUTTER UI — WHAT IT COULD DO (Gen 3, the most feature-complete)

~65 files across demov2/, views/, widgets/, providers/. This was the most feature-complete Flutter version.

### Engine-Wired Features (worked with real data)

chat_feed.dart (253 lines) — E2EE message list. Reverse ListView, .select() per-item rebuilds, same-sender grouping, read receipt promotion, load-more pagination. Wired to engine.getSession().messages.

chat_input.dart (286 lines) — LiquidChatComposer: @hello detection morphs UI, breathing orb icon, multi-line, haptic send. Wired to engine.sendText().

decision_board.dart (123 lines) — Fetches DecisionItems, decrypts payloads, groups by category, sorts by score, renders swim lanes. Wired to engine.getDecisionItems() + engine.decryptPayload().

plans_view.dart (838 lines) — 3-tier view: Event rail, category rail, content hero. Overview dashboard with facepile, hot badge, social copy. Recommendations paged view. Per-category card streams.

action_card_widget.dart (424 lines) — Photo card, 3 vote buttons with dual-spring physics, local score + server sync. Gold burst at 80%. Calls engine.reactToItem().

add_item_sheet.dart (193 lines) — Title + category + photo. Calls engine.encryptPayload() + engine.addDecisionItem().

space_layout.dart (314 lines) — 2-page PageView (Chat/Plans), glass header, parallax swipe, [+] add button on Plans.

auth_flow_page.dart (489 lines) — Firebase OTP: phone, invisible OTP field, verify, engine bootstrap. Fully functional.

home_layout.dart (280 lines) — 3-tab (Chats/Groups/Memories) with parallax header. New chat via engine.findOrCreateChat().

chats_tab_view.dart (157 lines) — engine.conversations stream, filtered by type, tap to SpaceLayout.

memories_tab_view.dart (86 lines) — Cross-group media grid from encrypted images.

conversation_controller.dart (23 lines) — 4 real StreamProvider.family: messages, presence, typing, receipts — all from engine sessions.

### Features That Existed as Mock/Demo (no equivalent in new app)

spotlight_sheet.dart (148 lines) — Full-screen AI surface with blur + streaming text reveal + GhostInput.

time_scrubber.dart (355 lines) — 2D temporal memory browser: year scrubber + horizontal event cards. Unique navigation concept.

explore_tab.dart (242 lines) — Category chips, 2-column grid, shimmer loading, pull-to-refresh.

discovery_detail_sheet.dart (504 lines) — Image gallery, AI summary, "Add to group" button with multi-group dropdown.

discovery_suggestion_card.dart (210 lines) — In-feed "@hello suggests" card.

feedback_sheet.dart (295 lines) — 3-state error reporting (editing/submitted/offline).

settings_page.dart (126 lines) — Blurred avatar header, typographic menu.

profile_edit.dart (147 lines) — Name + avatar editor.

device_list.dart (141 lines) — Swipe-to-revoke linked devices.

device_linking_page.dart (191 lines) — QR viewfinder with CustomClipper even-odd mask for Sesame protocol.

invite_surface.dart (179 lines) — Mock QR code with pulsing animation.

claim_sheet.dart (203 lines) — Long-press-to-join with spring physics.

gold_burst.dart (102 lines) — Consensus celebration: breathing gold border glow + haptic on 80%.

swim_lane_rail.dart (149 lines) — Category-sorted horizontal card rails with vital labels.

spring_curves.dart (55 lines) — Parameterized spring curve library (bouncy/snappy/gentle/heavy).

keyboard_aware_input.dart (48 lines) — Zero-lag keyboard tracking via platformDispatcher.

---

## WHAT THE NEW APP IS MISSING

### Tier 1: Features that WORKED in Gen 3 and are now BROKEN or ABSENT

1. Auth flow (Firebase OTP to engine) — Old: working (489 lines). New: 63-line stub, no Firebase, no OTP, no engine bootstrap. Can't authenticate.

2. Real chat send/receive — Old: working via engine.getSession().messages + sendText(). New: onSend shows a SnackBar toast. Can't chat.

3. Decision decryption — Old: working via engine.decryptPayload(). New: mock data only. Can't see real decisions.

4. Decision voting to engine — Old: working via engine.reactToItem(). New: local setState only, lost on dispose. Can't vote.

5. Add decision item — Old: working via engine.encryptPayload() + addDecisionItem(). New: no equivalent. Can't add decisions.

6. Conversation providers — Old: 4 StreamProvider.family wired to engine. New: kUseMockData = true blocks all. No real data.

7. New chat creation — Old: engine.findOrCreateChat(peerId) in home_layout. New: New Chat sheet onTap is Navigator.pop() (no-op). Can't start conversations.

8. Read receipt tracking — Old: working via receiptsProvider. New: no receipt provider or display. No delivery status.

9. Typing indicators — Old: working via typingProvider. New: engine stubs empty, no UI consumer. No typing display.

10. Presence — Old: working via presenceProvider. New: engine stubs empty, no UI consumer. No online/offline.

### Tier 2: Features that EXISTED in Gen 3 (mock/demo) with no equivalent in Gen 4

11. Discovery/Explore tab — Old: 9 files, ~1,400 lines. Category chips, grid, detail sheet with image gallery + AI summary. New: completely absent. The 4-tab layout has HOME/CHATS/GROUPS/PLANS with no Explore.

12. AI Spotlight — Old: full-screen blur + streaming text reveal + GhostInput. New: no dedicated AI surface at all.

13. Time Scrubber — Old: 2D temporal memory browser (year + events). New: no memories feature.

14. Settings subsystem — Old: 4 files covering settings page + profile edit + device list + device linking QR. New: 48-line stub with 3 static rows.

15. Invite/Join — Old: invite surface (QR) + claim sheet (long-press-to-join). New: completely absent.

16. Error reporting — Old: FeedbackSheet (3-state: editing/submitted/offline) + ErrorCard (auto-dismiss). New: no error handling UI anywhere.

17. Gold Burst celebration — Old: breathing gold border glow + haptic on 80%+ consensus. New: no consensus celebration.

18. 3-tier Plans view — Old: Event rail, category rail, content hero with overview dashboard. New: decision_sheet.dart is a flat mock list.

19. Swim lane rails — Old: category-sorted horizontal card rails with vital labels. New: no equivalent.

20. In-feed AI suggestions — Old: DiscoverySuggestionCard with "@hello suggests" inline card. New: no AI cards in feed.

21. Discovery suggestion card — Old: add-to-group from AI suggestion. New: no equivalent.

22. Spring curves library — Old: parameterized SpringCurve with named presets. New: uses standard easing curves.

23. Keyboard-aware input — Old: zero-lag tracking via platformDispatcher. New: sheets don't handle keyboard at all, input gets obscured.

### Tier 3: Features in OLD REACT (Gen 1) with no equivalent in Gen 4

24. Voice input — useVoiceInput with Web Speech API transcription. No voice feature.

25. Consensus timer — ConsensusTimer countdown ring to lock expiration. No timer.

26. Consensus banner — ConsensusBanner celebration on 80%+ with confetti. No banner.

27. Itinerary view — ItineraryView day-by-day trip schedule. Card exists (itinerary_card.dart) but taps to a SnackBar.

28. Link preview cards — LinkPreviewCard with OG metadata inline in chat. No link previews.

29. Space picker — SpacePicker multi-group dropdown for adding items. No cross-group actions.

30. Device tier detection — useDeviceTier adapts UI to device capability. No performance adaptation.

31. Playground choreography — usePlaygroundChoreography guided demo sequencing. No onboarding demo.

32. Awareness stream — AwarenessStream priority-sorted feed (needs flight > needs vote > exploring). HOME tab has ZenithMock hardcoded data.

### Tier 4: Web App Has NO Frontend

33. No web UI at all. 44 components + 11 hooks + 18 pages were deleted. Not one was replaced.

34. 53 API routes with no consumer. Backend is production-grade. Nobody calls it.

35. 27 crypto modules with no client. Full Signal Protocol in TypeScript. No component initializes it.

36. PWA manifest points to /login. The page doesn't exist. Would 404.

37. Service worker caches /galaxy. The page doesn't exist. Caches a 404.

---

## QUALITY COMPARISON

Engine integration — Gen 3: 6 providers wired to real engine streams. Auth, chat, decisions, receipts, typing, presence all working. Gen 4: kUseMockData = true. Mock data baked into widget bodies. Zero engine calls from any page. Gen 3 wins completely.

Visual polish — Gen 3: good but conventional, dark theme, standard iOS patterns. Gen 4: exceptional, plasma gradients, ambient mesh, glassmorphic sheets, spring animations, hologram avatars. Gen 4 wins.

Feature breadth — Gen 3: Auth + Chat + Decisions + Plans + Discovery + Settings + AI + Invites + Memories = 9 features. Gen 4: Home feed + Chat list + Group list + Card display + Sheets (all mock) = 5 mock screens. Gen 3 wins.

Code quality — Gen 3: some magic numbers, hardcoded group IDs, but clean architecture. DecryptedItemPayload model, proper StreamProvider.family, RepaintBoundary per chat item. Gen 4: 13 no-bold violations, 5+ duplicate _displayName implementations, 40+ always-running AnimationController tickers, BackdropFilter at OOM ceiling, zero Semantics. Gen 3 wins.

Chat bubble — Gen 3: 361 lines, asymmetric blur (outbound 20 sigma, inbound 8 sigma), web-safe (kIsWeb disables blur), spring drag with SpringSimulation(stiffness:600), 5-emoji picker. Gen 4: 452 lines, fixed blur, copy-paste corner radius bug (isLastInGroup ? inner : inner), landmine #9 conditional Positioned, hardcoded "Today 12:34 PM" timestamp. Gen 3 wins.

Decision cards — Gen 3: ActionCardWidget (424 lines), dual-spring physics, local score + engine.reactToItem() sync, gold burst at 80%. Gen 4: decision_card_small.dart (168 lines), emoji-glyph buttons, local state only lost on dispose, no engine call, score doesn't update on vote. Gen 3 wins.

---

## BOTTOM LINE

The rewrite gained visual craft and lost everything else.

Gen 3 had a working E2EE chat app — you could authenticate with a phone number, see real conversations, send encrypted messages, vote on decisions, and get AI suggestions. It wasn't pretty, but it was real.

Gen 4 has a stunning visual shell with plasma gradients and glassmorphic surfaces, but every tap either does nothing, shows a toast, or closes a sheet. The auth flow is a stub. The chat is mock data. The votes don't persist. The search bar doesn't accept input. The new chat button is a no-op. The 53-route backend has no frontend calling it.

23 features that previously worked are now broken, absent, or downgraded to mock-only. The web app's entire React frontend was deleted and never replaced. The old Flutter code in the backup is more functional than what's live today.

The plasma system is beautiful. But you can't ship a gradient.

---

## GAP TO "FIRST REAL MESSAGE"

Flutter path (shorter): Flip mock flag. Wire auth flow. Connect DmPage/GroupPage to ChatSession.messages stream and session.sendText(). Implement contact picker in new_chat_sheet. The UI chrome is already built.

Web PWA path (longer): Build the entire front-end from scratch — login page, chat list, chat page, message components, auth hooks, crypto initialization. The backend and libraries are ready to consume.
