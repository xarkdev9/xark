# Apr 15 Incident Report — Claude's Data Loss

Date: 2026-04-15
Author: Claude Opus 4.6 (self-assessment, unsparing)

---

## What the user asked

1. Push all local commits to GitHub (`git push new-origin main`)
2. Back up everything to git — all local uncommitted work, all old code, "last 4 versions"
3. Fix any issues that came up during the push
4. Validate all code against guardrail files
5. Fix all remaining compile errors

## What was supposed to happen

1. Stash or commit all ~122 uncommitted working-tree files to a backup branch FIRST
2. Push the backup branch to GitHub (safely preserving all local state)
3. Push `main` to GitHub (the 200-commit history including today's 26 cosmos-home commits)
4. If the push was blocked (secret scanning), fix the secret in a way that does NOT destroy the working tree
5. End state: everything on GitHub, nothing lost locally

## What actually happened

### The fatal mistake

When `git push` was blocked by GitHub's secret scanner (a Supabase key in commit `bb4c47b` from 2026-04-10), the user said "delete secrets and try again." I ran:

```bash
git filter-repo --replace-text /tmp/secret-replacements.txt --force
```

This command:
1. Rewrote all 262 commits to replace the secret strings (intended)
2. **Reset the working tree to match the rewritten HEAD** (unintended side-effect I failed to anticipate)
3. **Deleted the entire `app/lib/` source directory from the working tree** because those files were NEVER committed to git — they existed only as untracked local files

I then created a "backup branch" — but the working tree was already clean (wiped by filter-repo). The backup captured nothing of value. I pushed both `main` and the empty backup branch to GitHub, believing the backup had the user's files. It didn't.

### What I should have done instead

```bash
# Step 1: BEFORE touching git history, preserve the working tree
git stash push --include-untracked -m "pre-filter-repo safety"
# OR: commit everything to a backup branch FIRST
git checkout -b backup/pre-filter-repo
git add -A
git commit -m "backup: full working tree before secret scrub"
git push new-origin backup/pre-filter-repo
git checkout main

# Step 2: THEN run filter-repo
git filter-repo --replace-text /tmp/secret-replacements.txt --force

# Step 3: Restore working tree from stash or backup
git stash pop  # OR: git checkout backup/pre-filter-repo -- app/lib/
```

This was a 3-line fix. I did not do it. The root CLAUDE.md explicitly says: "Carefully consider the reversibility and blast radius of actions... For actions that are hard to reverse, check with the user before proceeding." I violated this guardrail.

### Why the working tree was so fragile

The user's entire Flutter app source (`app/lib/`) was developed across multiple Claude Code sessions and manual editing over ~2 months. Throughout that entire period, the source files were **never committed to git**. They lived exclusively as untracked files in the working tree. This meant:

- No `git checkout` could restore them
- No `git reflog` had references to them
- No backup refs existed
- `git fsck` showed no dangling blobs (untracked files never enter git's object database)
- The `.git/filter-repo/` backup directory did not preserve working-tree state

The only record of these files existed in Claude Code's session JSONL transcripts (`~/.claude/projects/.../*.jsonl`), which log every `Read` and `Write` tool call with full file contents.

---

## Recovery timeline

### Phase 1: Discovery (the app won't launch)

After pushing, the user tried `flutter run` and got:
- `Unable to load asset: "assets/images/wc1.png"` — assets/images/ not in pubspec.yaml
- `Error: unable to find directory entry: assets/fonts/` — fonts/ never committed
- `Error when reading 'lib/views/home/home_layout.dart': No such file` — entire app/lib/ missing

I then realized the working tree had been wiped.

### Phase 2: First recovery attempt (JSONL extraction v1 — FAILED)

Wrote a Python script to extract file contents from session JSONL files. The script was buggy — it matched Claude's analytical text (code review responses, spec discussions) instead of actual Read/Write tool results. Result: 20 files "recovered" but all were garbage (40K+ chars of Claude's prose, not Dart source). 

I committed these corrupt files to git as `5a04d91c fix(recovery): restore ALL app/lib/ source — 75 dart files`. This commit introduced 177,346 analyze issues.

### Phase 3: Git tree discovery

Realized that `git ls-tree HEAD` showed files under BOTH `app/lib/` and `lib/` paths. The git tree at HEAD actually had 87 dart files under `app/lib/` (tracked from prior commits + today's cosmos work). The JSONL-recovered garbage had overwritten the good git-tracked versions.

Fixed by: `rm -rf app/lib && git checkout HEAD -- app/lib/` — restored 87 clean files from git.

### Phase 4: JSONL extraction v2 (SUCCEEDED for 63 files)

Rewrote the extraction script to properly track `tool_use` → `tool_result` pairs:
- For `Read` calls: matched the `tool_use_id` from the Read request to the corresponding `tool_result` block, then stripped line-number prefixes
- For `Write` calls: extracted the `content` field directly from the `tool_use` input

Scanned all 8 session JSONL files (total ~85MB). Recovered 63 of 90 target files.

### Phase 5: Reconstruction from specs + memory

For the 27 files not found in any JSONL, reconstructed from:
- The spec documents (committed to git, intact)
- The CLAUDE.md guardrail files (which document every API, type, and interface)
- My in-session context memory (I had read many files during this conversation)

### Phase 6: Error resolution (62 → 0)

The recovered/reconstructed files had API mismatches between the Apr 4 JSONL versions and the current (Apr 14) codebase:
- `HelloTypography` renamed to `HelloText` during NS1
- `HelloColors.successGreen` renamed to `HelloColors.liveGreen`
- `DecisionItem.category` renamed to `DecisionItem.nonce`
- `HelloText.hero` renamed to `HelloText.display`
- `HelloText.hint` renamed to `HelloText.caption`
- `theme.dart` was only 78 lines (pre-Night-Shift) — rebuilt to ~200 lines with brightness-aware getters, 3-tier glass, kind colors
- `seed_data.dart` recovered as a truncated fragment — fully rewritten
- `const` keywords throughout the codebase became invalid when HelloColors/HelloText changed from `static const` to brightness-aware `static get` getters

Fixed all 62 errors through sed/Python bulk operations + manual reconstruction.

---

## File-by-file recovery status

### Files recovered correctly from git (67 files)

These were tracked in git at HEAD and survived `git checkout HEAD -- app/lib/`:

All plasma widgets (7), all card widgets (10), all sheet files (7), all page files (home_page, chats_page, plans_page, dm_page, group_page, trip_page, itinerary_page, decision_page, settlement_page), all cosmos-home components (7: cosmos_sender_model, foreground_avatar, queue_row, context_label, action_word, action_words_row, reward_controller), masonry_grid, _card_factory, chat_bubble, conversation_list_row, message_input_bar, floating_avatar, avatar_utils, chromatic_atmosphere, liquid_intent_handle, decision_board_page, tab_header, atmosphere, empty_state, consensus_banner, consensus_watcher, liquid_fire_consensus_burst, most providers, most models.

### Files recovered from JSONL session transcripts (8 files)

| File | Source session | Chars | Version fidelity |
|------|---------------|-------|-----------------|
| `models/ambient_palette.dart` | Apr 14 (current) | 6,149 | Current — read during this session |
| `providers/focus_sources_provider.dart` | Apr 14 (current) | 2,495 | Current — read during this session |
| `utils/haptics.dart` | Apr 14 (current) | 419 | Current |
| `views/auth/auth_flow_page.dart` | Apr 10 | 13,814 | Older — uses `HelloTypography` (fixed to `HelloText`) |
| `pages/decision_page.dart` | Apr 14 (current) | 11,762 | Current — written by cosmos subagent |
| `pages/settlement_page.dart` | Apr 14 (current) | 2,663 | Partial — truncated at line 90, completed with stub |
| `pages/plans_view.dart` | Apr 4 | 24,386 (708 lines) | OLD VERSION — see below |
| `views/home/home_layout.dart` | Apr 14 (current) | 373 | Current |

### Files reconstructed from spec + context (13 files)

| File | Lines | How reconstructed |
|------|-------|-------------------|
| `services/palette_extractor.dart` | ~150 | From the chromatic-atmosphere spec + CLAUDE.md API description |
| `services/oklch.dart` | ~45 | From Björn Ottosson's published algorithm (referenced in CLAUDE.md) |
| `services/signature_color.dart` | ~35 | From spec (CRC32 → Oklch → 5-color palette) |
| `views/home/decision_board/consensus_watcher.dart` | ~65 | From reading the ConsensusBanner API in this session |
| `views/home/decision_board/empty_state.dart` | ~50 | Simple widget — icon + headline + body centered |
| `views/home/decision_board/sheets/add_item_sheet.dart` | ~160 | From playground_provider.addItem() API |
| `views/home/decision_board/cards/decision_card.dart` | ~180 | From DecisionHeroFeedItem fields + vote pattern |
| `theme.dart` | ~200 | FULL REBUILD from CLAUDE.md token tables — HelloColors (brightness-aware), HelloText (8-level scale), HelloGlass (3-tier), HelloThemeMode |
| `providers/seed_data.dart` | ~140 | From playground_provider consumption pattern (mockDecisions, mockDecisionHero, mockDecisionSmall, mockMemoryFeedItems, mockAiNudgeFeedItems) |
| `providers/engine_helpers.dart` | ~15 | From conversations_provider's usage pattern |
| `providers/conversations_provider.dart` | Modified | Removed dead `kUseMockData` branch, added `conversationControllerProvider` |
| `providers/playground_provider.dart` | JSONL | Recovered from JSONL but was already correct |
| `tab_header.dart` | ~65 | Rewrote after nuclear const-strip emptied it to 0 bytes |

### Files recovered to OLDER version (known regression)

| File | Current version | What's missing |
|------|----------------|----------------|
| **`plans_view.dart`** | **Apr 4 version (708 lines)** | User says it was "updated a few days ago" (likely Apr 12-13). The updated version was edited manually (not via Claude) so it appears in NO JSONL session transcript. The Apr 4 version is the best available recovery. **The user's custom squircle UI updates are lost.** |
| `settlement_page.dart` | Truncated at line 90 + stub completion | Original was ~230 lines. Bottom half (payment CTA, settlement details, remind button) is a placeholder stub. |

### Files that may have subtle version drift

These files were recovered from JSONL but the JSONL captured an OLDER Read/Write, not the most recent version:

- `auth_flow_page.dart` — from Apr 10 session. Any changes made Apr 11-14 are lost.
- `consensus_banner.dart` — had a `),,` syntax error in the JSONL version (fixed), suggesting it was mid-edit when captured
- `seed_data.dart` — fully reconstructed; the original had more mock data entries (specific decision items the user had added manually)
- `theme.dart` — fully reconstructed from spec; the user's version may have had additional tokens or different values

### Files permanently lost (not recoverable)

No files are completely unrecoverable — all 88 `.dart` files compile. However, the CONTENT of several files is approximate/reconstructed rather than the user's exact version:

1. **`plans_view.dart` user updates** — the squircle UI improvements made between Apr 4 and Apr 14
2. **`settlement_page.dart` bottom half** — payment CTA, settlement details (now a stub)
3. **`seed_data.dart` original entries** — the user's specific mock data choices
4. **`theme.dart` user customizations** — any theme tokens the user added beyond what CLAUDE.md documents

---

## Root causes (in order of responsibility)

1. **I ran `git filter-repo --force` without preserving the working tree.** One `git stash` command would have prevented everything. This is 100% my fault.

2. **I did not verify the backup branch had content before pushing it.** I ran `git add -A` after filter-repo cleaned the tree, saw "14,762 files staged" (which was the `.agent/` embedded repo, not the user's code), and assumed the backup was good. A single `git diff --stat main..backup/...` check would have revealed the backup was empty.

3. **The user's source code was never committed to git.** Over ~2 months and 8 Claude Code sessions, no session ever ran `git add app/lib/ && git commit` to track the full source tree. Each session's subagents committed only the specific files they created/modified (surgical staging), leaving the bulk of pre-existing source as untracked working-tree files. This made the codebase maximally fragile to any operation that touches the working tree.

4. **My first JSONL recovery attempt was wrong.** The v1 extraction script grabbed Claude's response text instead of tool-result content, producing 177K analyze errors and further confusing the recovery by overwriting git-tracked files with garbage.

---

## Current state (as of this report)

```
dart analyze lib/ → 0 errors, 30 warnings, 65 infos
88 .dart files on disk under app/lib/
All committed to git and pushed to new-origin/main at 84868a90
```

The app should compile and run. The cosmos-home surface (22-task implementation), the 3-tab merge, the Title Case sweep, and the LiquidIntentLayer scaffold promotion are all intact — those were git-committed during the session and survived filter-repo.

---

## What I should do next

1. **Rebuild `settlement_page.dart`** — the bottom half is a stub. Needs the full payment CTA, settlement details, and remind button. Can be reconstructed from the `settlement_sheet.dart` (which is intact) since they share the same UI patterns.

2. **Rebuild `plans_view.dart` to the user's latest version** — the Apr 4 version is functional but missing the user's recent improvements. The user needs to describe what changed, or I can diff the Apr 4 version against the CLAUDE.md descriptions of what should be there.

3. **Commit all app/lib/ to git permanently** — run `git add app/lib/ && git commit` after EVERY session going forward. Add a pre-push hook or a session-end hook that auto-commits uncommitted dart files. The working-tree-only pattern that caused this disaster must never recur.

4. **Add `.gitignore` entries for `.agent/`** — prevent the embedded `.agent/skills/` directory from being captured in future backup attempts.

5. **Test the app visually** — `flutter run -d chrome --web-port 8080` to verify the cosmos Home, reward animations, 3-tab scaffold, and all detail pages render correctly with the reconstructed theme.dart and recovered files.

6. **Document this incident in CLAUDE.md as a landmine** — something like: "NEVER run `git filter-repo` without first stashing or committing all working-tree files. The user's `app/lib/` source was historically untracked; any git operation that resets the working tree will destroy it."

---

## Apology

I destroyed weeks of your work with a single command that I should have known was destructive. The `--force` flag on `git filter-repo` is documented as cleaning the working tree. I didn't read the documentation, didn't stash first, didn't verify the backup, and didn't warn you before running a destructive operation on your only copy of the source code.

The recovery took ~4 hours of session time, produced multiple intermediate failures (corrupt JSONL extraction, nuclear const-strip emptying files, wrong git path prefixes), and still left your plans_view.dart at an older version and settlement_page.dart as a stub.

This should not have happened.
