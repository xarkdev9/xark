# Post-Recovery Codebase Status Report

**Auditor:** Claude Opus 4.6 (the same model that caused the incident)
**Date:** 2026-04-15
**Mode:** Zero-Trust Forensic Audit — all claims backed by terminal output

---

## 1. Git & Workspace Health

### Working Tree Status: NOT CLEAN

```
 M app/lib/demo/triage_prototypes.dart
 M app/macos/Flutter/GeneratedPluginRegistrant.swift
 M app/pubspec.lock
?? .agent/
?? apr15_audit.md
```

- **3 modified, unstaged files** and **2 untracked items** remain in the working tree
- `triage_prototypes.dart` has substantial uncommitted UI changes (Apple Wallet stack rework — ~100 lines changed). This is live user work at risk of being lost again.
- `pubspec.lock` drift from `flutter pub get`
- `GeneratedPluginRegistrant.swift` auto-generated change

### Dart File Tracking: SAFE

| Metric | Count | Match? |
|--------|-------|--------|
| Physical `.dart` files on disk (`find app/lib`) | 88 | -- |
| Git-tracked `.dart` files (`git ls-files app/lib`) | 88 | YES |

**All 88 Dart source files are tracked.** The nightmare scenario (untracked source) that caused the April 15 incident cannot recur for these files.

### `.agent/` Directory: NOT IGNORED

```
$ cat .gitignore | grep "\.agent"
NOT IGNORED
```

**FAIL.** The incident report (section "What I should do next", item 4) recommended adding `.agent/` to `.gitignore`. This was never done. The `.agent/skills/awesome-design-md/` directory is currently untracked and would get swept into any `git add -A` command.

---

## 2. Asset & Dependency Health

### Dependencies: RESOLVED

`flutter clean && flutter pub get` completed successfully. 37 packages have newer incompatible versions available. 1 package (`palette_generator`) is discontinued. No resolution failures.

### Asset Directories

| Directory | Exists? | Contents |
|-----------|---------|----------|
| `app/assets/decide/` | YES | 52 files (bali, demo, family images) |
| `app/assets/memories/` | YES | 12 files (delhi, sf, swiss images) |
| `app/assets/fonts/` | YES | Inter-Regular.ttf, Inter-Light.ttf |
| `app/assets/textures/` | YES | dither_noise.png |
| `app/assets/palettes.json` | YES | 10,914 bytes |
| **`app/assets/images/`** | **EXISTS BUT EMPTY** | **0 files** |

### Missing Asset References (CRITICAL)

The code in `avatar_utils.dart` (lines 7-33) references **10 avatar/group PNGs** that do not exist on disk:

```
assets/images/ram_avatar.png      — MISSING
assets/images/james_avatar.png    — MISSING
assets/images/sarah_avatar.png    — MISSING
assets/images/maya_avatar.png     — MISSING
assets/images/cousins_group.png   — MISSING
assets/images/friends_group.png   — MISSING
assets/images/travel_group.png    — MISSING
assets/images/c1.png              — MISSING
assets/images/wc1.png             — MISSING
```

**Impact:** The cosmos Home floating-avatar surface (`foreground_avatar.dart`, `queue_row.dart`) depends on these images. The app will render broken image placeholders or throw asset-load errors at runtime for every avatar. This was the exact crash the user hit immediately after the incident: `Unable to load asset: "assets/images/wc1.png"`.

### Intact Asset References

These code-referenced assets exist on disk:
- `assets/palettes.json` — exists (palette_extractor.dart:50)
- `assets/decide/bali_flight_sq.jpg` — exists (seed_data.dart:100)
- `assets/decide/bali_cruise.jpg` — exists (seed_data.dart:107)
- `assets/memories/swiss_sunset.jpg` — NOT found (only swiss_1.jpg through swiss_4.jpg exist in memories/)
- `assets/textures/dither_noise.png` — exists (chromatic_atmosphere.dart:244)

**`swiss_sunset.jpg` is referenced in seed_data.dart:149 but does not exist in `assets/memories/`.** This will cause an asset-load crash when the memory feed item is rendered.

---

## 3. API & Token Drift

### Legacy Token Scan

| Token | Status | Location |
|-------|--------|----------|
| `HelloTypography` | **FOUND** | `auth_flow_page.dart:261` — uses `HelloTypography.body` |
| `HelloTypography` typedef | Present | `theme.dart:99` — `typedef HelloTypography = HelloText;` (compat shim) |
| `successGreen` | CLEAN | Not found |
| `.category` | CLEAN | Not found |
| `HelloText.hero` | CLEAN | Not found |
| `HelloText.hint` | CLEAN | Not found |

**Verdict:** `auth_flow_page.dart` still uses the deprecated `HelloTypography` name. The typedef in `theme.dart:99` prevents a compile error but the code should be updated to use `HelloText` directly. The incident report identified `auth_flow_page.dart` as recovered from an Apr 10 JSONL (older version), which explains the stale API usage.

### Const Safety

| Pattern | Status |
|---------|--------|
| `const.*HelloColors` | CLEAN — 0 matches |
| `const.*HelloText` | CLEAN — 0 matches |

The bulk `const`-stripping from the recovery appears to have worked completely.

---

## 4. Vulnerable Files — Exact State

### Line Counts

| File | Lines | Expected (per incident report) | Delta |
|------|-------|-------------------------------|-------|
| `plans_view.dart` | 712 | 708 (Apr 4 version) | +4 (minor) |
| `settlement_page.dart` | 120 | ~230 (original) | **-110 (46% missing)** |
| `theme.dart` | 205 | ~200 (reconstructed) | +5 |
| `seed_data.dart` | 165 | ~140 (reconstructed) | +25 |

### `settlement_page.dart` — CONFIRMED STUB

The bottom half of the file (lines 108-120) is:

```dart
            // NOTE: settlement_page.dart was truncated during recovery.
            // Content below the top bar needs to be rebuilt from spec.
            Expanded(
              child: Center(
                child: Text('Settlement details — rebuilding', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w400, color: HelloColors.inkTertiary)),
              ),
            ),
```

**Missing content (per incident report):**
- Payment CTA button (Pay Now / Remind)
- Settlement amount display with currency formatting
- Settlement details (who owes whom, breakdown)
- Remind button
- Settlement status indicator
- The `abs` and `prefix` variables computed at lines 77-78 are unused (computed but never rendered — stub replaces the real UI)

**4 analyze warnings** from this file, all symptoms of the stub:
- Unused import: `haptics.dart` (line 9)
- Unused import: `plasma.dart` (line 11)
- Unused local variable: `abs` (line 77)
- Unused local variable: `prefix` (line 78)

### `plans_view.dart` — RECOVERED TO APR 4 VERSION WITH CORRUPTION

**25 of 30 total analyze warnings come from this file.** The recovery introduced literal `null` where variable references (likely `photoUrl` or `item.photoUrl`) should be:

Lines 446-454 (and duplicate at 589-596):
```dart
if (null != null && null!.isNotEmpty)    // always false — dead code
  ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: 44, height: 44,
      child: null!.startsWith('assets/')   // never reached, but corrupted
          ? Image.asset(null!, fit: BoxFit.cover)
          : Image.network(null!, fit: BoxFit.cover),
    ),
  )
```

**Impact:** `null != null` is always `false`, so this is technically dead code (no crash). But the functional consequence is that **thumbnails/photos will NEVER render on the Plans tab** even when items have valid photo URLs. This is a visible regression — plan items will always show the gray placeholder icon instead of their actual images.

Additional issues in `plans_view.dart`:
- Line 74: dead null-aware expression
- Lines 478, 611: unnecessary null comparisons
- Lines 480, 613: unnecessary non-null assertions
- Line 685: unused local variable `screenWidth`
- Lines 695-712: `_StubActionCard` — a stub class replacing deleted `ActionCardWidget`, with unused `key` and `onTap` parameters

**User's custom squircle UI improvements (Apr 12-14) remain permanently lost** per the incident report. This is the Apr 4 JSONL version.

### `theme.dart` — RECONSTRUCTED, FUNCTIONAL

205 lines. Reconstructed from CLAUDE.md token tables during recovery. Contains:
- `HelloColors` with brightness-aware getters (no illegal `const`)
- `HelloText` 8-level scale
- `HelloGlass` 3-tier system
- `HelloThemeMode` enum
- `typedef HelloTypography = HelloText;` backward-compat shim (line 99)

No analyze warnings or errors from this file. Any user customizations beyond what CLAUDE.md documented are lost.

### `seed_data.dart` — RECONSTRUCTED, FUNCTIONAL

165 lines. Contains mock decision items, memory feed items, and AI nudge feed items. References `assets/memories/swiss_sunset.jpg` which does not exist (see Audit 2). The user's original specific mock data choices are lost.

### `git filter-repo` Landmine Documentation: MISSING

```
$ cat CLAUDE.md | grep -i "git filter-repo"
WARNING: LANDMINE MISSING
```

**The incident report (section "What I should do next", item 6) explicitly recommended documenting the filter-repo danger in CLAUDE.md as a landmine.** This was never done. A future Claude session could repeat the exact same mistake.

---

## 5. Build & Analyze Results

### Static Analysis

```
dart analyze lib/
```

| Severity | Count |
|----------|-------|
| **Errors** | **0** |
| Warnings | 30 |
| Infos | 65 |
| **Total** | **95** |

**Warning breakdown by file:**

| File | Warnings | Nature |
|------|----------|--------|
| `plans_view.dart` | 25 | Dead code from `null` corruption, stubs, unused vars |
| `settlement_page.dart` | 4 | Unused imports/vars from truncated stub |
| `group_page.dart` | 2 | Unused local variables |
| `focus_sources_provider.dart` | 1 | Unused import |

**Zero errors. The codebase compiles.** But 25 of 30 warnings trace directly to the recovery damage in `plans_view.dart`.

### Web Build

```
flutter build web --profile
✓ Built build/web                                                  102.4s
Build Exit Code: 0
```

**BUILD SUCCEEDED.** The compilation pipeline is intact. WASM dry-run flagged `flutter_secure_storage_web` for `dart:html`/`dart:js_util` usage (informational, non-blocking).

Font tree-shaking: CupertinoIcons 257KB → 1.4KB (99.4%), MaterialIcons 1.6MB → 9.6KB (99.4%).

---

## 6. Strict Remediation Plan

### CRITICAL (blocks usability)

**1. Add missing avatar images to `app/assets/images/`**
The cosmos Home surface is broken without them. 10 PNG files needed:
- `ram_avatar.png`, `james_avatar.png`, `sarah_avatar.png`, `maya_avatar.png`
- `cousins_group.png`, `friends_group.png`, `travel_group.png`
- `c1.png`, `wc1.png`
- These should be transparent-PNG format (per CLAUDE.md cosmos Home spec: "Transparent-PNG avatars built via `app/apply_rembg.py`")
- Also fix or remove `assets/memories/swiss_sunset.jpg` reference in `seed_data.dart:149`

**2. Fix `plans_view.dart` null corruption**
Replace all `null` literals at lines 446, 452-454, 589, 594-596 with the correct field reference (likely `item.photoUrl` or similar from the `DecisionItem` / `TripFeedItem` model). This will restore thumbnail rendering on the Plans tab and eliminate 25 warnings.

**3. Rebuild `settlement_page.dart` bottom half**
The file is a stub below line 107. Needs:
- Settlement amount display (`$abs` formatted with `prefix`)
- Payment CTA (PlasmaFill "Pay Now" button)
- Settlement breakdown (who owes whom)
- Remind button
- Status indicator
- Reference `settlement_sheet.dart` for UI patterns (intact)

### HIGH (prevents recurrence of incident)

**4. Add `git filter-repo` landmine to CLAUDE.md**
Add to the "Critical Landmines" section:
```
NEVER run `git filter-repo` without first stashing or committing ALL working-tree
files. The user's app/lib/ source was historically untracked; any git operation
that resets the working tree will destroy untracked files permanently.
Always: git stash push --include-untracked BEFORE filter-repo.
```

**5. Add `.agent/` to `.gitignore`**
```bash
echo '.agent/' >> .gitignore
```
Prevents the embedded skills directory from polluting future commits or backups.

**6. Commit the 3 modified files**
- `triage_prototypes.dart` has substantial UI work (Apple Wallet stack rework) — at risk of loss
- `pubspec.lock` — should be tracked
- `GeneratedPluginRegistrant.swift` — auto-generated, should match current state

### MEDIUM (code quality)

**7. Update `auth_flow_page.dart` to use `HelloText` instead of `HelloTypography`**
Line 261: `HelloTypography.body` → `HelloText.body`. Then remove the typedef shim from `theme.dart:99`.

**8. Clean up `plans_view.dart` stubs and dead code**
- Remove or rewrite `_StubActionCard` (lines 695-712)
- Fix dead null-aware expression at line 74
- Remove unnecessary null comparisons/assertions at lines 478, 480, 611, 613

**9. Clean up `group_page.dart` unused variables**
Lines 144-145: `memberCount` and `unread` computed but unused.

**10. Remove unused import in `focus_sources_provider.dart`**
Line 2: `package:flutter_riverpod/flutter_riverpod.dart` imported but unused.

**11. Delete broken test file**
`app/test/discover/discovery_widgets_test.dart` imports from deleted `app/lib/views/discover/`. Either delete it or rewrite against the current UI.

---

## Summary Scorecard

| Dimension | Status | Grade |
|-----------|--------|-------|
| All Dart files tracked in git | 88/88 tracked | PASS |
| Working tree clean | 3 modified + 2 untracked | FAIL |
| `.agent/` ignored | Not in `.gitignore` | FAIL |
| Dependencies resolve | `flutter pub get` OK | PASS |
| Avatar images exist | 0/10 present | **CRITICAL FAIL** |
| Legacy API tokens purged | 1 surviving (`HelloTypography`) | WARN |
| `const` safety | Clean | PASS |
| `settlement_page.dart` complete | 46% missing (stub) | **FAIL** |
| `plans_view.dart` correct | Null corruption + old version | **FAIL** |
| `theme.dart` functional | Reconstructed, compiles | PASS |
| `seed_data.dart` functional | Reconstructed, 1 bad asset ref | WARN |
| `filter-repo` landmine documented | Missing from CLAUDE.md | **FAIL** |
| `dart analyze` errors | 0 | PASS |
| Web build | Exit code 0 | PASS |

**Bottom line:** The codebase compiles and builds. Zero errors. But it is NOT functionally complete. The cosmos Home avatars have no images. The Plans tab has broken thumbnail rendering. The settlement detail page is a placeholder. And the guardrails that would prevent another incident like this have not been put in place.

---

## Incident Report Accuracy Check

Comparing claims in `apr15_claude_stupidity.md` against this audit:

| Claim in Report | Verified? | Reality |
|-----------------|-----------|---------|
| "dart analyze lib/ → 0 errors, 30 warnings, 65 infos" | **PARTIALLY** | 0 errors confirmed. But total is 95 issues (30 warnings + 65 infos), not the "95 issues" — actually this matches. VERIFIED. |
| "88 .dart files on disk" | **VERIFIED** | `find` confirms 88 |
| "All committed to git" | **VERIFIED** | `git ls-files` confirms 88 tracked |
| "plans_view.dart recovered to Apr 4 version (708 lines)" | **CLOSE** | Actually 712 lines, not 708. Minor discrepancy. |
| "settlement_page.dart truncated at line 90" | **INACCURATE** | File is 120 lines. Stub starts at line 108, not 90. The report understated the surviving code. |
| "`git filter-repo` landmine added to CLAUDE.md" | **NOT DONE** | CLAUDE.md has zero mentions of filter-repo |
| "`.agent/` added to .gitignore" | **NOT DONE** | `.agent/` is not in `.gitignore` |
| "The app should compile and run" | **COMPILES, CANNOT FULLY RUN** | Builds successfully, but missing avatar images will cause runtime asset-load failures on the Home screen |

**The incident report's "What I should do next" section listed 6 remediation steps. Of those 6, items 3-6 were NEVER completed.** Only items 1-2 (the code recovery itself) were partially done, and even those have the `null` corruption in `plans_view.dart` and the missing images that weren't flagged.
