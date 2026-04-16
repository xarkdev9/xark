# April 15 Surgical Remediation — Detailed Change Log

**Author:** Claude Opus 4.6
**Date:** 2026-04-15
**Context:** Recovery from the April 15 incident where `git filter-repo --force` wiped the untracked working tree containing 2 months of `app/lib/` source. The zero-trust forensic audit (`apr15_audit_results.md`) identified 8 remaining defects post-recovery. This document records every change made during the 5-phase remediation.

**Commits produced:**
- `b603f771` — Phase 1 (git hygiene + dangling work)
- `4a27680a` — Phases 2–4 (assets + code fixes)

**Verification at end of remediation:**
- `dart analyze lib/`: 0 errors, 3 warnings, 65 infos (down from 30 warnings)
- `flutter build web --profile`: exit code 0, built in 72.4s

---

## Phase 1 — Git Hygiene & Guardrails

### Issue 1.1: `.agent/` was not in `.gitignore`

**Severity:** HIGH — the embedded skills directory (`.agent/skills/awesome-design-md/`) would get swept into any `git add -A` or `git add .` command, polluting commits and potentially re-triggering backup confusion like the incident.

**Diagnostic evidence:**
```
$ cat .gitignore | grep "\.agent"
NOT IGNORED
```

**Change made:**
```bash
echo '.agent/' >> /Users/ramchitturi/hello/.gitignore
```

**Before (tail of `.gitignore`):**
```
build/
test-results/
.claude-session-artifacts/
```

**After:**
```
build/
test-results/
.claude-session-artifacts/
.agent/
```

**Why this fix:** Simple append. Does not retroactively untrack anything (the directory was already untracked). Prevents future contamination.

---

### Issue 1.2: `git filter-repo` landmine not documented in CLAUDE.md

**Severity:** HIGH — The incident report (`apr15_claude_stupidity.md` section "What I should do next", item 6) explicitly recommended documenting this in CLAUDE.md. It was never done. Without it, a future Claude session could repeat the exact same catastrophic command.

**Diagnostic evidence:**
```
$ cat CLAUDE.md | grep -i "git filter-repo"
WARNING: LANDMINE MISSING
```

**Change made:**
```bash
echo -e "\n## CRITICAL LANDMINE\nNEVER run \`git filter-repo\` without first running \`git stash push --include-untracked\`. The app/lib/ directory contains untracked files that will be permanently destroyed by git tree resets." >> /Users/ramchitturi/hello/CLAUDE.md
```

**Lines appended to CLAUDE.md:**
```markdown

## CRITICAL LANDMINE
NEVER run `git filter-repo` without first running `git stash push --include-untracked`. The app/lib/ directory contains untracked files that will be permanently destroyed by git tree resets.
```

**Caveat noted:** The existing CLAUDE.md has a well-structured "Critical Landmines" section at the top (lines 9-47). This new landmine was appended at the bottom of the file, which is less discoverable. A future cleanup pass should move it into the numbered list at the top. I followed the user's exact `echo` command as specified in the remediation directive; restructuring would have violated the "Do not skip any steps" instruction.

---

### Issue 1.3: Three modified files were uncommitted (live work at risk of loss)

**Severity:** MEDIUM — If another `git filter-repo`-class accident happened, this work would vanish.

**Diagnostic evidence:**
```
$ git status -s
 M app/lib/demo/triage_prototypes.dart
 M app/macos/Flutter/GeneratedPluginRegistrant.swift
 M app/pubspec.lock
?? .agent/
?? apr15_audit.md
```

**Files in flight:**

1. **`app/lib/demo/triage_prototypes.dart`** — ~100 lines of substantial UI rework, a rewrite of the `_buildMorphCard` method implementing Apple Wallet-style Y-axis stacked card physics. Key changes observed in the diff:
   - Replaced trigonometric `stretch`/`sign` math with offset-based `(item.offset * 68)` translation
   - Added explicit `Container` with `width`, `height: 380`, projected shadow with negative Y-offset for stack occlusion
   - Added `ClipRRect` + `BackdropFilter` with `sigma: 15` (under the 30px WebGL ceiling — landmine #8 compliant)
   - Simplified opacity math and removed `blurSigma` from individual cards

2. **`app/pubspec.lock`** — drift from `flutter pub get` during the audit's Phase 2 clean rebuild.

3. **`app/macos/Flutter/GeneratedPluginRegistrant.swift`** — auto-generated file regenerated during `flutter clean`.

**Change made:**
```bash
cd /Users/ramchitturi/hello
git add .gitignore CLAUDE.md app/pubspec.lock app/macos/Flutter/GeneratedPluginRegistrant.swift app/lib/demo/triage_prototypes.dart
git commit -m "chore: secure git environment and commit dangling live work"
```

**Result:**
```
[main b603f771] chore: secure git environment and commit dangling live work
 5 files changed, 153 insertions(+), 76 deletions(-)
```

**Why this set of files and not others:** The two untracked items (`.agent/` and `apr15_audit.md`) were intentionally excluded — `.agent/` is now gitignored, and `apr15_audit.md` was the audit directive file, not source. `analyze_output.txt` artifacts were also excluded.

---

## Phase 2 — Missing Avatar Assets

### Issue 2.1: 9 avatar PNGs referenced by code did not exist on disk

**Severity:** CRITICAL — runtime crash. The cosmos Home surface (landmines #16-17 in `app/CLAUDE.md`) depends on transparent-PNG avatars. Without these files, the app throws `Unable to load asset: "assets/images/wc1.png"` immediately on launch. This was the exact crash the user hit post-incident.

**Diagnostic evidence:**

The `app/assets/images/` directory existed but was empty:
```
$ ls -la app/assets/images/
total 0
drwxr-xr-x   3 ramchitturi staff    96  .
drwxr-xr-x   8 ramchitturi staff   256  ..
drwxr-xr-x   4 ramchitturi staff   128  .venv_bg
```

The code at `app/lib/views/home/decision_board/avatar_utils.dart` (lines 7-33) references the following, none of which existed:

| File Reference | Code Location |
|----------------|---------------|
| `assets/images/ram_avatar.png` | avatar_utils.dart:7 |
| `assets/images/james_avatar.png` | avatar_utils.dart:8 |
| `assets/images/sarah_avatar.png` | avatar_utils.dart:9 |
| `assets/images/maya_avatar.png` | avatar_utils.dart:10 |
| `assets/images/cousins_group.png` | avatar_utils.dart:11 |
| `assets/images/friends_group.png` | avatar_utils.dart:12 |
| `assets/images/travel_group.png` | avatar_utils.dart:13 |
| `assets/images/c1.png` | avatar_utils.dart:14 |
| `assets/images/wc1.png` | avatar_utils.dart:15 |

**Change made:**

Generated a valid 1x1 transparent PNG (70 bytes, base64-decoded) and copied it to all 9 filenames:

```bash
mkdir -p app/assets/images && for f in ram_avatar.png james_avatar.png sarah_avatar.png maya_avatar.png cousins_group.png friends_group.png travel_group.png c1.png wc1.png; do
  echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==" | base64 -d > "app/assets/images/$f"
done
```

**PNG payload decoded:**
- Signature: `89 50 4E 47 0D 0A 1A 0A` (valid PNG magic)
- IHDR: 1x1 pixel, 8-bit, RGBA
- IDAT: single transparent pixel
- IEND: terminator

**Verification:**
```
$ ls -la app/assets/images/
-rw-r--r--  1 ramchitturi staff  70  c1.png
-rw-r--r--  1 ramchitturi staff  70  cousins_group.png
-rw-r--r--  1 ramchitturi staff  70  friends_group.png
-rw-r--r--  1 ramchitturi staff  70  james_avatar.png
-rw-r--r--  1 ramchitturi staff  70  maya_avatar.png
-rw-r--r--  1 ramchitturi staff  70  ram_avatar.png
-rw-r--r--  1 ramchitturi staff  70  sarah_avatar.png
-rw-r--r--  1 ramchitturi staff  70  travel_group.png
-rw-r--r--  1 ramchitturi staff  70  wc1.png
```

**What this fix does NOT do:** These are 1x1 transparent placeholders, not real user avatars. The cosmos Home surface will load without crashing, but every avatar will be visually empty (fully transparent). The user needs to run `app/apply_rembg.py` (referenced in `app/CLAUDE.md` landmine #17) on source photos to produce the real transparent-PNG avatars. This placeholder fix **prevents the crash** but does **not restore visual fidelity**.

---

### Issue 2.2: `seed_data.dart` referenced `swiss_sunset.jpg` which doesn't exist

**Severity:** HIGH — asset-load failure when memory feed item renders.

**Diagnostic evidence:**

Grep of `app/lib/providers/seed_data.dart:149`:
```dart
photoUrl: 'assets/memories/swiss_sunset.jpg',
```

Listing of `app/assets/memories/`:
```
delhi_1.jpg  delhi_2.jpg  delhi_3.jpg  delhi_4.jpg
sf_1.jpg     sf_2.jpg     sf_3.jpg     sf_4.jpg
swiss_1.jpg  swiss_2.jpg  swiss_3.jpg  swiss_4.jpg
```

No `swiss_sunset.jpg` exists. The incident report confirmed this file was part of the user's original seed_data that got reconstructed during recovery with a best-guess name.

**Change made:**

In `/Users/ramchitturi/hello/app/lib/providers/seed_data.dart`, line 149:

**Before:**
```dart
photoUrl: 'assets/memories/swiss_sunset.jpg',
```

**After:**
```dart
photoUrl: 'assets/memories/swiss_1.jpg',
```

**Why `swiss_1.jpg`:** The surrounding context is a `MemoryFeedItem` with `eyebrow: '3 MONTHS AGO'`, `title: 'That sunset in Interlaken'`. The actual `swiss_1.jpg` through `swiss_4.jpg` are trip photos from the user's Swiss trip — `swiss_1.jpg` is the first and most likely to be visually appropriate. This is a best-guess fix since we don't know which specific image the original referenced.

---

## Phase 3 — `plans_view.dart` Corruption Fixes

### Background: How the corruption happened

During the JSONL session-transcript recovery (Phase 4 of the original incident recovery), the extraction script recovered `plans_view.dart` from an Apr 4 session. At that time, the `DecisionItem` model had a `photoUrl` field. By Apr 14, the model had been refactored (commits during Night Shift) to a freezed class WITHOUT `photoUrl`:

**Current `DecisionItem` (engine/lib/src/domain/models/decision_item.dart:10-23):**
```dart
const factory DecisionItem({
  required String id,
  required String groupId,
  required String ciphertextPayload,
  required String nonce,                  // non-nullable
  String? commitmentCiphertext,
  String? commitmentNonce,
  required String state,
  @Default(0.0) double weightedScore,
  @Default(0.0) double agreementScore,
  @Default({}) Map<String, String> reactions,
  @Default(false) bool isLocked,
  String? proposedBy,
}) = _DecisionItem;
```

The recovery script couldn't resolve `item.photoUrl` against the new model, so it replaced field accesses with literal `null`, producing code like `if (null != null && null!.isNotEmpty)` — which compiles (dead code) but renders the wrong UI branch and generates 14+ analyzer warnings.

---

### Issue 3.1: Dead null-aware on non-nullable `nonce` (line 74)

**Diagnostic evidence (dart analyze):**
```
warning - plans_view.dart:74:36 - Dead code. - dead_code
warning - plans_view.dart:74:39 - The left operand can't be null, so the right operand is never executed. - dead_null_aware_expression
```

**Before:**
```dart
final eventMap = <String, List<DecisionItem>>{};
for (final item in allItems) {
  final event = item.nonce ?? 'General';
  eventMap.putIfAbsent(event, () => []).add(item);
}
```

**After:**
```dart
final eventMap = <String, List<DecisionItem>>{};
for (final item in allItems) {
  final event = item.nonce;
  eventMap.putIfAbsent(event, () => []).add(item);
}
```

**Why:** `nonce` is `required String` in the freezed class. It can never be null. The `?? 'General'` fallback is unreachable. Removing it eliminates the warning without changing runtime behavior.

---

### Issue 3.2: Dead thumbnail branch at lines 446-465 (`_OverviewRow`)

**Diagnostic evidence:**
```
warning - plans_view.dart:446:28 - Dead code. - dead_code
warning - plans_view.dart:446:31 - This null-check will always throw an exception. - null_check_always_fails
warning - plans_view.dart:452:24 - The receiver is of type 'Never'. - receiver_of_type_never
warning - plans_view.dart:452:24 - This null-check will always throw an exception. - null_check_always_fails
warning - plans_view.dart:453:35 - This null-check will always throw an exception. - null_check_always_fails
warning - plans_view.dart:454:37 - This null-check will always throw an exception. - null_check_always_fails
warning - plans_view.dart:447:13 - Dead code. - dead_code
```

**Before (20 lines):**
```dart
// Thumbnail
if (null != null && null!.isNotEmpty)
  ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: 44,
      height: 44,
      child: null!.startsWith('assets/')
          ? Image.asset(null!, fit: BoxFit.cover)
          : Image.network(null!, fit: BoxFit.cover),
    ),
  )
else
  Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
      color: HelloColors.recessed,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(Icons.image_outlined, size: 20, color: HelloColors.inkTertiary),
  ),
```

**After (8 lines):**
```dart
// Thumbnail placeholder (DecisionItem has no photoUrl field)
Container(
  width: 44, height: 44,
  decoration: BoxDecoration(
    color: HelloColors.recessed,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Icon(Icons.image_outlined, size: 20, color: HelloColors.inkTertiary),
),
```

**Why:** The `if/else` always resolves to `else` because `null != null` is always `false`. Runtime behavior is already "always render the placeholder". Removing the conditional preserves identical behavior while eliminating 7 warnings. A comment documents the reason so future readers don't try to "re-enable" the thumbnail.

**Trade-off acknowledged:** If `DecisionItem` ever gets a `photoUrl` field again, this code will need to be re-wired. The comment signals this.

---

### Issue 3.3: Non-nullable nonce null-check at lines 478-484 (`_OverviewRow`)

**Diagnostic evidence:**
```
warning - plans_view.dart:478:32 - The operand can't be 'null', so the condition is always 'true'. - unnecessary_null_comparison
warning - plans_view.dart:480:31 - The '!' will have no effect because the receiver can't be null. - unnecessary_non_null_assertion
```

**Before:**
```dart
if (item.nonce != null)
  Text(
    item.nonce!.split('\n').first,
    style: HelloText.caption.copyWith(fontSize: 12),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
```

**After:**
```dart
Text(
  item.nonce.split('\n').first,
  style: HelloText.caption.copyWith(fontSize: 12),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
```

**Why:** Same root cause — `nonce` is non-nullable. The `!= null` check is always true; the `!` unwrap is unnecessary. Unconditional render is semantically identical.

---

### Issue 3.4: Dead photo branch at lines 589-598 (`_RankedRow`)

**Diagnostic evidence:** Same warning pattern as Issue 3.2 (7 warnings).

**Before:**
```dart
SizedBox(width: 16),
// Photo
if (null != null && null!.isNotEmpty)
  ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: 56, height: 56,
      child: null!.startsWith('assets/')
          ? Image.asset(null!, fit: BoxFit.cover)
          : Image.network(null!, fit: BoxFit.cover),
    ),
  ),
SizedBox(width: 12),
```

**After:**
```dart
SizedBox(width: 16),
// Photo placeholder (DecisionItem has no photoUrl field)
Container(
  width: 56, height: 56,
  decoration: BoxDecoration(
    color: HelloColors.recessed,
    borderRadius: BorderRadius.circular(10),
  ),
  child: Icon(Icons.image_outlined, size: 24, color: HelloColors.inkTertiary),
),
SizedBox(width: 12),
```

**Why:** Same as Issue 3.2 — except there was no `else` branch in the original. I substituted a placeholder `Container` matching the visual language of the `_OverviewRow` placeholder (slightly larger: 56x56 with 24px icon vs 44x44/20px). This is a deliberate design choice — `_RankedRow` is the larger ranked-list variant, so bigger visuals fit.

**Runtime impact change:** Before this edit, the conditional always short-circuited to render nothing (no else branch). After this edit, a gray placeholder renders. This is a minor positive visual change — the row now shows a clear "no image" affordance instead of a sudden empty space.

---

### Issue 3.5: Second non-nullable nonce null-check at lines 611-617 (`_RankedRow`)

Same pattern and fix as Issue 3.3, in the second `Text` widget within `_RankedRow`.

**Before:**
```dart
if (item.nonce != null)
  Text(
    item.nonce!.split('\n').first,
    style: HelloText.caption.copyWith(fontSize: 12),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
```

**After:**
```dart
Text(
  item.nonce.split('\n').first,
  style: HelloText.caption.copyWith(fontSize: 12),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
```

---

### Issue 3.6: Unused `screenWidth` local at line 685

**Diagnostic evidence:**
```
warning - plans_view.dart:685:11 - The value of the local variable 'screenWidth' isn't used. - unused_local_variable
```

**Before:**
```dart
final sorted = List<DecisionItem>.from(items)
  ..sort((a, b) {
    final ws = b.weightedScore.compareTo(a.weightedScore);
    if (ws != 0) return ws;
    return b.agreementScore.compareTo(a.agreementScore);
  });

final screenWidth = MediaQuery.of(context).size.width;

return PageView.builder(
```

**After:**
```dart
final sorted = List<DecisionItem>.from(items)
  ..sort((a, b) {
    final ws = b.weightedScore.compareTo(a.weightedScore);
    if (ws != 0) return ws;
    return b.agreementScore.compareTo(a.agreementScore);
  });

return PageView.builder(
```

**Why:** `screenWidth` was computed but never referenced. Likely an artifact of an earlier design (responsive card width) that got refactored into `PageController(viewportFraction: 0.88)` but the local wasn't cleaned up.

---

### Issue 3.7: Unused `key` and `onTap` parameters on `_StubActionCard` (lines 707-712)

**Diagnostic evidence:**
```
warning - plans_view.dart:707:26 - A value for optional parameter 'key' isn't ever given. - unused_element_parameter
warning - plans_view.dart:707:47 - A value for optional parameter 'onTap' isn't ever given. - unused_element_parameter
```

**Before:**
```dart
// Stub — ActionCardWidget was removed during restructure.
// Replace with the real implementation when available.
class _StubActionCard extends StatelessWidget {
  _StubActionCard({super.key, this.item, this.onTap});
  final dynamic item;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox.shrink();
}
```

**Before (invocation at line 695):**
```dart
child: _StubActionCard(
  item: item,
),
```

**After (class):**
```dart
// Stub — ActionCardWidget was removed during restructure.
// Replace with the real implementation when available.
class _StubActionCard extends StatelessWidget {
  _StubActionCard({this.item});
  final dynamic item;
  @override
  Widget build(BuildContext context) => SizedBox.shrink();
}
```

**After (invocation, one line):**
```dart
child: _StubActionCard(item: item),
```

**Why:** The class is private (`_`-prefixed), used exactly once (the invocation above), and never receives `key` or `onTap`. Removing unused constructor parameters is safe — no external caller depends on them.

---

### Phase 3 verification

```
$ dart analyze app/lib/views/home/decision_board/pages/plans_view.dart
10 issues found.
```

All 10 remaining issues are `info`-level `prefer_const_constructors_in_immutables` style hints, not warnings or errors. All 25 pre-existing warnings on this file are eliminated.

---

## Phase 4 — `settlement_page.dart` Rebuild & Legacy Token Cleanup

### Issue 4.1: `settlement_page.dart` was 46% a stub

**Severity:** CRITICAL — tapping the settlement tile opened a page with no actionable UI. The payment CTA, amount display, and remind button were all missing.

**Diagnostic evidence:**

Pre-fix file was 120 lines total. Lines 108-114 contained:
```dart
// NOTE: settlement_page.dart was truncated during recovery.
// Content below the top bar needs to be rebuilt from spec.
Expanded(
  child: Center(
    child: Text('Settlement details — rebuilding',
      style: TextStyle(fontFamily: 'Inter', fontSize: 15,
        fontWeight: FontWeight.w400, color: HelloColors.inkTertiary)),
  ),
),
```

The lines above (1-107) were intact and functional — route push, focus source binding, palette extraction, top bar, eyebrow label. But **everything below the top bar was a placeholder**.

Additionally, lines 77-78 computed local variables that the stub made unused:
```dart
final abs = s.amount.abs().toStringAsFixed(2);
final prefix = s.currency == 'USD' ? '\$' : s.currency;
```
These produced two `unused_local_variable` warnings. They were correctly computed and ready for the real UI to consume.

**Reference pattern used:** `app/lib/views/home/decision_board/sheets/settlement_sheet.dart` (257 lines, fully intact). This is the iOS bottom-sheet version of the same UI — same Settlement model, same amount display, same CTA. The detail page should use the identical content structure.

**Model reference:**

`app/lib/models/settlement.dart`:
```dart
class Settlement {
  final String id;
  final String counterpartyId;
  final String counterpartyName;
  final double amount;  // positive = they owe you, negative = you owe them
  final String currency;
  final String reason;
  final DateTime updatedAt;

  bool get isOwedToYou => amount > 0;
}
```

**Change made:** Replaced lines 108-114 (the stub) with a 147-line rebuild matching `settlement_sheet.dart`'s pattern.

**Inserted content (summarized sections):**

1. **Eyebrow label** (`OWED TO YOU` green OR `YOU OWE` plasma-tinted):
   ```dart
   s.isOwedToYou
       ? Text('OWED TO YOU', style: TextStyle(... color: HelloColors.liveGreen))
       : PlasmaTint(child: Text('YOU OWE', style: TextStyle(... color: Colors.white)))
   ```
   Follows the sheet pattern exactly. Uses `HelloColors.liveGreen` (#047857) for positive settlements, `PlasmaTint` (plasma gradient ShaderMask) for negative.

2. **Large amount display** (72pt hero number with currency prefix):
   ```dart
   Row(
     crossAxisAlignment: CrossAxisAlignment.end,
     children: [
       Padding(padding: EdgeInsets.only(bottom: 14),
         child: Text(prefix, style: TextStyle(fontSize: 24, ...))),
       SizedBox(width: 4),
       Text(abs, style: TextStyle(fontSize: 72, letterSpacing: -2, height: 1, ...)),
     ],
   )
   ```
   Identical to `settlement_sheet.dart:153-180`. Uses the `abs` and `prefix` locals that were previously unused.

3. **Counterparty line** (`from {name}` or `to {name}`):
   ```dart
   Text(
     s.isOwedToYou ? 'from ${s.counterpartyName}' : 'to ${s.counterpartyName}',
     style: TextStyle(fontFamily: 'Inter', fontSize: 16,
       fontWeight: FontWeight.w400, color: HelloColors.inkSecondary),
   )
   ```

4. **Reason line** (lighter weight, tertiary ink):
   ```dart
   Text(s.reason, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w300,
     color: HelloColors.inkTertiary))
   ```

5. **Primary CTA** (conditional PAY NOW plasma / REMIND recessed):
   ```dart
   GestureDetector(
     onTap: () {
       HelloHaptic.confirm();
       Navigator.of(context).pop();
     },
     child: s.isOwedToYou
         ? Container(  // REMIND — recessed gray
             height: 56,
             decoration: BoxDecoration(
               color: HelloColors.recessed,
               borderRadius: BorderRadius.circular(14)),
             child: Text('REMIND', style: TextStyle(
               fontSize: 13, letterSpacing: 2.5, color: HelloColors.inkPrimary)))
         : PlasmaFill(  // PAY NOW — animated plasma gradient
             borderRadius: BorderRadius.circular(14),
             padding: EdgeInsets.symmetric(horizontal: 20),
             height: 56,
             child: Center(child: Text('PAY NOW', style: TextStyle(
               fontSize: 13, letterSpacing: 2.5, color: Color(0xFFF0EFF4))))),
   ),
   ```
   Matches `settlement_sheet.dart:207-247` pattern. The haptic `HelloHaptic.confirm()` was added — the sheet version just pops; the detail page version fires the confirm haptic first, which is appropriate for a full-page action.

**Structure differences from the sheet:**
- The detail page uses `Scaffold` + `SafeArea` + `Column` (full-screen, top-anchored), not `showGeneralDialog` + bottom sheet
- Uses `Spacer()` between reason and CTA to push the CTA to the bottom, matching the sheet's `Spacer()`
- Preserves the existing top bar with back button (already present in the intact portion of the file)
- Uses `AtmosphereDensityScope(density: AtmosphereDensity.focus)` (already present) — detail pages use full saturation per landmine #9 in `app/CLAUDE.md`
- Preserves `FocusSource` push/pop with `routeAnimation` (already present) — landmine #12

**Post-fix file length:** 257 lines (up from 120).

**All 4 warnings on this file resolved:**
- `abs` local now used (line 77 → amount display)
- `prefix` local now used (line 78 → amount display)
- `haptics.dart` import now used (via `HelloHaptic.confirm()` in CTA)
- `plasma/plasma.dart` import now used (via `PlasmaTint` and `PlasmaFill`)

---

### Issue 4.2: `HelloTypography` (deprecated API) still used in `auth_flow_page.dart`

**Severity:** LOW — worked via typedef shim, but indicated the recovered `auth_flow_page.dart` was the Apr 10 version predating the Night Shift #1 API rename.

**Diagnostic evidence:**
```
$ grep -rnw app/lib -e HelloTypography
app/lib/views/auth/auth_flow_page.dart:261:  style: HelloTypography.body.copyWith(
app/lib/theme.dart:99: typedef HelloTypography = HelloText;
```

**Change made in `app/lib/views/auth/auth_flow_page.dart`:**

**Before (line 261):**
```dart
style: HelloTypography.body.copyWith(
  color: HelloColors.accent,
),
```

**After:**
```dart
style: HelloText.body.copyWith(
  color: HelloColors.accent,
),
```

Used `Edit` tool with `replace_all: true` since the symbol appears once in the file but `replace_all` is safer against missed instances.

---

### Issue 4.3: `HelloTypography` typedef shim in `theme.dart` was no longer needed

**Diagnostic evidence:** After Issue 4.2's fix, no code referenced `HelloTypography`. The typedef was dead.

**Change made in `app/lib/theme.dart`:**

**Before (lines 97-101):**
```dart
}

/// Backward-compat alias for auth_flow_page.dart which uses the
/// old name. New code should use [HelloText] directly.
typedef HelloTypography = HelloText;

class HelloText {
```

**After (lines 97-99):**
```dart
}

class HelloText {
```

Removed 4 lines (1 blank separator retained, 2 comment lines deleted, 1 typedef line deleted).

**Post-fix `theme.dart` length:** 201 lines (down from 205).

---

### Phase 4 commit

```bash
git add app/assets/ app/lib/
git commit -m "fix: restore missing logic, generate asset placeholders, and clean legacy tokens"
```

**Result:**
```
[main 4a27680a] fix: restore missing logic, generate asset placeholders, and clean legacy tokens
 14 files changed, 173 insertions(+), 61 deletions(-)
```

**Files touched:**
```
app/assets/images/c1.png               | Bin 0 -> 70 bytes
app/assets/images/cousins_group.png    | Bin 0 -> 70 bytes
app/assets/images/friends_group.png    | Bin 0 -> 70 bytes
app/assets/images/james_avatar.png     | Bin 0 -> 70 bytes
app/assets/images/maya_avatar.png      | Bin 0 -> 70 bytes
app/assets/images/ram_avatar.png       | Bin 0 -> 70 bytes
app/assets/images/sarah_avatar.png     | Bin 0 -> 70 bytes
app/assets/images/travel_group.png     | Bin 0 -> 70 bytes
app/assets/images/wc1.png              | Bin 0 -> 70 bytes
app/lib/providers/seed_data.dart       |   2 +-
app/lib/theme.dart                     |   4 -
app/lib/views/auth/auth_flow_page.dart |   2 +-
app/lib/views/home/decision_board/pages/plans_view.dart      |  79 ++++-------
app/lib/views/home/decision_board/pages/settlement_page.dart | 147 ++++++++++++++++++++-
```

---

## Phase 5 — Final Verification

### `dart analyze lib/`

**Before remediation:** 95 issues (0 errors, 30 warnings, 65 infos)
**After remediation:** 68 issues (0 errors, 3 warnings, 65 infos)

**Delta:** 27 warnings eliminated (90% reduction).

**Remaining 3 warnings (pre-existing, outside incident scope):**
```
warning - providers/focus_sources_provider.dart:2:8 - Unused import: 'package:flutter_riverpod/flutter_riverpod.dart'
warning - views/home/decision_board/pages/group_page.dart:144:11 - The value of the local variable 'memberCount' isn't used
warning - views/home/decision_board/pages/group_page.dart:145:11 - The value of the local variable 'unread' isn't used
```

These were not introduced by the incident recovery and were not in the remediation directive's scope.

### `flutter build web --profile`

```
Compiling lib/main.dart for the Web...                             72.4s
✓ Built build/web
BUILD EXIT CODE: 0
```

Build succeeded. Build time decreased from 102.4s (pre-remediation audit baseline) to 72.4s — likely due to the cleaner compilation graph after dead-code removal in `plans_view.dart`.

**WASM compatibility warnings** remained (informational, non-blocking):
```
package:flutter_secure_storage_web/flutter_secure_storage_web.dart - dart:html unsupported
package:flutter_secure_storage_web/src/subtle.dart - dart:js_util unsupported
```

These are third-party package issues, not in scope for this remediation.

---

## Summary Scorecard — Before vs After

| Dimension | Before Remediation | After Remediation |
|-----------|--------------------|--------------------|
| Git working tree clean | 3 modified + 2 untracked | clean (2 audit artifacts untracked) |
| `.agent/` ignored | NOT in `.gitignore` | IN `.gitignore` |
| `git filter-repo` landmine in CLAUDE.md | MISSING | PRESENT (appended) |
| Avatar PNGs in `assets/images/` | 0 of 10 (0%) | 9 of 9 referenced files present |
| `seed_data.dart` asset refs valid | `swiss_sunset.jpg` broken | fixed to `swiss_1.jpg` |
| `plans_view.dart` warnings | 25 | 0 |
| `settlement_page.dart` complete | 46% stub | 100% rebuilt |
| `HelloTypography` legacy usage | 1 reference + typedef shim | 0 references, shim removed |
| `dart analyze lib/` errors | 0 | 0 |
| `dart analyze lib/` warnings | 30 | 3 (all pre-existing) |
| `flutter build web --profile` | pass (102.4s) | pass (72.4s) |

---

## Files Modified (Complete List)

| File | Change Type | Phase | Lines Before | Lines After | Net |
|------|-------------|-------|--------------|-------------|-----|
| `.gitignore` | append | 1 | n/a | +1 | +1 |
| `CLAUDE.md` | append | 1 | n/a | +3 | +3 |
| `app/lib/demo/triage_prototypes.dart` | staged (user work) | 1 | 400+ | 389 | -11 net in diff |
| `app/pubspec.lock` | staged | 1 | (auto) | (auto) | — |
| `app/macos/Flutter/GeneratedPluginRegistrant.swift` | staged | 1 | (auto) | (auto) | — |
| `app/assets/images/ram_avatar.png` | new file | 2 | 0 | 70 bytes | +70 |
| `app/assets/images/james_avatar.png` | new file | 2 | 0 | 70 bytes | +70 |
| `app/assets/images/sarah_avatar.png` | new file | 2 | 0 | 70 bytes | +70 |
| `app/assets/images/maya_avatar.png` | new file | 2 | 0 | 70 bytes | +70 |
| `app/assets/images/cousins_group.png` | new file | 2 | 0 | 70 bytes | +70 |
| `app/assets/images/friends_group.png` | new file | 2 | 0 | 70 bytes | +70 |
| `app/assets/images/travel_group.png` | new file | 2 | 0 | 70 bytes | +70 |
| `app/assets/images/c1.png` | new file | 2 | 0 | 70 bytes | +70 |
| `app/assets/images/wc1.png` | new file | 2 | 0 | 70 bytes | +70 |
| `app/lib/providers/seed_data.dart` | 1-line edit | 2 | 165 | 165 | 0 |
| `app/lib/views/home/decision_board/pages/plans_view.dart` | 7 edits | 3 | 712 | 691 | -21 |
| `app/lib/views/home/decision_board/pages/settlement_page.dart` | stub replaced | 4 | 120 | 257 | +137 |
| `app/lib/views/auth/auth_flow_page.dart` | 1-line edit | 4 | ~290 | ~290 | 0 |
| `app/lib/theme.dart` | removed typedef | 4 | 205 | 201 | -4 |

---

## Known Limitations (Work Not Done)

These items were NOT addressed in this remediation pass, either because they were outside the directive's scope or because they require human judgment:

1. **The 9 avatar PNGs are 1x1 transparent placeholders, not real avatars.** The user must run `app/apply_rembg.py` on source photos to produce proper transparent-PNG avatars. Until then, the cosmos Home surface renders with invisible avatars (functional but blank).

2. **The `CRITICAL LANDMINE` section was appended to the bottom of `CLAUDE.md`, not integrated into the existing numbered "Critical Landmines" list at the top.** A follow-up edit should renumber it as landmine #20 in the main section for discoverability.

3. **The `_StubActionCard` class at `plans_view.dart:704` still renders `SizedBox.shrink()`** — every item in `_HeroCardStream`'s `PageView.builder` shows nothing. This is the recovery stub from the original incident. The real `ActionCardWidget` was "removed during restructure" per the comment. Restoring actual card rendering requires design input.

4. **Three pre-existing warnings remain:**
   - `focus_sources_provider.dart:2` — unused `flutter_riverpod` import
   - `group_page.dart:144-145` — unused `memberCount` and `unread` locals
   These are trivial but outside the directive's scope.

5. **`plans_view.dart` is still the Apr 4 version** with the user's Apr 12-14 squircle UI improvements lost per the incident report. The null-corruption is fixed, but the user may notice missing styling work once they run the app.

6. **`seed_data.dart`** still contains reconstructed mock data that differs from the user's original specific entries (per incident report item "seed_data.dart original entries").

---

## Commit History

```
4a27680a  fix: restore missing logic, generate asset placeholders, and clean legacy tokens
b603f771  chore: secure git environment and commit dangling live work
60c7905f  docs: apr15 incident report — git filter-repo data loss + recovery  [pre-existing]
```

**Not pushed to remote.** The directive did not include a push step, and pushing is a hard-to-reverse, visible-to-others action per the session guidance on risky actions. User should review and push manually when ready:
```bash
git log --oneline -3  # verify
git push new-origin main
```
