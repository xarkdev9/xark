# Chromatic Atmosphere — Living Surface System

**Date:** 2026-04-14
**Scope:** Global content-responsive ambient color system. Replaces `AmbientMesh` (kind-driven) with `ChromaticAtmosphere` (content-palette-driven). Every screen in the app breathes with the content in focus.
**Reference aesthetic:** Apple Music "Now Playing" + iOS Lock Screen media player.
**Outcome:** Open Sarah's DM → screen bathes in her personal color. Swipe to a beach photo → warm amber atmosphere. Tap a snow trip → alpine blue. Like the app is alive.
**Hard constraint:** The 3-second rule (apr14.md) wins every conflict. No atmospheric decision is permitted to reduce content readability or action visibility below threshold.

---

## Part 0: The Three-Second Rule Is Non-Negotiable

Steve Jobs' critique was clear: *"Density is respect for the user's time. Every screen must allow the user to take a meaningful action within 3 seconds of seeing it. Not understand — ACT."*

This spec bakes the 3-second rule into the atmosphere system at six enforcement points. Any proposed change that violates one is rejected, even if it looks better.

**Enforcement 1 — Adaptive Card Surface**
The card's glass fill opacity increases as atmosphere saturation increases. A vibrant beach-photo atmosphere forces cards to `HelloGlass.curtainFill` (90% white) to preserve readability. Cards do not get muddy. Ever.

**Enforcement 2 — Plasma CTAs Are Sacred**
Every `PlasmaFill` button (send, vote, submit, CTA pills) renders with full plasma gradient regardless of atmosphere. Actions always cut through.

**Enforcement 3 — Focus Elevation**
The centered/active card gets +5% surface opacity plus a soft `BoxShadow(blurRadius: 24, color: Colors.black12)`. This visually lifts the actionable target above the ambient field.

**Enforcement 4 — Scan-Density Override**
On list pages with >5 visible items, atmosphere saturation is multiplied by 0.6. Dense pages stay scannable. On single-content detail pages, atmosphere runs at 1.0.

**Enforcement 5 — Non-Blocking Transitions**
Route transitions run in parallel with atmosphere cross-fade. Touch input is never blocked by animation. Tap-through is instant.

**Enforcement 6 — Debounced Focus**
The atmosphere only follows content that's been centered for **300ms**. Fast scrolling does not strobe the background. The atmosphere settles when the user settles.

These six rules are the spine of the spec. Every later decision references back to them.

---

## Part 1: Vision

Every piece of content in hello carries a color identity. The app's background — full-bleed, edge-to-edge, on every screen — continuously reflects whatever the user is currently looking at.

- Home feed: atmosphere shifts as the user scrolls, following the centered card's palette
- DM page: Sarah's chat opens in her signature violet; Alex's opens in teal
- Group page: the family group is warm amber; the travel crew is ocean
- Decision page: a hotel with a beach photo fills the screen with ocean blues
- Trip page: immersive trip-wide atmosphere extracted from the hero photo
- Between screens: colors cross-fade smoothly — never a hard cut

The system is *ambient intelligence*. It whispers rather than shouts. The user does not think "the colors changed." The user thinks "this app feels alive."

**What this is not:**
- Not a skin system. Users do not pick colors.
- Not a theme. Light/dark modes are orthogonal and both supported.
- Not decoration. Every color choice is derived from content the user created or received.
- Not a performance burden. Runs at 120fps floor. Shared animation controllers. Palette extraction in background isolate. Aggressive caching.

---

## Part 2: Principles (Non-Negotiable)

1. **The 3-second rule wins.** See Part 0. Six enforcement points. No exceptions.
2. **Full-bleed, moderate saturation.** Entire viewport. ~40% saturation. Never neon. Never muddy. Apple Lock Screen intensity.
3. **Content is color.** Every photo extracts a palette. Every person has a signature. Every kind has a fallback. No content is without color identity.
4. **Cross-fade, never cut.** 800ms `easeInOutCubic` on every palette change. Sync'd with navigation transitions.
5. **Debounced focus.** 300ms settle threshold. No disco during scroll.
6. **Reduced motion respected.** Static atmosphere + snap cross-fades when OS setting is on.
7. **Accessible contrast.** Every text/surface combination passes WCAG AA (4.5:1 for body, 3:1 for large) under any possible atmosphere.
8. **No new landmines.** Never exceed `HelloGlass.curtainSigma` (24). Never blur inside Hero/PageView/TabBarView transitions.

---

## Part 3: Core Concepts

### AmbientPalette (data model)

```dart
class AmbientPalette {
  final Color dominant;     // most-present color in the source
  final Color vibrant;      // saturated hero accent
  final Color muted;        // desaturated background tone
  final Color lightAccent;  // lighter tonal variant
  final Color darkAccent;   // darker tonal variant

  double get averageSaturation; // 0.0 to 1.0, mean HSL S across all colors
  double get averageLightness;  // 0.0 to 1.0, mean HSL L

  static AmbientPalette lerp(AmbientPalette a, AmbientPalette b, double t);
  static AmbientPalette neutral; // fallback for edge cases
}
```

Every content item produces exactly one `AmbientPalette`. Palettes are cached by source identifier.

### ambientPaletteProvider

A global `StateProvider<AmbientPalette>` that every screen's atmosphere renderer watches. Written to by the focus tracker with debouncing. When it emits, the atmosphere cross-fades.

### ChromaticAtmosphere (widget)

Full-bleed background renderer. Positioned at the root of every screen's Scaffold body. Watches `ambientPaletteProvider`, renders a 5-circle radial gradient composition with subtle drift, cross-fades on palette change.

Replaces the existing `AmbientMesh` widget.

### FocusSource stack

A stack of active focus sources. The top of the stack drives the atmosphere. Operations: `push`, `pop`, `update`.

Priority (higher wins):
- 100 — Sheets / modals
- 50 — Detail pages (DM, Group, Decision, Trip, Settlement, Itinerary)
- 10 — Tab pages with centered content
- 1 — Tab signature color fallback

When a sheet opens over a detail page, the sheet's content drives the atmosphere. When dismissed, the detail page's atmosphere returns.

---

## Part 4: Color Source — Three-Path Resolution

Every content item resolves to a palette via one of three paths, priority order.

### Path A — Photo Extraction

**When:** Item has an associated photo (decision item with photoUrl, trip with heroPhoto, memory with photoUrl, conversation with avatar, etc.).

**Package:** `palette_generator: ^0.3.3+4` — official Flutter package, maintained by the flutter.dev team.

**Asset images (pre-compute at build time):**
A Dart script `scripts/precompute_palettes.dart` scans:
- `app/assets/decide/`
- `app/assets/memories/`
- `app/assets/images/` (if present)

For each image, extracts a 5-color palette and writes `app/assets/palettes.json`:

```json
{
  "decide/bali_beach.jpg": {
    "dominant": "#1a6b8f",
    "vibrant": "#e8b844",
    "muted": "#6b5a3d",
    "lightAccent": "#a3c8d6",
    "darkAccent": "#0d3a4e"
  },
  "decide/bali_flight_ga.jpg": { ... },
  ...
}
```

The manifest is bundled in the app binary. On startup, `PaletteExtractor.load()` reads it into memory once. Asset palette lookup is O(1) thereafter. **Zero runtime extraction cost for any pre-shipped asset.**

Run the script manually: `dart run scripts/precompute_palettes.dart`
CI hook (future): run on every asset change. For now, manual trigger.

**Network images (runtime extraction — main isolate with downscale):**

⚠ **`dart:ui` objects cannot cross isolate boundaries.** Attempting to send an `ImageProvider` or `dart:ui.Image` across isolates throws `Illegal argument in isolate message`. Extraction MUST run on the main isolate.

Protection against frame drops and RAM spikes comes from aggressive downscaling via `ResizeImage`. A 100×100 thumbnail extracts 5 colors in <5ms — indistinguishable from a 4K image's palette, but 1,600× less memory.

```dart
Future<AmbientPalette> extract(String url) async {
  final provider = ResizeImage(NetworkImage(url), width: 100, height: 100);
  final generator = await PaletteGenerator.fromImageProvider(provider);
  return AmbientPalette.fromGenerator(generator);
}
```

While extraction runs, the item displays with its **kind-token fallback palette** (Path C). When extraction completes (~5-20ms on main isolate with downscale), the palette cross-fades to the real one.

Extracted palettes are cached via `shared_preferences` as `Map<String, AmbientPalette>` (JSON-encoded hex colors), keyed by URL. Max 500 entries, LRU eviction. Cache survives app restarts.

**Never** call `PaletteGenerator.fromImage()` with a `dart:ui.Image` across isolate boundaries. **Always** use `fromImageProvider()` with `ResizeImage` on the main isolate.

### Path B — Signature Color

**When:** Item has no photo but has a stable identifier (userId, groupId).

Deterministic hash → perceptually uniform hue assignment. Stable across platforms (CRC32 of UTF-8 bytes, not Dart's unstable `String.hashCode`).

⚠ **HSL is mathematically uniform but optically flawed.** `HSL(60°, 0.55, 0.55)` (yellow) is blinding. `HSL(240°, 0.55, 0.55)` (blue) is muddy-dark. Same numeric saturation+lightness, wildly different perceived brightness.

**Fix:** Generate signatures in **Oklch** (Oklab in polar coordinates) — a perceptually uniform color space. At the same L (lightness), every hue has the same *perceived* visual weight. Every user's signature palette feels balanced regardless of where they land on the wheel.

```dart
AmbientPalette signaturePalette(String identifier) {
  final bytes = utf8.encode(identifier);
  final crc = Crc32().convert(bytes).toInt();
  final hueRadians = (crc % 360).toDouble() * (math.pi / 180);
  
  Color oklch(double l, double c, double h) => Oklch(l: l, c: c, h: h).toColor();
  
  return AmbientPalette(
    dominant:    oklch(0.65, 0.12, hueRadians),
    vibrant:     oklch(0.72, 0.15, hueRadians),
    muted:       oklch(0.65, 0.06, hueRadians),
    lightAccent: oklch(0.85, 0.09, hueRadians),
    darkAccent:  oklch(0.45, 0.10, hueRadians),
  );
}
```

**Oklch parameters:**
- L (lightness): 0.0 (black) to 1.0 (white). Perceptually linear.
- C (chroma): 0.0 (gray) to ~0.4 (maximum displayable). Perceptually linear saturation.
- h (hue): 0 to 2π radians.

**Oklch → sRGB conversion:** Pure Dart implementation (~30 lines). Standard math from the Oklab specification (Björn Ottosson, 2020). No external package required, but can use `oklab` or `color_space` package if preferred.

```dart
// Reference: https://bottosson.github.io/posts/oklab/
class Oklch {
  final double l, c, h;
  const Oklch({required this.l, required this.c, required this.h});
  
  Color toColor() {
    // Oklch → Oklab
    final a = c * math.cos(h);
    final b = c * math.sin(h);
    
    // Oklab → linear sRGB
    final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = l - 0.0894841775 * a - 1.2914855480 * b;
    
    final lCubed = l_ * l_ * l_;
    final mCubed = m_ * m_ * m_;
    final sCubed = s_ * s_ * s_;
    
    final r = 4.0767416621 * lCubed - 3.3077115913 * mCubed + 0.2309699292 * sCubed;
    final g = -1.2684380046 * lCubed + 2.6097574011 * mCubed - 0.3413193965 * sCubed;
    final bl = -0.0041960863 * lCubed - 0.7034186147 * mCubed + 1.7076147010 * sCubed;
    
    // Linear → sRGB gamma
    double gamma(double x) => x <= 0.0031308 ? 12.92 * x : 1.055 * math.pow(x, 1 / 2.4) - 0.055;
    
    return Color.from(
      alpha: 1.0,
      red: gamma(r).clamp(0.0, 1.0),
      green: gamma(g).clamp(0.0, 1.0),
      blue: gamma(bl).clamp(0.0, 1.0),
    );
  }
}
```

Every person ("me", "sarah", "alex", "maya") gets a unique hue on the wheel — and every signature has **equal perceived brightness and saturation**. Yellow-Sarah and Blue-Alex look equally vibrant, never one blinding and the other muddy.

Dependencies: `crclib: ^3.0.0` (CRC32 hash). Oklch conversion is pure Dart — no dependency required.

### Path C — Kind Token

**When:** No photo, no personal identifier. Fallback.

Uses existing `HelloColors.kind*` tokens. Each kind pre-computes a 5-color palette derived from the kind's base color:

```dart
const Map<String, AmbientPalette> kindPalettes = {
  'dm':         AmbientPalette.fromBaseColor(HelloColors.kindDm),
  'group':      AmbientPalette.fromBaseColor(HelloColors.kindGroup),
  'decision':   AmbientPalette.fromBaseColor(HelloColors.kindDecision),
  'settlement': AmbientPalette.fromBaseColor(HelloColors.kindSettlement),
  'itinerary':  AmbientPalette.fromBaseColor(HelloColors.kindItinerary),
  'memory':     AmbientPalette.fromBaseColor(HelloColors.kindMemory),
  'ai':         AmbientPalette.fromBaseColor(HelloColors.kindAiNudge),
};
```

`AmbientPalette.fromBaseColor(Color base)` produces a 5-color palette by varying the HSL S and L around the base color.

### Resolution Logic

```dart
Future<AmbientPalette> resolvePalette(ContentItem item) async {
  if (item.photoUrl != null) {
    return await PaletteExtractor.extract(item.photoUrl!);
  }
  if (item.signatureId != null) {
    return signaturePalette(item.signatureId!);
  }
  return kindPalettes[item.kind] ?? AmbientPalette.neutral;
}
```

`ContentItem` is a thin adapter. Existing models (`DecisionItem`, `Conversation`, `Trip`, `Settlement`) implement a `get photoUrl`, `get signatureId`, `get kind` or are wrapped by an adapter.

---

## Part 5: Focus Tracking

### focusSourcesProvider

```dart
class FocusSource {
  final String id;
  final AmbientPalette palette;
  final int priority;
}

final focusSourcesProvider = StateNotifierProvider<FocusSourceStack, List<FocusSource>>(...);

class FocusSourceStack extends StateNotifier<List<FocusSource>> {
  FocusSourceStack() : super(const []);
  
  void push(FocusSource source) {
    state = [...state, source]..sort((a, b) => b.priority.compareTo(a.priority));
  }
  
  void pop(String id) {
    state = state.where((s) => s.id != id).toList();
  }
  
  void update(String id, AmbientPalette palette) {
    state = [
      for (final s in state) s.id == id ? FocusSource(id: id, palette: palette, priority: s.priority) : s
    ];
  }
  
  AmbientPalette get activePalette =>
      state.isEmpty ? AmbientPalette.neutral : state.first.palette;
}
```

### ambientPaletteProvider (derived)

```dart
final ambientPaletteProvider = Provider<AmbientPalette>((ref) {
  final sources = ref.watch(focusSourcesProvider);
  return sources.isEmpty ? AmbientPalette.neutral : sources.first.palette;
});
```

Because the stack is already sorted by priority, the first element is the winner.

### Route-Animation-Driven Transitions (Swipe-Back Fix)

⚠ `dispose()` is called AFTER the dismissal animation completes. If a user slowly swipes back from Sarah's violet DM, the background would stubbornly stay 100% violet during the entire swipe, then snap to home's color at the end. Dead giveaway that the colors are fake. Breaks the Apple "Now Playing" dismissal illusion.

**Fix:** Detail-page focus sources bind to their `ModalRoute.animation`. The `ambientPaletteProvider` lerps the top two sources by the route's animation value — so the atmosphere cross-fades with the user's finger during an edge-swipe-back.

```dart
class FocusSource {
  final String id;
  final AmbientPalette palette;
  final int priority;
  final Animation<double>? routeAnimation; // if non-null, drives cross-fade progress
}
```

### Updated derivation

```dart
final ambientPaletteProvider = Provider<AmbientPalette>((ref) {
  final sources = ref.watch(focusSourcesProvider);
  if (sources.isEmpty) return AmbientPalette.neutral;
  if (sources.length == 1) return sources.first.palette;
  
  final top = sources.first;
  final under = sources[1];
  
  // If the top source has a route animation, lerp between under and top
  // based on the route's progress. 1.0 = fully on top's page. 0.0 = dismissed.
  if (top.routeAnimation != null) {
    final t = top.routeAnimation!.value;
    return AmbientPalette.lerp(under.palette, top.palette, t);
  }
  
  return top.palette;
});
```

The provider must be re-evaluated on each animation tick. Implementation:

```dart
// Inside DmPage state:
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final routeAnim = ModalRoute.of(context)?.animation;
  if (routeAnim != null && !_pushed) {
    _pushed = true;
    ref.read(focusSourcesProvider.notifier).push(FocusSource(
      id: 'dm_${widget.peer.id}',
      palette: resolvePalette(widget.peer),
      priority: 50,
      routeAnimation: routeAnim,
    ));
    // Listen to animation and trigger provider re-evaluation
    routeAnim.addListener(_onRouteTick);
  }
}

void _onRouteTick() {
  // Force focusSourcesProvider to re-emit so ambientPaletteProvider
  // recomputes the lerp with the new animation value.
  // Cheapest way: notifier.touch() — a no-op state update that triggers rebuild.
  ref.read(focusSourcesProvider.notifier).touch();
}

@override
void dispose() {
  ModalRoute.of(context)?.animation?.removeListener(_onRouteTick);
  ref.read(focusSourcesProvider.notifier).pop('dm_${widget.peer.id}');
  super.dispose();
}
```

Result: edge-swipe-back feels like Apple "Now Playing" dismissal. The violet atmosphere retreats as the user's finger drags, revealing the home feed's atmosphere underneath in perfect 1:1 fluidity.

**Performance:** The route animation ticks at 60-120fps during the gesture. Each tick triggers one provider rebuild + one `ChromaticAtmosphere` repaint. The atmosphere is wrapped in `RepaintBoundary`, so only the atmosphere repaints — content doesn't. Well within frame budget.

### Per-Screen Wiring

| Screen | Focus source | Behavior | Priority |
|---|---|---|---|
| HomePage | `centeredFeedItemIdProvider` → resolve item → palette | Debounced 300ms; push once on mount, `update()` on each stable center change | 10 |
| ChatsPage | Tab signature (violet) | Static while idle; on row hover/tap preview, lerp toward that row's palette before pushing to DM page | 1 |
| GroupsPage | Tab signature (orange) | Same pattern | 1 |
| PlansPage | Centered feed item or focus trip | Debounced 300ms | 10 |
| DmPage | Peer's palette (Path B via peer userId, or Path A via avatar if exists) | Push on `initState`, pop on `dispose` | 50 |
| GroupPage | Group's palette | Push on `initState`, pop on `dispose` | 50 |
| DecisionPage | Decision item's palette | Push on `initState`, pop on `dispose` | 50 |
| TripPage | Trip's palette (Path A from hero photo) | Push on `initState`, pop on `dispose` | 50 |
| SettlementPage | kindSettlement palette | Static while on page | 50 |
| ItineraryPage | Parent trip's palette | Push on `initState`, pop on `dispose` | 50 |
| AnySheet | Sheet's content palette | Push on open, pop on close | 100 |
| Settings pages | None (returns to canvas default) | No push — stack is empty → `AmbientPalette.neutral` shows | — |
| Auth flow | None — stack is empty | Neutral canvas before user has content | — |

### Debouncing on HomePage / PlansPage

Fast scrolling fires `centeredFeedItemIdProvider` rapidly. Without debounce, the atmosphere would strobe.

```dart
Timer? _focusDebounce;
ref.listen(centeredFeedItemIdProvider, (_, next) {
  _focusDebounce?.cancel();
  _focusDebounce = Timer(const Duration(milliseconds: 300), () async {
    if (!mounted) return;
    final item = findItemById(next);
    if (item == null) return;
    final palette = await resolvePalette(item);
    ref.read(focusSourcesProvider.notifier).update('home_feed', palette);
  });
});
```

---

## Part 6: Atmosphere Renderer — `ChromaticAtmosphere` Widget

Full-bleed. Replaces `AmbientMesh`. One instance per Scaffold body.

### Structure

```dart
class ChromaticAtmosphere extends ConsumerStatefulWidget {
  const ChromaticAtmosphere({super.key});
  // No child — this is a background layer. Stack it below content.
}

class _ChromaticAtmosphereState extends ConsumerState<ChromaticAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;
  AmbientPalette? _current;
  AmbientPalette? _previous;
  double _crossfadeT = 1.0;
  
  @override
  void initState() {
    super.initState();
    _drift = AnimationController(vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
  }
  
  // On palette change: animate _crossfadeT from 0 to 1 over 800ms easeInOutCubic
  // During animation, render lerp(previous, current, _crossfadeT)
  // After animation, _previous becomes _current, _crossfadeT resets to 1.0
}
```

### Composition

```dart
Widget build(BuildContext context) {
  final palette = _crossfadeT >= 1.0
      ? _current!
      : AmbientPalette.lerp(_previous!, _current!, _crossfadeT);
  
  final saturationMultiplier = _densityModeMultiplier(context); // 0.6 on list pages, 1.0 on detail
  
  return RepaintBoundary(
    child: Stack(
      fit: StackFit.expand,
      children: [
        // Base canvas (brightness-aware)
        Container(color: HelloColors.canvas),
        
        // 5 radial gradients — one per palette color
        for (var i = 0; i < 5; i++)
          AnimatedBuilder(
            animation: _drift,
            builder: (context, _) {
              final colors = [
                palette.dominant, palette.vibrant, palette.muted,
                palette.lightAccent, palette.darkAccent,
              ];
              final center = _driftedCenter(i, _drift.value);
              return Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: center,
                      radius: 0.9,
                      colors: [
                        colors[i].withValues(alpha: 0.40 * saturationMultiplier),
                        colors[i].withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    ),
  );
}
```

**No BackdropFilter on the atmosphere itself.** The radial gradients with soft alpha stops produce the "atmospheric blur" feel naturally. Eliminates all `BackdropFilter` performance concerns for this system.

### Drift Animation

`_driftedCenter(int index, double t)` returns an `Alignment` that slowly pans on a 20-second cycle. Each of the 5 circles has a distinct drift pattern (phase offsets of 72°) so they cross-circulate. Subtle — motion is barely perceptible.

```dart
Alignment _driftedCenter(int index, double t) {
  final phase = t * 2 * math.pi + index * (2 * math.pi / 5);
  final baseX = [-0.5, 0.3, 0.7, -0.2, 0.0][index];
  final baseY = [-0.3, -0.5, 0.2, 0.5, 0.1][index];
  return Alignment(
    baseX + 0.2 * math.sin(phase),
    baseY + 0.2 * math.cos(phase * 0.7),
  );
}
```

### Idle Sleep (Battery Protection)

⚠ An infinitely-repeating animation forces the GPU to recomposite the atmosphere at 60/120Hz forever — even while the user is reading static text. This drains battery and heats the device.

**Rule:** The UI rests when the user rests. The drift controller pauses after 3 seconds of no user activity and resumes instantly on touch.

```dart
class _ChromaticAtmosphereState extends ConsumerState<ChromaticAtmosphere>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _drift;
  Timer? _idleTimer;
  
  @override
  void initState() {
    super.initState();
    _drift = AnimationController(vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
    WidgetsBinding.instance.addObserver(this);
    _armIdleTimer();
  }
  
  void _armIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _drift.stop();
    });
  }
  
  void _onUserActivity() {
    if (!_drift.isAnimating) _drift.repeat();
    _armIdleTimer();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _drift.stop();
      _idleTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _drift.repeat();
      _armIdleTimer();
    }
  }
  
  // Wrap the Scaffold in Listener + NotificationListener<ScrollNotification>
  // Call _onUserActivity() on pointer down / scroll start.
}
```

**What counts as activity:**
- `Listener.onPointerDown` (any tap/swipe anywhere on screen)
- `NotificationListener<ScrollNotification>` (any list scroll)
- Keyboard input (rare — handled by parent scaffold's focus listener)

**What resumes drift:**
- User activity (touch/scroll/keyboard)
- App returning to foreground (`didChangeAppLifecycleState → resumed`)
- Palette change via `ambientPaletteProvider` (new content = wake up and greet)

**What keeps drift paused:**
- 3s of no input + app in foreground + no palette change
- App backgrounded (always paused)

### Cross-Fade on Palette Change

```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final next = ref.watch(ambientPaletteProvider);
  if (_current == null) {
    _current = next;
    return;
  }
  if (next == _current) return;
  
  _previous = _current;
  _current = next;
  _crossfadeT = 0.0;
  
  final reducedMotion = MediaQuery.disableAnimationsOf(context);
  if (reducedMotion) {
    _crossfadeT = 1.0;
    setState(() {});
    return;
  }
  
  // Animate _crossfadeT from 0 → 1 over 800ms
  // Use TickerProvider + AnimationController or Tween
}
```

### OLED Banding Protection — Dither Noise Overlay

⚠ 5 overlapping mathematical radial gradients produce visible **color banding** (concentric stair-stepping rings) on OLED displays. Every modern iPhone and most Android flagships are OLED. Without dither, the premium atmosphere looks cheap.

**Fix:** A tiny static noise texture overlaid on the entire atmosphere at `BlendMode.overlay` with 1.5% opacity. This dithers the gradients at sub-perceptual level, breaks up the banding, and adds a subtle "frosted glass" texture. Apple uses this technique throughout iOS (Control Center, Notification Center, widget backgrounds).

**Implementation:** A pre-shipped 256×256 PNG noise texture, `app/assets/textures/dither_noise.png`, generated once (plain blue-noise pattern). Rendered as a `DecoratedBox` with `repeat: ImageRepeat.repeat` at the top of the atmosphere Stack.

```dart
// Inside ChromaticAtmosphere Stack, as the LAST child (on top of all gradients):
Positioned.fill(
  child: IgnorePointer(
    child: Opacity(
      opacity: 0.015,
      child: Image.asset(
        'assets/textures/dither_noise.png',
        repeat: ImageRepeat.repeat,
        filterQuality: FilterQuality.none, // preserve noise grain
      ),
    ),
  ),
),
```

Texture generation (one-time, committed to the repo):
```bash
# Using ImageMagick or any noise generator. Blue noise preferred for dither quality.
convert -size 256x256 xc:gray50 +noise Gaussian -blur 0x0.5 app/assets/textures/dither_noise.png
```

**Why 1.5% opacity:** Invisible as a "texture" but sufficient to break gradient banding at the typical viewing distance (~30cm). Any higher and the noise becomes a perceivable stippling. Any lower and banding returns. Validated against iOS system material rendering.

**Cost:** One 256×256 PNG (~5KB bundled). GPU repeats the texture — native cost, no custom shader.

### Density Mode Multiplier (Enforcement 4)

```dart
double _densityModeMultiplier(BuildContext context) {
  final route = ModalRoute.of(context)?.settings.name;
  // Detail pages run full saturation; list pages run 0.6x
  // Determined by route name or widget scope
  return _isListPage(context) ? 0.6 : 1.0;
}
```

List pages are: HomePage, ChatsPage, GroupsPage, PlansPage, any Sheet listing items.
Detail pages are: DmPage, GroupPage, DecisionPage, TripPage, SettlementPage, ItineraryPage.

---

## Part 7: Contrast Protection — Theme-Aware + Luminance-Based

⚠ Two failures must be prevented simultaneously:
1. **Dark Mode Flashbang.** Hardcoding "90% white" breaks dark mode — a white card over saturated darkness blinds the user.
2. **Saturation Trap.** A saturated *navy blue* (dark, low-risk) and a saturated *neon yellow* (blinding, high-risk) both have high saturation but require different defenses.

### Fix 1: Theme-aware surface colors

`AmbientSurfaceTier` does NOT encode absolute colors. It encodes an **opacity level over the active theme's base surface**. In light mode, opacity blends toward white. In dark mode, toward the dark surface (#1C1C1E).

```dart
enum AmbientSurfaceTier { whisper, veil, curtain }

extension AmbientSurfaceTierColors on AmbientSurfaceTier {
  /// Returns the theme-appropriate surface fill for this tier.
  /// Light mode: blends toward white. Dark mode: blends toward #1C1C1E.
  Color get fill {
    final isDark = HelloColors.isDark;
    final baseSurface = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    return switch (this) {
      AmbientSurfaceTier.whisper => baseSurface.withValues(alpha: 0.70),
      AmbientSurfaceTier.veil    => baseSurface.withValues(alpha: 0.80),
      AmbientSurfaceTier.curtain => baseSurface.withValues(alpha: 0.90),
    };
  }
  
  Color get border {
    final isDark = HelloColors.isDark;
    final borderBase = isDark ? Colors.white : Colors.black;
    return switch (this) {
      AmbientSurfaceTier.whisper => borderBase.withValues(alpha: 0.06),
      AmbientSurfaceTier.veil    => borderBase.withValues(alpha: 0.10),
      AmbientSurfaceTier.curtain => borderBase.withValues(alpha: 0.14),
    };
  }
}
```

Result: A saturated beach photo forces **90% of white** in light mode OR **90% of dark-gray** in dark mode — both preserve readability, neither flashbangs the user.

### Fix 2: Luminance-based risk metric (not saturation alone)

The tier is selected by a **combined risk score** that weights both saturation AND luminance distance from the theme's neutral surface.

```dart
final ambientSurfaceTierProvider = Provider<AmbientSurfaceTier>((ref) {
  final palette = ref.watch(ambientPaletteProvider);
  
  // Relative luminance (WCAG 2.1 formula) — averaged across palette.
  final avgLum = palette.averageRelativeLuminance; // 0.0 (black) to 1.0 (white)
  final avgSat = palette.averageSaturation;        // 0.0 to 1.0
  
  // Theme neutral luminance: ~0.95 for #FAFAFA, ~0.01 for #111.
  final themeNeutralLum = HelloColors.isDark ? 0.01 : 0.95;
  
  // How visually different is this palette from the theme's neutral base?
  final luminanceDelta = (avgLum - themeNeutralLum).abs();
  
  // Contrast risk: further from neutral + more saturated = higher risk.
  final risk = (luminanceDelta * 0.6) + (avgSat * 0.4);
  
  if (risk < 0.20) return AmbientSurfaceTier.whisper;
  if (risk < 0.50) return AmbientSurfaceTier.veil;
  return AmbientSurfaceTier.curtain;
});
```

**Why this works:**
- Saturated **navy blue** (low luminance distance from dark theme neutral) → low risk → Whisper. Blue navy + whisper dark card = elegant.
- Saturated **neon yellow** (high luminance distance from ANY theme neutral) → high risk → Curtain. Yellow chaos + 90% surface = readable.
- Muted gray-blue → very low risk → Whisper.
- Vibrant beach orange (high sat, mid lum) → medium risk → Veil.

### WCAG Relative Luminance Formula

```dart
extension RelativeLuminance on Color {
  double get relativeLuminance {
    double channel(int c) {
      final n = c / 255.0;
      return n <= 0.03928 ? n / 12.92 : math.pow((n + 0.055) / 1.055, 2.4).toDouble();
    }
    return 0.2126 * channel((r * 255).round()) +
           0.7152 * channel((g * 255).round()) +
           0.0722 * channel((b * 255).round());
  }
}
```

Every content card reads `ref.watch(ambientSurfaceTierProvider)` and selects its fill/border. Dark mode and saturation chaos both handled in one metric.

### Testing

Golden tests verify: for each of 20 palette samples covering the risk spectrum, in BOTH light and dark themes, body text inside cards maintains ≥4.5:1 contrast ratio (WCAG AA).

---

## Part 8: Scan-Density Override — Concrete Thresholds

Atmosphere saturation is multiplied based on what's on screen:

| Context | Visible items | Multiplier |
|---|---|---|
| HomePage feed | ≥6 | 0.6 |
| HomePage feed | <6 | 1.0 |
| PlansPage grid | ≥6 | 0.6 |
| ChatsPage / GroupsPage list | Any | 0.6 |
| DecisionPage / TripPage / SettlementPage / ItineraryPage / DmPage / GroupPage | — | 1.0 |
| Sheets | — | 1.0 (they're focused attention) |

Implementation: each atmosphere instance reads the "density hint" from its containing screen via an `InheritedWidget` — `AtmosphereDensity.of(context)` returns `AtmosphereDensity.dense` or `AtmosphereDensity.focus`. Screens set this once at the scaffold level.

---

## Part 9: Haptic Choreography — Active Intent Only

⚠ Haptic fatigue is a real failure mode. If the phone "ticks" every time the user casually scrolls and pauses to read, the app shifts from magical to mechanically annoying. **Ambient intelligence whispers. It does not constantly nudge.**

**Rule:** Haptics fire ONLY on explicit user intent. Passive visual changes (atmosphere cross-fading as the user scrolls) get no haptic — the color shift itself IS the feedback.

### Haptic-on vs Haptic-off by trigger

| Palette Change Trigger | Haptic? | Reason |
|---|---|---|
| Passive scroll settle on home feed | ❌ No | User is browsing, not deciding. Visual cross-fade suffices. |
| User taps a DM row → navigate to DmPage | ✅ `HelloHaptic.select()` | Explicit tap. Confirm the transition. |
| User taps a decision card → open DecisionPage | ✅ `HelloHaptic.select()` | Explicit tap. |
| User opens a sheet (add item, search, vote) | ✅ `HelloHaptic.tap()` | Explicit gesture. Sheet existing haptic pattern unchanged. |
| User swipes to switch tabs | ✅ `HelloHaptic.select()` | Explicit gesture. Tabs are an active decision. |
| User swipes back from detail page | ❌ No haptic on gesture start | Gesture itself is the signal; haptic on dismissal would double-signal. Navigation framework handles dismiss haptic. |
| Sheet dismissal auto-closing | ❌ No | User did not act. |
| Palette change from external event (e.g., new decision created by another user via engine stream) | ❌ No | Not user-initiated. Visual cross-fade only. |

**Implementation:** The focus source push/pop methods do NOT fire haptics automatically. The call site fires the haptic as part of the triggering gesture. Keeps control local.

```dart
// Navigating to DM page — haptic fires at the tap site, not in atmosphere code.
onTap: () {
  HelloHaptic.select();
  Navigator.push(context, MaterialPageRoute(builder: (_) => DmPage(peer: ...)));
}
```

This preserves hello's existing haptic model (`HelloHaptic` utility from Night Shift #1 Phase 4) and keeps the atmosphere system silent — it responds to intent, never originates it.

---

## Part 10: Adaptive Text Color (Subtle)

On most screens, text inside cards uses `HelloColors.inkPrimary` (near-black on light theme, near-white on dark theme) and stays readable because the card surface is opaque enough (Enforcement 1).

Edge case: text OUTSIDE cards — on the atmosphere directly — might lose contrast. Example: the TabHeader floating avatar in the top-right sits on bare atmosphere, no card behind.

Solution: screen-level text that sits on bare atmosphere uses `HelloColors.inkPrimary` with a subtle text shadow:

```dart
TextStyle(
  color: HelloColors.inkPrimary,
  shadows: [Shadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 2)],
)
```

The shadow is only applied to text on bare atmosphere — not text inside cards.

---

## Part 11: Reduced Motion

Honors OS / Flutter reduced-motion setting via `MediaQuery.disableAnimationsOf(context)`.

When enabled:
- Drift controller freezes at initial position (no slow-pan)
- Cross-fade becomes a snap (duration: 0)
- Palette still updates — just instantly
- No loss of functionality, only motion

Reduced motion is checked at every build. If the user toggles it during a session, the system responds immediately.

---

## Part 12: Performance Budget

**Target:** 120fps floor on modern devices. No frame drops during passive atmosphere (no scroll, no interaction). Atmosphere should cost ≤2ms per frame.

**Cost sources:**
1. **Drift animation:** 1 `AnimationController` (shared across all mounted atmospheres — but only one is mounted at a time via routing). 60fps tick. Pure math, no expensive ops.
2. **Cross-fade:** Second animation, only during 800ms after palette change. Then zero cost.
3. **Gradient rendering:** 5 radial gradients. Flutter's gradient shader is GPU-accelerated. ~0.5ms on modern devices.
4. **Palette extraction:** Runs in background isolate. Never on the UI thread.
5. **Provider writes:** Max 3x/second via debouncing. Each write triggers ~1 widget rebuild (the atmosphere itself, wrapped in RepaintBoundary).

**Audit checkpoints:**
- Before merge: `flutter run --profile` on a low-end Android (Pixel 3a equivalent). Frame budget over 16.67ms must be zero during passive scroll.
- On every PR touching atmosphere: manual profile review.

---

## Part 13: Build-Time Palette Precomputation

Script: `scripts/precompute_palettes.dart`

```dart
// Pseudocode
void main() async {
  final assetDirs = ['app/assets/decide', 'app/assets/memories', 'app/assets/images'];
  final result = <String, AmbientPalette>{};
  
  for (final dir in assetDirs) {
    for (final image in Glob('$dir/*.{jpg,png,webp}').listSync()) {
      final palette = await PaletteGenerator.fromImageProvider(FileImage(image));
      result[relativePath(image)] = AmbientPalette.fromGenerator(palette);
    }
  }
  
  File('app/assets/palettes.json').writeAsStringSync(jsonEncode(result));
  print('Wrote ${result.length} palettes');
}
```

Trigger: manually via `dart run scripts/precompute_palettes.dart` after asset changes. CI integration deferred.

Output size: ~200 bytes per palette × ~50 images = ~10KB JSON. Ships with the app.

---

## Part 14: Screen Coverage

This spec upgrades atmosphere on every existing screen. Summary:

| Screen | Current | After this spec |
|---|---|---|
| HomePage | `AmbientMesh` lerps tab colors | `ChromaticAtmosphere` reads centered item palette, 300ms debounce, density=0.6 |
| ChatsPage | `AmbientMesh` tab color | `ChromaticAtmosphere` tab fallback, density=0.6 |
| GroupsPage | `AmbientMesh` tab color | `ChromaticAtmosphere` tab fallback, density=0.6 |
| PlansPage | `AmbientMesh` tab color | `ChromaticAtmosphere` plans feed / focus trip palette, density=0.6 |
| DmPage | (none — uses body color) | `ChromaticAtmosphere` peer signature palette (priority 50), density=1.0 |
| GroupPage | (none) | `ChromaticAtmosphere` group palette, density=1.0 |
| DecisionPage | (none) | `ChromaticAtmosphere` item palette, density=1.0 |
| SettlementPage | (none) | `ChromaticAtmosphere` kindSettlement palette, density=1.0 |
| TripPage | (none) | `ChromaticAtmosphere` trip hero palette, density=1.0 |
| ItineraryPage | (none) | `ChromaticAtmosphere` parent trip palette, density=1.0 |
| AuthFlow / Onboarding | (none) | No atmosphere — default canvas |
| Settings / UserMenu | (none) | No atmosphere — default canvas (neutral zone) |

---

## Part 15: File Map

### New files (8)
```
app/lib/providers/ambient_palette_provider.dart
app/lib/providers/focus_sources_provider.dart
app/lib/services/palette_extractor.dart         (main-isolate with ResizeImage downscale)
app/lib/services/signature_color.dart           (Oklch perceptually uniform)
app/lib/services/oklch.dart                     (Oklch → sRGB conversion, pure Dart)
app/lib/views/home/decision_board/chromatic_atmosphere.dart
app/assets/textures/dither_noise.png            (256×256 blue-noise dither overlay)
scripts/precompute_palettes.dart
```

### Modified files (~20)
```
app/pubspec.yaml                                     (add palette_generator, crclib)
app/assets/palettes.json                              (generated — new)
app/lib/theme.dart                                    (AmbientSurfaceTier extension)
app/lib/views/home/decision_board/atmosphere.dart     (replace AmbientMesh body — or deprecate)
app/lib/views/home/decision_board/decision_board_page.dart  (wire ChromaticAtmosphere)
app/lib/views/home/decision_board/pages/home_page.dart      (focus debounce wiring)
app/lib/views/home/decision_board/pages/plans_page.dart     (focus wiring)
app/lib/views/home/decision_board/pages/plans_view.dart     (focus wiring)
app/lib/views/home/decision_board/pages/dm_page.dart        (push/pop focus source)
app/lib/views/home/decision_board/pages/group_page.dart     (push/pop focus source)
app/lib/views/home/decision_board/pages/decision_page.dart  (push/pop focus source)
app/lib/views/home/decision_board/pages/settlement_page.dart (push/pop focus source)
app/lib/views/home/decision_board/pages/trip_page.dart      (push/pop focus source)
app/lib/views/home/decision_board/pages/itinerary_page.dart (push/pop focus source)
app/lib/views/home/decision_board/pages/chats_page.dart     (tab density hint)
app/lib/views/home/decision_board/pages/groups_page.dart    (tab density hint)
app/lib/views/home/decision_board/cards/_card_shell.dart    (read ambientSurfaceTierProvider)
app/lib/views/home/decision_board/sheets/*.dart             (push/pop focus source on open/close — 8 sheets)
```

### Dependencies added
```
palette_generator: ^0.3.3+4
crclib: ^3.0.0  (stable CRC32 across platforms)
```

---

## Part 16: Execution Architecture

6 phases, 4 waves. Estimated 18-22 hours total.

### Wave A — Foundation (parallel, 2 concurrent agents)
- **Phase 1:** `AmbientPalette` model + `signature_color.dart` + `palette_extractor.dart` + `ambient_palette_provider.dart` + `focus_sources_provider.dart`
- **Phase 2:** `scripts/precompute_palettes.dart` + run once → `app/assets/palettes.json` + pubspec updates

### Wave B — Renderer (sequential, depends on Wave A)
- **Phase 3:** `ChromaticAtmosphere` widget (composition + cross-fade + drift + reduced motion)

### Wave C — Wiring (sequential, depends on Wave B)
- **Phase 4:** Replace `AmbientMesh` with `ChromaticAtmosphere` across all tab pages (home, chats, groups, plans) + wire centered-card debounce
- **Phase 5:** Focus push/pop on all detail pages (DM, Group, Decision, Settlement, Trip, Itinerary) + all sheets

### Wave D — Contrast + Polish (sequential, depends on Wave C)
- **Phase 6:** `ambientSurfaceTierProvider` + update all card widgets + haptic choreography + adaptive text shadows + full verification battery

---

## Part 17: Success Criteria

1. `cd app && dart analyze lib/` returns zero new errors
2. `cd app && flutter build web` succeeds
3. `dart run scripts/precompute_palettes.dart` runs in <10 seconds and produces `palettes.json`
4. Home feed: scroll through 5 items with distinct photos → atmosphere cross-fades between their extracted palettes visibly
5. DM page: open conversation with peer "sarah" → within 800ms of the page transition completing, the atmosphere has settled on sarah's signature palette
6. Decision page: open a decision with a beach photo → atmosphere is ocean-toned
7. **Isolate safety:** palette extraction of a network image completes without throwing `Illegal argument in isolate message`. Runs on main isolate with ResizeImage downscale.
8. **WCAG AA — both themes:** body text inside cards over the 20-sample risk spectrum (combinations of saturation + luminance distance), in BOTH light and dark mode, maintains ≥4.5:1 contrast ratio
9. **No dark mode flashbang:** in dark mode, a vibrant photo palette forces cards to ~90% of `#1C1C1E` (dark gray), never a 90% white surface
10. **Idle sleep:** with no touch/scroll for 3 seconds, drift animation pauses. Resumes on first touch. Frame budget drops to zero during idle.
11. **App lifecycle:** backgrounding the app pauses drift. Resumes on foreground.
12. **Swipe-back fluidity:** on iOS edge-swipe-back from a detail page, the atmosphere lerps from detail palette → underlying palette in 1:1 sync with the user's finger. No snap at end.
13. **OLED no banding:** on an OLED device (iPhone 12+ or Pixel 6+), no visible concentric rings in the atmosphere. Dither noise overlay present.
14. **Perceptually uniform signatures:** generate signatures for 20 different userIds. All signatures have equal perceived brightness (no blinding yellows, no muddy blues). Validated against Oklch lightness reference samples.
15. Reduced motion: with OS setting on, zero drift animation, zero cross-fade animation (snap), but palettes still update
16. Fast scroll: drag through 20 feed items in <2 seconds — atmosphere only settles on items that remain centered for ≥300ms (no strobe)
17. Palette cache: second app launch with same assets has zero extraction latency
18. Palette extraction: a network image's palette resolves within 20ms on a mid-range device (due to ResizeImage downscale to 100×100)
19. Frame budget: during passive atmosphere (no drift, no scroll), frame time is <1ms over the `ChromaticAtmosphere` widget (profile mode)
20. **Haptic — active intent only:** scrolling the feed fires zero haptics. Tapping a row fires exactly one `HelloHaptic.select()`. No haptic fatigue.
21. Route transition: navigating from home to DM page plays the route animation and the atmosphere cross-fade in parallel — no sequential jank

---

## Part 18: What This Spec Does NOT Cover (Out of Scope)

- User-customizable color overrides ("I want Sarah's chat to be green, not violet") — future feature
- Dark/light mode auto-adaptation of the atmosphere intensity — current spec works in both, but dark-mode-specific tuning is future
- Video content palette extraction (Apple Music animated artwork style) — future
- CI integration of the precompute script — manual trigger for now
- Multi-user palette averaging for groups ("group color = average of all members' signatures") — future, currently uses group avatar or kindGroup fallback
- Per-individual custom avatars beyond the current asset set — the avatar system itself is unchanged

---

## Appendix A: The 3-Second Rule Re-affirmed

Every design decision in this spec is traceable back to one of the six enforcement points in Part 0. If a future change to this system cannot point to an enforcement point that permits it, the change is rejected.

The atmosphere serves the content. The content serves the user. The user's time is sacred.

This is the Apple 2030 standard.
