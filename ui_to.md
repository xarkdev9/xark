Based on everything reviewed across all four generations, here is every UI component and visual element that still needs to be built or fixed in the new
  app. Organized by where it goes.

  ---
  HOME TAB (currently home_page.dart)

  Awareness Stream / Priority Feed — The horizontal dock shows 17 hardcoded ZenithMock objects. The old React AwarenessStream.tsx had priority-sorted cards:
  who needs flights first, who hasn't voted, what's converging, with time decay scoring. The new dock is a flat list with no priority logic, no sorting, no
  visual differentiation between urgent and idle items.

  Awareness Badges on Avatars — The old React PeopleDock.tsx showed active/idle/away state as colored dots on each avatar. The old Flutter chats_tab_view.dart
   had unread rose dots. The new UnboundAvatarItem has a selected-state indicator pip but no presence/awareness badge.

  In-Feed AI Suggestion Card — Gen 3 had DiscoverySuggestionCard (210 lines): an inline "@hello suggests" card showing 1-3 items with thumbnails, titles,
  prices, and per-item "Add" buttons. No equivalent exists in the new feed.

  ---
  CHAT (DM + Group pages)

  Real Message List Widget — Both dm_page.dart and group_page.dart render hardcoded _MockMessage arrays inline in build(). There is no reusable ChatFeed or
  MessageList widget that accepts a stream. Gen 3's chat_feed.dart (253 lines) was a dedicated widget with reverse scroll, .select() per-item rebuilds,
  same-sender grouping, RepaintBoundary per item, load-more pagination, and timestamp reveal on scroll pause. That widget needs to be rebuilt.

  Typing Indicator — Gen 3's chat_view.dart had a real-time typing indicator bar at the bottom of the chat that animated dots when the other person was
  typing. group_card.dart has _TypingDots but it only appears in the card, not in the full chat view. The full-screen DM and group pages have no typing
  indicator.

  Read Receipt Display — Gen 3's chat_feed.dart promoted message status from sent → delivered → read based on the receipt stream and showed checkmark
  indicators. The new ChatBubble accepts a status parameter but no caller passes real status data.

  Link Preview Cards — React had LinkPreviewCard.tsx (120 lines): OG metadata card with image, title, and domain rendered inline in chat messages. No
  equivalent in the new app. URLs sent as messages render as raw text.

  Encrypted Media Renderer — Gen 3 had EncryptedImageView (190 lines): blur placeholder thumbnail during decrypt, animated crossfade to decrypted image, lock
  icon on failure. The new chat bubble has no inline media support at all.

  Swipe-to-Reply Icon Direction — Already reviewed: the reply icon appears on the wrong side of the bubble during swipe. Outbound messages show the icon on
  the right (the side the bubble moves away from). Needs to be flipped.

  Chat Bubble Corner Radius Bug — chat_bubble.dart:140-151: isLastInGroup ? inner : inner — both branches identical. Solo messages get wrong corner radii.
  Copy-paste bug.

  Chat Bubble Timestamp — Hardcoded "Today 12:34 PM" at line 193. No actual timestamp parameter exists on the widget.

  ---
  SHEETS

  Search Sheet — Real Search — search_sheet.dart has a cosmetic Container with static text instead of a TextField. The list shows all conversations with no
  filtering. Needs: a real TextEditingController, debounced filtering of the conversation list, and empty-state for no results.

  New Chat Sheet — Contact Picker — new_chat_sheet.dart (only reachable if BottomBar is restored) has three options that all do Navigator.pop(). "New Chat"
  needs a contact search/picker with engine.findOrCreateChat(). "New Group" needs a title input + member selection with engine.createGroup(). "New Event"
  needs at minimum a placeholder flow.

  Attachment Sheet — attachment_sheet.dart exists but was not reviewed in this cycle. The MessageInputBar has a [+] that toggles an internal media tray with
  camera/image/location icons that are all onPressed: () {} stubs. Either the tray or the sheet needs to actually open an image picker and eventually wire to
  engine.sendMedia().

  Settlement Sheet — settlement_sheet.dart exists. Needs review to confirm it displays real settlement data from xpensly_core rather than hardcoded amounts.

  Keyboard Avoidance on All Sheets — All four reviewed sheets (dm_sheet, group_sheet, decision_sheet, search_sheet) use fixed heights with no
  viewInsets.bottom compensation. When the software keyboard opens, it covers the input bar on every phone. Every sheet with an input needs keyboard-aware
  bottom padding.

  ---
  DECISION / VOTING

  Vote Buttons That Actually Update the Score — decision_card_small.dart and decision_sheet.dart both have vote buttons that update local setState only. The
  progress bar and agreement percentage do NOT change when you vote. The UI needs to at least update the local score display immediately (optimistic update)
  even before engine wiring.

  Gold Burst / Consensus Celebration — Gen 3 had gold_burst.dart (102 lines): a breathing animated border glow with HapticFeedback.heavyImpact() triggered at
  80%+ agreement. The new decision_card.dart has a dead _triggerGoldBurst() method. No visual celebration exists for the consensus moment. This was the single
   most emotionally resonant feedback loop in the old app.

  Consensus Banner — React had ConsensusBanner.tsx (180 lines): a celebratory banner across the top of the decision board with confetti and "Group agrees!"
  copy. No equivalent.

  Consensus Timer — React had ConsensusTimer.tsx (120 lines): animated countdown ring showing time remaining until lock expiration. The new _ConsensusTimer in
   decision_card.dart is a text-only countdown with no ring visualization.

  Inline Poll Widget — Gen 3 had InlinePollWidget (159 lines): animated fill bars embedded in chat messages for live voting. No equivalent in the new chat
  bubble or message list.

  ---
  PLANS TAB

  Split Category (Xpensly Entry) — Gen 3's plans_view.dart had "Split" as the last category in the tier-2 rail, opening _SplitPlaceholder as the Xpensly entry
   point. The new plans_view.dart has no Split category. The expense splitting SDK (xpensly_core + xpensly_ui) exists with 9 themed widgets but nothing in the
   plans tab links to it.

  Add Decision Item Sheet — Gen 3 had add_item_sheet.dart (193 lines): title + category + photo fields, submit calls engine.encryptPayload() +
  addDecisionItem(). The new group page has no [+] button and no add-item flow.

  Category Swim Lane Rails — Gen 3 had swim_lane_rail.dart (149 lines): horizontal card rails per category with vital labels ("82% on #1, 3 of 5 rated"). The
  new plans_view uses a tier-2 chip rail but the content below is a single hero canvas, not per-category swim lanes. Different UX choice but the swim lane
  visual is gone.

  Itinerary Day View — React had ItineraryView.tsx (200 lines): day-by-day trip schedule with flight/hotel/activity blocks. itinerary_card.dart exists in the
  feed but tapping it shows a SnackBar. There is no full itinerary page.

  ---
  DISCOVERY / EXPLORE

  Discovery Item Card — Gen 3 had discovery_item_card.dart (185 lines): photo with 4:3 aspect ratio, title, price, taste score dot (green/amber/gray), source
  badge ("AI"/"curated"), taste reason. The new explore_tab.dart has 10 identical placeholder tiles with no data model.

  Discovery Detail Sheet — Gen 3 had discovery_detail_sheet.dart (504 lines): image gallery PageView with dot indicator, title/location/rating, "@hello says"
  AI summary, tags, "Add to group" button with multi-group dropdown, Save, Not interested. No equivalent exists.

  Discovery Carousel — Gen 3 had discovery_carousel.dart (54 lines): stories-style horizontal carousel with swipe-up dismiss. No equivalent.

  Category Chips — Gen 3 had category_chips.dart (107 lines): horizontal filter chips with AnimatedContainer selection state. The new explore tab has no
  filtering.

  Shimmer Loading State — Gen 3's explore tab had shimmer placeholder cards (pulsing opacity 0.3→0.7) during data load. No loading state exists anywhere in
  the new app — empty feeds show blank space.

  ---
  SETTINGS

  Dark-Theme-on-Light Fix for device_listing.dart — Every text and icon in this file uses Colors.white on a #FAFAFA background. The entire file needs color
  migration to the light theme.

  Profile Edit Page — Gen 3 had profile_edit.dart (147 lines): 120px tappable avatar with simulated upload delay, centered borderless name TextField,
  ProfileState/ProfileNotifier Riverpod state. The new user_settings_page.dart has an inline name field with a memory-leaking TextEditingController but no
  dedicated profile edit flow.

  Device Linking / QR Scanner — Gen 3 had device_linking_page.dart (191 lines): animated gradient background, _SesameMaskClipper (CustomClipper with
  PathFillType.evenOdd) punching a clear 250px viewing window, tap-to-simulate handshake with rose flash. The new settings has a static Icons.qr_code_scanner
  that says "VIEWFINDER ACTIVE" but is inert.

  Appearance / Theme Settings — user_menu.dart has "Appearance (Plasma Engine)" as a menu item with onTap: () {}. No settings page exists for appearance, dark
   mode toggle, or plasma configuration.

  ---
  AUTH

  Real OTP Flow UI — Gen 3's auth (489 lines) had: invisible TextField layered under typographic digit display, RichText rendering each of 6 digits as
  hero-style with center dot for empty, heavyImpact haptic on 6th digit, blur+fade AnimatedSwitcher between steps, loading spinner during verification. The
  new auth (189 lines) has a basic TextField with obscureText: true and no visual polish. The visual delta between the old and new OTP entry is enormous.

  Welcome Screen / Splash — React had WelcomeScreen.tsx (150 lines): animated brand splash with liquid-fire text, tap to begin. Gen 3 showed a brand reveal
  before the phone entry. The new auth starts directly at a phone field with no brand moment.

  ---
  ERRORS AND FEEDBACK

  Error Card — Compile Fix — error_card.dart uses HelloColors.surfaceChrome which doesn't exist. Needs to be replaced with a valid token (HelloColors.recessed
   or HelloColors.surfaceDeep).

  Empty States — No page in the app has an empty state. When a list is empty (no DMs, no groups, no decisions, first install), the user sees blank space. Gen
  3's explore tab had a centered icon + copy empty state. Every list page needs one.

  Loading States / Shimmers — No page has a loading skeleton. When providers eventually return async data, the transition from nothing to populated list will
  be a jarring pop-in. Shimmer placeholders should exist for: conversation list, feed grid, plans view, explore grid.

  ---
  GLOBAL / SYSTEM-WIDE

  BottomBar Restoration — bottom_bar.dart (291 lines) is fully implemented with real TextField, plasma buttons, tab chip, mic/send morph. It is commented out
  in decision_board_page.dart. It needs to be uncommented and mounted in the scaffold. Without it there is no tab switcher, no search access, no compose
  button, and no visible way to navigate tabs except swiping.

  Haptic Feedback — Everywhere — Gen 3 used HapticFeedback.lightImpact() on votes, heavyImpact() on consensus and send, selectionClick() on category/event
  selection, mediumImpact() on long press. The new code imports HapticFeedback nowhere. Zero tactile feedback on any interaction.

  Semantics / Accessibility — Zero Semantics widgets across all ~65 files. Every interactive element is invisible to VoiceOver/TalkBack. Not a visual
  component per se, but Apple App Store review will reject without basic accessibility.

  Spring Curves Library — Gen 3 had spring_curves.dart (55 lines): parameterized SpringCurve extends Curve with presets (bouncy, snappy, gentle, heavy) and an
   extension method animateWithSpring(). The new app/lib/physics/ directory has only portal_page_route.dart. Every file that needs springs
  (liquid_intent_handle.dart, _card_shell.dart, chat_bubble.dart) hardcodes SpringSimulation inline instead of using shared presets.

  LedgerPill Widget — React had LedgerPill.tsx (100 lines): a compact settlement pill ("You owe $120" / "Sarah owes you $80") for use in chat, feed cards, and
   group headers. The new settlement_card.dart renders settlement info but there is no compact inline pill variant for embedding elsewhere.

  Space Picker / Multi-Group Dropdown — React had SpacePicker.tsx (130 lines): dropdown for choosing which group to add an item to. Used in discovery detail
  sheet and AI panel. No equivalent.

  ---
  CROSS-CUTTING FIXES NEEDED

  17 no-bold violations across 7 files need all weights changed to w400 or lighter.

  5+ dark-theme-on-light-theme files need color migration (device_listing, feedback_sheet, explore_tab, group_media_gallery, plus scattered Colors.white
  references).

  Deprecated API cleanup: withOpacity() → withValues(alpha:) in dm_sheet, group_sheet, home_page, group_expense_page, and others. withAlpha(int) →
  withValues(alpha: double) in dm_page, group_page, plans_view.

  Wrong brand name "xark" in auth_flow_page and group_chat_page. Replace with "hello".

  Deprecated terminology: "Sanctuary" (→ dm), "The Summoning" (→ invite/create group), "spatial plane" (→ group), "the Void" (undefined).

  5 duplicate _displayName() implementations need extraction to a shared utility.

  2 copies of _SheetShell (dm_sheet + group_sheet, 89% identical) need extraction to one shared widget.

  3 copies of _MockMessage class need consolidation.

  ---
  That is the complete list. Every missing UI component, every visual gap, every fix needed, mapped against what existed before and what exists now.