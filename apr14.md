---
The Core Problem: You're Decorating Before You're Designing

Apple doesn't start with ShaderMask effects and BackdropFilter layers. Apple starts with: what does the user need to see, how do they get to it, and what happens when they tap. Then the visual language serves
those answers.

Your app starts from the opposite direction. You built glassmorphic sheets, hologram avatars, ambient mesh backgrounds, liquid intent handles, plasma strokes, and portal page routes. Then you put hardcoded
"Bali hotel" strings inside them. The visual effects exist before the information architecture does.

The result: every screen looks expensively made and says nothing. A user opening this app sees beautiful gradients and has no idea what to do. There's no hierarchy telling them "this is your most important
thing right now." There's no progressive disclosure. There's no information density. It's a gallery of effects, not a product.

Apple's Settings app has zero animations and zero blur effects. It communicates perfectly. Your settings page has a QR viewfinder label that says "ACTIVE" over a static icon, white text invisible on a white
background, and a device revocation flow that does nothing. The visual craft is high. The information design is zero.

SUGGESTION: Think Like Steve Jobs

Jobs would walk into a room, look at this app on a phone, and say: "What is this app FOR? Show me in one screen." Then he'd clear the room and come back with a napkin sketch that has three things on it.

Here is what he would demand:

1. ONE SCREEN, ONE ANSWER: When a user opens hello, the very first thing they see must answer the question "What do I need to do right now?" Not "what is pretty" — what needs my attention. Airbnb does this perfectly. When you open Airbnb, you see a search bar and destination cards. The answer is: "Where do you want to go?" Instagram opens to your feed. The answer is: "Here's what your people posted." Your home screen opens to a horizontal avatar dock with a spotlight hero. The answer is: "???" There is no answer.

The fix: Your home screen should open to a prioritized action list. The top item is the thing that needs you most. "Swiss Trip: 2 items need your vote." "Sarah sent you a message 3 minutes ago." "Bali flights lock in 4 hours — you haven't booked." This is what the old React AwarenessStream did and it was right. Every item is tappable, every item leads somewhere, every item resolves a task.

Reference — Slack: Opens to the channel with the most unread messages. Not a gallery of effects. The most urgent thing first. The entire left sidebar is a priority-sorted list of conversations with unread counts. That is information architecture.

Reference — Linear: Opens to "My Issues" — a kanban board of your personal tasks sorted by priority. Zero decoration. Maximum clarity. Every pixel communicates what you need to do next.

2. REMOVE THE EFFECTS UNTIL THE INFORMATION WORKS: Jobs famously killed the original iPhone's UI flourishes when they distracted from function. He would tell you to build the entire home screen as plain white cards with black text first. No plasma. No glass. No blur. No ambient mesh. Just: avatar, name, action needed, timestamp. Make THAT version feel right. Then add one effect at a time and ask "does this help the user understand their task, or does it distract?" If it distracts, cut it.

Reference — WhatsApp: 2 billion users. The chat list is: avatar circle, name in medium weight, last message in light weight, timestamp right-aligned, unread badge. That is all. No gradients, no blur, no animation. It is the most successful messaging UI ever built because the information hierarchy is flawless. The avatar tells you WHO. The name confirms it. The preview tells you WHAT. The timestamp tells you WHEN. The badge tells you HOW MUCH you've missed. Five data points, instantly parsed.

3. EVERY TAP MUST GO SOMEWHERE REAL: Jobs would tap every single element on the screen. If any tap does nothing, he would say "then why is it here?" The avatar with an empty onTap, the new chat button that pops the sheet, the search bar that doesn't search, the vote button that doesn't vote — he would cut all of them. If you can't build the feature yet, don't show the surface. A button that does nothing is worse than no button because it teaches the user that your app lies.

Reference — Apple Maps: Every element on the map is tappable and leads to a real detail card. There are no decorative pins. No fake businesses. No "coming soon" buttons. If it's on the screen, it works.

---
You Have No Typography System

You reference fontFamily: 'Inter' everywhere but Inter is not bundled in pubspec.yaml. On iOS it falls back to SF Pro. On Android it falls back to Roboto. On web it falls back to whatever the browser has. You
have never seen your own app render the same font across platforms.

Apple ships San Francisco with precise optical sizing, tracking tables per weight, and text styles that adapt to Dynamic Type. You have HelloText.display at 44px and HelloText.label at 10px with nothing in
between that creates a readable hierarchy. Your body text is 17px. Your label is 10px. That's a 7px jump with nothing bridging it. Apple uses 11, 13, 15, 17, 20, 22, 28, 34 — a continuous scale where every size
 has a purpose.

Your no-bold mandate (max w400) is conceptually interesting but you violate it 17 times across 7 files. If you can't enforce your own rule, the rule doesn't exist. Either commit to it and fix every violation,
or abandon it and use weight for hierarchy like everyone else. Half-enforced design rules are worse than no rules because they create inconsistency.

SUGGESTION: Think Like Steve Jobs

Jobs obsessed over typography more than almost anything else. He audited a calligraphy course at Reed College and later said it was the reason the Mac had beautiful fonts. He would look at your typography and say: "This is amateur. Fix it before you show me anything else."

Here is what he would demand:

1. BUNDLE THE FONT AND OWN THE RENDERING: Download Inter from Google Fonts. Add it to pubspec.yaml under fonts. Set fontFamily: 'Inter' in ThemeData. Now every platform renders identically. No more platform lottery. Apple bundles San Francisco and never lets the OS choose for them. You must do the same.

But Jobs would go further. He would ask: "Is Inter the right font for this brand?" Inter is a UI font designed by Rasmus Andersson for computer interfaces. It is clean but generic — hundreds of apps use it. Jobs would want a font that has personality. Look at what the premium apps do:

Reference — Airbnb: Uses Cereal, a custom typeface designed exclusively for them. It has slightly rounded terminals that mirror their logo shape. The font IS the brand.

Reference — Stripe: Uses a modified version of Camphor with custom number figures for financial data. The numbers are proportional, not tabular, which makes dollar amounts feel fluid and modern.

Reference — Linear: Uses Inter, actually — but with a very tight letter-spacing and specific size scale that makes it feel like their own. They own Inter by how they use it, not by what it is.

For hello, if you want billion-dollar: commission a custom typeface or license something distinctive. If that is not feasible right now, bundle Inter and define a strict type scale. Either way, the font must be in the binary, not a system fallback.

2. DEFINE A COMPLETE TYPE SCALE WITH SEMANTIC NAMES: Apple has 11 named text styles: largeTitle, title1, title2, title3, headline, body, callout, subheadline, footnote, caption1, caption2. Each has a size, weight, and leading. Each adapts to Dynamic Type accessibility settings.

You need to define your complete scale in HelloText:

- hero: 34px / w300 / -0.02 tracking (trip destination names, large numbers)
- title: 28px / w400 / -0.01 tracking (page titles, conversation names)
- headline: 22px / w400 / 0 tracking (section headers, card titles)
- body: 17px / w400 / 0 tracking (message text, descriptions)
- callout: 15px / w400 / 0 tracking (secondary information, timestamps in context)
- subhead: 13px / w400 / 0.01 tracking (metadata, member counts, "3 items need votes")
- caption: 11px / w400 / 0.02 tracking (eyebrow labels, "LIVE", "YOUR FOCUS")
- micro: 10px / w400 / 0.04 tracking (badge numbers, tiny labels)

Every text in the app must use one of these. No inline TextStyle with ad-hoc sizes. If a text doesn't fit one of these, the scale is wrong, not the text.

3. RESOLVE THE NO-BOLD MANDATE: Jobs would say: "You made a rule. Follow it or kill it." Here is the resolution: keep the no-bold mandate but use SIZE and OPACITY as your hierarchy tools instead of weight. This is actually more sophisticated than bold/not-bold:

- Primary information: 17px / w400 / opacity 1.0 (ink primary)
- Secondary information: 15px / w400 / opacity 0.65 (ink secondary)
- Tertiary information: 13px / w400 / opacity 0.45 (ink tertiary)
- De-emphasized: 11px / w300 / opacity 0.35

Apple's Music app does exactly this. Song titles, artist names, and album names are all the same weight. Size and opacity create the hierarchy. It feels calm and premium. Your app should feel the same way.

Fix all 17 violations. Change every w500, w600, w700, w800 to w400 and compensate with size or opacity. If a label at w400 doesn't look important enough, make it bigger, don't make it bolder.

Reference — Notion: Uses a single weight (400) for almost all body content. Headers are larger, not bolder. The result is a UI that feels calm and focused. When everything is the same weight, nothing shouts and nothing whispers — the hierarchy comes from spatial relationships and size.

---
Your Glass Hierarchy Is Incoherent

You have BackdropFilter at sigma 15 in dm_sheet headers, sigma 24 in decision_sheet, sigma 30 in card shells, sigma 30 in home_page, sigma 40 in group_chat_page Hero transitions, sigma 14 in sheet backgrounds, and sigma 0 (commented
out) in dm/group sheet pageBuilders. Six different blur values with no documented reasoning for why each surface gets its specific sigma.

Apple uses exactly three blur levels in the entire iOS system: ultraThinMaterial, thinMaterial, and regularMaterial. Three. With clear rules about when each applies.

You have six-plus. Some are at the WebGL crash ceiling. Some are inside transitions where they'll cause OOM. Some are commented out while others aren't. There's no hierarchy document that says "navigation
chrome gets X, modal backgrounds get Y, card surfaces get Z." You're assigning blur values per-file based on what looks good in that file, not based on a system.

SUGGESTION: Think Like Steve Jobs

Jobs would say: "Three. We need three. Not six. Three." He would eliminate every variant and force the team to justify each level from the user's perspective: what does this blur TELL the user?

Here is what he would build:

1. DEFINE THREE GLASS TIERS AND NEVER DEVIATE:

- Glass Tier 1 — "Whisper" (sigma 8): Light frosting. Used for floating navigation chrome that the user reads THROUGH. The content behind should still be recognizable. Use for: TabHeader, BottomBar pill, in-chat glass footer, card shell surface.

- Glass Tier 2 — "Veil" (sigma 16): Medium frosting. Used for modal surfaces where the background is context, not content. The user should know WHERE they are but not be able to read what's behind. Use for: sheet headers, sheet footers, DM/Group glass overlays.

- Glass Tier 3 — "Curtain" (sigma 24): Heavy frosting. Used for full-attention modals where the background is dismissed. The user is HERE now, not there. Use for: decision sheet, search sheet full-screen, AI spotlight overlay.

NEVER exceed sigma 24. The WebGL crash ceiling is 30. Leave a 6px safety margin. If a surface feels like it needs more than 24, the problem is not the blur — it is the background contrast. Add a tinted color layer instead.

2. BAN BLUR FROM TRANSITIONS: Any widget inside a Hero, PageView swipe, TabBarView transition, or AnimatedBuilder must NEVER use BackdropFilter. Blur during transitions causes CanvasKit to allocate offscreen buffers mid-animation, which is the exact OOM pattern that killed your old screens at 100px. The fix: freeze or remove the blur during the transition and fade it back in after the animation completes.

Reference — Apple Maps: When you pull up the bottom sheet in Maps, the sheet has a blur background. But during the pull GESTURE, the blur does not recompute — it uses a cached snapshot. The blur only updates when the sheet settles at a snap point. This is why Maps feels fluid: it never blurs and animates simultaneously.

Reference — iOS Control Center: The blur is pre-rendered. When you swipe down, you see a blurred snapshot that was composited BEFORE the gesture began. This is why Control Center never drops frames.

3. CODIFY THE TIERS IN CODE:

Create a `HelloGlass` class with three static methods:
```
HelloGlass.whisper(child)   // sigma 8, white 70% fill, 0.5px border
HelloGlass.veil(child)      // sigma 16, white 80% fill, 0.5px border
HelloGlass.curtain(child)   // sigma 24, white 90% fill, no border
```

Every BackdropFilter in the codebase calls one of these three. No inline ImageFilter.blur anywhere. If a developer wants sigma 30, the compiler tells them: "Use HelloGlass.curtain." If they want sigma 40, the system doesn't offer it.

Reference — Uber: Uses exactly two blur levels in their entire app: a light blur behind the destination input card, and a heavier blur behind the ride-request sheet. Two. For an app used by 130 million people. Constraint creates coherence.

---
The Color Situation Is a Mess

--hello-white is #111111 (dark). --hello-void is #FAFAFA (light). You have files using Colors.white on #FAFAFA backgrounds (invisible). You have Color(0xFFFF385C) (hot pink), Color(0xFFFF5A00) (orange),
Color(0xFFFFB380) (peach) scattered in files, none of which are in HelloColors. You have HelloColors.primary marked as deprecated but used in 2 new files. You have device_listing.dart as a fully dark-themed
file sitting inside a light-themed app. You have decision_card.dart rendering dark #1E1E1E cards in a #FAFAFA feed.

Apple has one color system. Every color has a name, a light value, a dark value, and an accessibility variant. There are no orphan hex values in any file.

Your HelloColors in theme.dart defines a clear set of tokens. And then half your files ignore them and hardcode hex values. The design system exists on paper and is bypassed in practice.

SUGGESTION: Think Like Steve Jobs

Jobs would hold up the phone and say: "I see five different oranges. Which one is ours?" Then he would demand a single source of truth and fire anyone who hardcodes a hex value outside it.

Here is what he would build:

1. AUDIT AND KILL EVERY ORPHAN COLOR: Grep the entire codebase for `Color(0x` and `Colors.` that aren't from HelloColors. Every single one gets replaced or registered. Here are the orphans found in this review:

- `0xFFFF385C` (hot pink) in _card_shell.dart, liquid_intent_handle.dart — either register as `HelloColors.pulsePink` or replace with plasma
- `0xFFFF5A00` (orange glow) in settlement_card.dart — either register as `HelloColors.glowOrange` or replace with accent
- `0xFFFFB380` (warm peach) in decision_sheet.dart — either register as `HelloColors.warmPeach` or replace with an existing token
- `Color(0xFF1E1E1E)` (dark card) in decision_card.dart — replace with HelloColors token or redesign card for light theme
- `Color(0xFF51443E)` (taupe) in direct_message_page.dart — register or replace
- `Colors.white` used as text color in 5+ files on light backgrounds — replace with HelloColors.inkPrimary or inkSecondary
- `HelloColors.primary` in 2 new files — replace with current tokens

Zero tolerance. If a color is not in HelloColors, it does not ship.

2. FIX THE NAMING INVERSION: `--hello-white` being `#111111` (dark) and `--hello-void` being `#FAFAFA` (light) is a cognitive trap that will cause bugs forever. Rename them:

- `--hello-white` (#111111) becomes `HelloColors.ink` — it is your ink color, your text color, your darkest mark.
- `--hello-void` (#FAFAFA) becomes `HelloColors.canvas` — it is your blank canvas, your background.

This is not cosmetic. Every developer who touches this codebase will intuitively reach for "white" when they want a light color. If "white" is dark, they will write bugs. Apple names colors by function, not by appearance: `label`, `secondaryLabel`, `tertiaryLabel`, `quaternaryLabel`, `systemBackground`, `secondarySystemBackground`. You never have to guess what `secondaryLabel` looks like — you know it's less prominent than `label`.

Reference — Material Design: Google's color system names tokens by role: `surface`, `onSurface`, `primary`, `onPrimary`, `outline`, `outlineVariant`. The name tells you WHERE it goes, not WHAT it looks like.

Reference — Figma: Their internal design system names every color with a `{category}/{variant}/{state}` pattern: `text/primary/default`, `text/primary/disabled`, `bg/surface/elevated`. No ambiguity.

3. BUILD A DARK-MODE-READY TOKEN SYSTEM NOW, EVEN IF YOU DON'T SHIP DARK MODE YET: Define every HelloColors value as a pair:

```
static Color get canvas => _isDark ? Color(0xFF111111) : Color(0xFFFAFAFA);
static Color get ink => _isDark ? Color(0xFFFAFAFA) : Color(0xFF1A1A1A);
static Color get inkSecondary => _isDark ? Color(0xFF9E9EA8) : Color(0xFF6B6B78);
```

This solves two problems: (a) every file automatically uses the right color in the right theme, eliminating the dark-text-on-light-background bugs in device_listing.dart and feedback_sheet.dart; and (b) when you eventually ship dark mode, it works immediately with no per-file migration.

Reference — Telegram: Supports 4+ themes (day, night, night blue, tinted). Every color is a theme token. Adding a new theme is changing a palette file, not touching any component. They handle millions of users with this system.

Reference — Spotify: Dark-only by design. But their token system is so disciplined that every surface — now playing bar, playlist header, search results — uses exactly the same `surface` / `elevated` / `highlight` tokens. If they ever shipped light mode, the app would just work.

4. PLASMA IS YOUR ACCENT, NOT YOUR COLOR SYSTEM: The plasma gradient (FF0055 → FF0000 → FF4D00 → FF8C00) is beautiful. But it is for ~28 action surfaces. Every other color in the app must come from the neutral palette: canvas, ink at various opacities, and the focus trip colors (alpine, ocean, sunset, violet). The problem is that developers reach for accent/plasma when they want something to "pop." The rule: if the element is not in the 28-surface list, it must be grayscale or trip-tinted. Never plasma.

Reference — Apple: The entire iOS system uses exactly one accent color: blue (#007AFF). It appears on links, toggle switches, and primary action buttons. Everything else is gray, white, or black. One accent, used with extreme discipline, makes that accent feel meaningful. Your plasma could be that powerful if you stop diluting it by putting orange on passive informational icons and eyebrow labels.

---
You're Building Effects, Not Interactions

Count the animated elements: PlasmaClock, AmbientMesh, LiquidIntentLayer spring, CardShell ring pulse, CardShell unread pulse, CardShell tap spring, BottomBar AnimatedSwitcher, TabHeader AnimatedSwitcher,
TypingDots, _breatheController in dm/group pages, portal page route scale/fade, HologramAvatar ShaderMask, PlasmaFill, PlasmaTint, PlasmaStroke, PlasmaProgressBar.

Now count the interactions that produce a meaningful result: zero. Tapping send shows a toast. Tapping vote updates local state that's lost on scroll. Tapping search does nothing. Tapping new chat closes the
sheet. Tapping the avatar does nothing. Long-pressing a bubble shows reactions that don't persist.

Apple's apps have fewer animations but every animation communicates something. The swipe-to-delete spring tells you "this action is real and you just did it." The pull-to-refresh spinner tells you "data is
coming." Your animations tell the user "this app is beautiful" and nothing else. Beauty without utility is decoration, not design.

SUGGESTION: Think Like Steve Jobs

Jobs would say: "I don't want it to move unless it means something." He would list every animation and demand a one-sentence justification. If the sentence starts with "it looks cool" instead of "it tells the user," the animation dies.

Here is what he would build:

1. THE ANIMATION JUSTIFICATION TEST: For every animation in the app, answer this question: "What does the user learn from this motion that they could not learn from a static state?" If the answer is nothing, kill the animation.

Apply the test:

- PlasmaClock (shared gradient sweep): KEEP. It distinguishes "this is an action I can take" from "this is information I'm reading." The motion is the brand. It earns its cost.
- AmbientMesh (tab color lerp): CONDITIONAL. During a tab swipe, the background color lerp tells the user which tab they're approaching. That is useful feedback. But when sitting on a single tab with no interaction, the mesh should be STATIC. Stop the animation when the tab index has settled for more than 500ms. Resume when a swipe begins.
- CardShell ring pulse: KILL. A pulsing ring on the focused card adds no information. The user already knows which card they're looking at — it's the one in the center of the screen. The pulse is decoration. Replace with: nothing. Or if you must have focus indication, use a subtle scale change (1.02x) that is static while the card is centered, not continuously animated.
- CardShell unread pulse: CHANGE. An unread indicator should be a static dot (plasma-filled) that is either present or absent. A pulsing glow does not make the user read the message faster. Replace the `AnimationController.repeat()` with a static `PlasmaFill` dot.
- CardShell tap spring: KEEP. This is direct feedback for a user's touch. It says "I felt your tap." Exactly what Apple does with every button.
- _breatheController (hint animation): KEEP but make it SELF-TERMINATING. The breathing "swipe to explore" hint should play twice, then stop forever. The user either saw it or didn't. Looping it infinitely is nagging.

2. EVERY INTERACTION MUST COMPLETE A SENTENCE: Jobs would frame it this way: every time a user touches the screen, they are starting a sentence. "I want to..." The app must finish the sentence:

- User taps send → "I want to send this message" → message appears in the list, scrolls to bottom, delivery indicator shows. NOT: toast appears and disappears.
- User taps vote → "I want to vote for this" → the score updates immediately (optimistic), the button stays pressed, a micro-celebration plays if they're the tipping vote. NOT: local state updates and is lost on scroll.
- User taps avatar → "I want to see this person's profile" → profile card slides up with their name, shared groups, and message history. NOT: nothing happens.
- User taps search → "I want to find something" → keyboard appears, cursor blinks, results filter as they type. NOT: a static label sits there.

Reference — Instagram: Tap the heart on a photo. The heart fills instantly (optimistic update), a brief scale animation plays (0.8 → 1.2 → 1.0 in 300ms), and the like count increments. Three things happen in under 300ms and all three tell you "your action was received." The server sync happens silently in the background. The user never waits.

Reference — Tinder: Swipe right. The card flies off screen with physics that match your swipe velocity. A "LIKE" stamp appears at the rotation angle of your gesture. The next card is already loaded underneath. The entire interaction takes 400ms and communicates: your choice was registered, here's the next one, keep going. No waiting, no confirmation dialog, no toast.

3. BUILD FEEDBACK BEFORE FEATURES: Before wiring any feature to the engine, build the feedback layer. This means:

- Haptic feedback: Import `flutter/services.dart` in every interactive widget. `HapticFeedback.lightImpact()` on every tap. `HapticFeedback.mediumImpact()` on every drag release. `HapticFeedback.heavyImpact()` on destructive actions (delete, revoke, lock). `HapticFeedback.selectionClick()` on picker changes (tab switch, category select).

- Optimistic visual updates: Every action should update the UI immediately, before the network responds. Vote → score changes now, syncs later. Send → message appears now, delivery indicator updates later. Delete → item fades now, server confirms later.

- Completion animations: When an action succeeds, play a 200ms micro-animation. A checkmark that draws itself. A subtle scale bounce. A color transition from accent to settled green. These are 20-line widgets that make the app feel alive.

Reference — Apple Pay: Double-click side button → Face ID → "Done" checkmark with haptic. Three steps, each with distinct haptic, each instant. The entire payment takes 2 seconds and you feel every stage physically. That is what "premium" means.

---
The 40+ Always-Running AnimationControllers Are Not Premium, They're Wasteful

Every CardShell in the feed runs 3 AnimationController.repeat() calls in initState regardless of whether the card is focused, unread, or being tapped. With 20 cards visible, that's 60 tickers firing every
frame. Apple's engineers would consider this a performance bug, not a feature. Premium means things move when they should and are still when they shouldn't. Running constant animations on every card creates
visual noise, not sophistication.

iMessage shows zero animation on a message list until you interact with something. Then the interaction animation is precise, meaningful, and stops when the interaction ends. Your cards pulse and ring
continuously whether anyone is looking or not.

SUGGESTION: Think Like Steve Jobs

Jobs understood that restraint IS the premium. The original iPod had one wheel. The original iPhone had one button. Premium is not "more" — it is "only what matters." He would look at 60 tickers running on screen and say: "This is the opposite of what I asked for. I asked for polish. This is noise."

Here is what he would build:

1. THE LAZY ANIMATION PRINCIPLE: No AnimationController starts until it is needed. No AnimationController runs after its purpose is fulfilled. This is not optimization — this is design philosophy.

Rewrite CardShell:

- `_ringController`: Do NOT start in `initState`. Start ONLY when `isFocused` becomes true (in `didChangeDependencies` or a `ref.listen` callback). Stop when `isFocused` becomes false. If the card is never focused, the controller never runs. Cost: 0 tickers for 19 out of 20 visible cards.

- `_unreadController`: Do NOT start in `initState`. Start ONLY when `widget.ambientPulse` is true. Stop when it becomes false. Better yet: replace the animation entirely with a static PlasmaFill dot (see animation justification above). Cost: 0 tickers.

- `_tapController`: This one is correct — it starts on tap and stops on release. Keep it. Cost: 0 tickers when not being tapped.

Net result: From 60 tickers per frame to 2-3 tickers per frame (one focused card's ring + PlasmaClock shared controller). That is a 95% reduction in animation overhead.

2. THE SHARED ANIMATION PRINCIPLE: You already did this correctly with PlasmaClock. One AnimationController drives all 28 plasma surfaces. Apply the same principle everywhere:

- AmbientMesh: Already uses a shared controller. Correct.
- TypingDots: Should share a single global typing animation, not create a new AnimationController per card that shows typing.
- _breatheController: Two copies exist (dm_page and group_page). Extract to a shared mixin or utility.

Reference — Flutter's own TickerMode: Flutter has a built-in TickerMode widget that disables all AnimationControllers for offscreen subtrees. If you wrap your masonry grid items in TickerMode(enabled: isVisible), every card that scrolls off screen automatically pauses all its animations. Zero code change in the card widgets. This is how Google's own apps handle animation performance in lists.

3. THE VISIBILITY GATE: Use Flutter's `VisibilityDetector` (from the `visibility_detector` package) or `Sliver`-level keep-alive semantics to track which cards are actually on screen. Only on-screen cards run animations. This is how every high-performance list in the App Store works:

Reference — TikTok: Only the currently visible video plays. Scroll one pixel past the threshold and the previous video pauses, its audio stops, its animation controllers freeze. Scroll back and it resumes from the same frame. This is not just for video — every particle effect, heart animation, and text overlay in TikTok follows the same rule. If the user can't see it, it doesn't run.

Reference — Twitter/X: Profile header parallax animations only run while the header is visible. Once you scroll past the header into the tweet list, the parallax controller stops. The tweet list itself has zero animation until you interact (like, retweet, reply).

4. MEASURE AND BUDGET: Apple engineers allocate a "frame budget" — 16.67ms per frame at 60fps. They know exactly how many milliseconds each component costs. You should add a performance overlay (`MaterialApp(showPerformanceOverlay: true)`) and scroll through your feed on a low-end Android device. If the frame time exceeds 16ms during passive scrolling (no user interaction), you have too many animations running. The target is: passive scroll = 0 animations running except PlasmaClock. Active interaction = targeted animation on the touched element only.

---
Your Information Density Is Zero

Open iMessage. In a single screen you see: 15-20 conversations, each with an avatar, a name, a timestamp, a message preview, and a delivery indicator. That's 5 data points per row, 15 rows, 75 pieces of
information on one screen.

Open your home page. You see: a horizontal dock of avatars and one hero spotlight card. That's maybe 5-8 pieces of information on the entire screen. The rest is gradient, blur, and whitespace.

Apple uses whitespace to create breathing room between high-density information. You use whitespace because there's no information to show. A "Morning Brief" card with 3 hardcoded strings is not information
density. A feed of mock "Bali hotel" items is not information density. Until real data flows through these layouts, you cannot judge whether the layouts work at scale. A masonry grid that looks good with 6 mock
 cards may fall apart with 60 real ones.

SUGGESTION: Think Like Steve Jobs

Jobs would say: "Density is not clutter. Density is respect for the user's time." He would hold up the iPhone and say: "This screen is 6.1 inches. Every pixel you waste on decoration is a pixel the user can't use to make a decision. Show me a screen where I can make a decision in 3 seconds."

Here is what he would build:

1. THE 3-SECOND RULE: Every screen in the app must allow the user to take a meaningful action within 3 seconds of seeing it. Not "understand" — ACT. This forces information density because actions require context.

For the HOME tab, the 3-second action is: "tap the most urgent item." That means the most urgent item must be immediately visible, immediately identifiable, and immediately tappable. A horizontal avatar dock with a single spotlight hero fails this test — the user has to parse the dock, select an avatar, read the hero, then decide. That is 6-10 seconds minimum.

Replace with: A vertical list of action cards, sorted by urgency, each showing WHO (avatar), WHAT (action needed), WHEN (deadline), and a single CTA button. The user sees the list, taps the top item, done. 3 seconds.

Reference — Superhuman: Email reimagined as a priority queue. The most important email is at the top. One keystroke to act. The entire UI is designed for speed of decision. They charge $30/month because they save you 3 hours/week. Speed of decision IS the product.

Reference — Duolingo: Opens to one button: "START LESSON." Not a dashboard. Not a gallery. One button that does the most important thing. Everything else is secondary. The lesson streak count is visible but small. The leaderboard is one swipe away. The shop is two taps away. The core action is 0 seconds to reach.

2. THE DATA POINT INVENTORY: Count the data points per screen element. If any element has fewer than 3 data points, it is either too large or too empty. If any element has more than 7, it needs to be split.

Your conversation list row (ConversationListRow) currently shows: avatar (1), name (2), timestamp (3), preview text (4), unread badge (5). That is 5 data points — correct. This is your best-designed component.

Your home page dock item (UnboundAvatarItem) shows: avatar (1), name (2). That is 2 data points. It is too large for what it communicates. At 72px wide per item, you fit 5 items on screen. 5 items x 2 data points = 10 pieces of information. Compare: a conversation list with 74px rows fits 8 rows on screen. 8 rows x 5 data points = 40 pieces of information. The conversation list is 4x more information-dense.

The fix: either add data to the dock items (unread count, last action, urgency indicator) or shrink them to 44px and fit more on screen. WhatsApp's status row shows 20+ avatars at 44px each because each avatar only needs to convey "this person posted."

Reference — Notion: Their sidebar shows pages as a flat list with tiny (16px) icons, page names, and nothing else. Extremely high density — you can see 30+ pages on a laptop screen. When you need detail, you click the page. The sidebar is for NAVIGATION, not for READING. Your dock should be the same: navigation, not content.

3. TEST WITH REAL DATA AT SCALE: Create a mock data generator that produces 50 DM conversations, 15 groups, 200 decision items, and 30 trip itineraries. Fill them with:

- Names that are 3 characters ("Ali") and 25 characters ("Alexandra Richardson-Martinez")
- Messages that are 5 words ("hey are you free") and 200 words (a paragraph)
- Timestamps from "just now" to "3 months ago"
- Unread counts from 0 to 999
- Decision items with 0 votes, 3 votes, and 12 votes
- Trip photos that are portrait, landscape, missing, and broken URLs

Run the app with this data. Every layout problem will reveal itself: text overflow, badge truncation, empty states, scroll performance, masonry grid imbalance with varied card heights, conversation list with all-read vs all-unread states. You will discover that your 72px avatar looks absurd next to "Alexandra Richardson-Martinez" truncated to "Alexandr..." You will discover that a masonry grid with 200 items scrolls at 45fps because of the BackdropFilter on every CardShell.

Reference — Facebook: Before shipping any UI change, they run it through a "data diversity" test with synthetic profiles from every country, language, name length, and content type. A profile with a 40-character Thai name in a right-to-left Arabic group with a 3-line bio and no profile photo. That is what "billion-dollar testing" looks like.

---
What Billion-Dollar Apps Actually Have That You Don't

State transitions. Loading → loaded → empty → error. Every screen, every list, every card. You have none. A user on slow network sees blank white.

Progressive disclosure. Tap a conversation → see messages → tap a message → see details → long press → see actions. Each level reveals more. Your app has one level: the feed. Tapping goes to a sheet with
hardcoded content. There's no depth.

Predictability. In iMessage, every conversation row behaves identically. In your app, tapping a DM card opens a sheet on some paths and a full page on others. The search sheet navigates to pages. The card
factory navigates to sheets. Two paths to the same content, undocumented.

Feedback. Every tap produces a response within 100ms. Haptic, visual, or both. Your new code has zero HapticFeedback imports. Zero. Apple uses haptics on nearly every interaction.

Accessibility. Zero Semantics widgets in ~65 files. Apple would not pass internal review, let alone App Store review.

Real content testing. Apple designs with real data: real names (some long, some short, some RTL), real images (some portrait, some landscape, some missing), real edge cases (0 messages, 1 message, 10000
messages). You've never run your layouts against anything except "Bali hotel" and "Swiss Trip."

SUGGESTION: Think Like Steve Jobs

Jobs would read this list and say: "These aren't features. These are table stakes. If you don't have these, you don't have an app. You have a prototype pretending to be an app."

Here is what he would build, in order:

1. STATE TRANSITIONS — THE FOUR HORSEMEN: Every data-driven widget in the app must handle exactly four states. No exceptions. Build a `DataState<T>` union type and a `DataStateBuilder` widget:

- LOADING: Shimmer skeleton that matches the shape of the loaded content. Not a spinner. Not blank white. A ghost of the content that will appear. The user's brain starts parsing the layout before the data arrives.

- LOADED: The real content. This is what you've been building. But it must gracefully handle: 1 item (centered, not floating in a sea of white), 5 items (normal), 50 items (scrollable, performant), 500 items (paginated, lazy-loaded).

- EMPTY: A centered illustration + headline + subhead + CTA. "No messages yet. Start a conversation." This is not optional. An empty screen is a confused user. An empty screen with a CTA is an engaged user.

- ERROR: An inline error card (your error_card.dart, once the compile error is fixed) with a retry button. Not a red alert. Not a dialog. A card in the content area that says "Something went wrong. Tap to retry." Calm, not alarming.

Reference — Airbnb: Their search results page has all four states. Loading: animated placeholder cards matching the final card shape. Loaded: photo cards with pricing. Empty: "No results. Try adjusting your dates." Error: "We couldn't load results. Tap to retry." Every state is designed, not an afterthought.

Reference — Stripe Dashboard: Loading state uses gray rectangular shimmer blocks that match the exact dimensions of the table rows, charts, and KPI cards that will appear. When the data loads, the shimmer dissolves into content with no layout shift. The user's eye position doesn't change. This is a $95 billion company's attention to loading states.

2. PROGRESSIVE DISCLOSURE — THE DEPTH MAP: Draw a depth map of your app. Level 0 is what the user sees on launch. Level 1 is what they see after one tap. Level 2 is after two taps. Level 3 is after three taps. Billion-dollar apps have 3-5 levels. Your app has 1.5.

Build the depth:

- Level 0: Home feed (priority-sorted action list). User sees urgency at a glance.
- Level 1: Tap a DM → full-screen chat. Tap a group → full-screen group with chat/plans swipe. Tap a decision → decision detail sheet.
- Level 2: In chat, long-press a message → reaction picker + reply + copy + delete. In group, tap a decision item → full detail with vote buttons + photo gallery + "@hello says" summary.
- Level 3: In decision detail, tap "Add to Trip" → itinerary slot picker. Tap "Share" → share sheet. Tap the consensus bar → voter breakdown (who voted what).

Each level is a real feature, not a visual treatment. Each level ADDS information that was hidden at the previous level. This is progressive disclosure.

Reference — Apple Photos: Level 0: grid of thumbnails (high density, fast scanning). Level 1: tap → full photo (medium density, visual appreciation). Level 2: swipe up → metadata, map, people, suggestions (rich context). Level 3: tap Edit → full editing tools. Each level reveals more while the previous levels remain accessible with a back gesture.

Reference — Spotify: Level 0: Home with "Made for You" sections. Level 1: Tap a playlist → track list. Level 2: Tap a track → now playing with lyrics. Level 3: Tap the queue button → upcoming tracks with drag-to-reorder. Level 4: Tap the device button → AirPlay/Bluetooth picker. Five levels of depth, each immediately useful.

3. PREDICTABILITY — ONE PATH PER DESTINATION: Jobs would say: "There should be exactly one way to get to any piece of content." Your app has two paths to the same DM conversation: openDmSheet (bottom sheet) from some card taps, and openDmPage (full-screen push) from the search sheet. Pick one. The rule:

- Tap from a card in the feed → full-screen page (CupertinoPageRoute). This is the primary path.
- Tap from search results → same full-screen page. Same destination.
- Bottom sheets are for CREATION and CONFIGURATION, not for viewing content. Sheets = new chat, new group, attachment picker, settings. Pages = viewing conversations, groups, decisions, profiles.

Reference — iMessage: Every conversation is reached the same way: tap the row, full-screen push. There is no "sometimes a sheet, sometimes a page." The navigation model is so consistent that users never think about it. That is the goal.

4. HAPTIC ARCHITECTURE: Build a `HelloHaptic` utility class with semantic methods:

```
HelloHaptic.tap()        // lightImpact — every button, every card
HelloHaptic.confirm()    // mediumImpact — send message, cast vote, save setting
HelloHaptic.celebrate()  // heavyImpact — consensus reached, item locked, onboarding complete
HelloHaptic.select()     // selectionClick — tab switch, picker change, category filter
HelloHaptic.warning()    // notificationWarning — destructive action confirmation
```

Then: every GestureDetector, InkWell, and TextButton in the app calls the appropriate HelloHaptic method. No exceptions. No "I'll add haptics later." The haptic is part of the interaction, not a polish layer.

Reference — Apple Watch: Every turn of the Digital Crown produces a haptic click. Every notification tap produces a distinct haptic pattern. Every workout milestone produces a celebration burst. Apple designed an entirely new haptic engine (Taptic Engine) because they believe physical feedback is not optional — it is fundamental to the experience.

5. ACCESSIBILITY IS NOT A FEATURE, IT IS A REQUIREMENT: Build a `HelloSemantics` wrapper for every interactive widget:

```
HelloSemantics(
  label: 'Swiss Trip group, 3 unread messages',
  hint: 'Double tap to open',
  isButton: true,
  child: GroupCard(...),
)
```

Then audit every file. VoiceOver should be able to navigate the entire app: home feed, conversation list, chat messages, decision voting, settings. A blind user should be able to send a message.

Reference — Apple: Their accessibility team has veto power over any feature that ships. If VoiceOver doesn't work, the feature doesn't ship. Period. This is not charity — 15% of users have some form of disability. That is 15% of your billion-dollar market.

Reference — Be My Eyes: An app that connects blind users with sighted volunteers via video call. They have 500,000 users. Their entire UI is Voice-Over-first. Every element has a semantic label. Every gesture has an accessibility alternative. They prove that accessibility-first design does not compromise visual quality — it forces clarity.

---
FINAL NOTE

The distance between where this app is and where it needs to be is not measured in components or animations. It is measured in decisions. Every time you sit down to build, you face a choice: build another visual effect, or make one existing thing actually work. Jobs would always choose the second. The first Mac shipped with one font menu, not twelve. But that one font menu worked perfectly.

Build one perfect conversation. Then build the second one.
