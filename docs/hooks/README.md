# docs/hooks/ — Claude Code hook scripts for the hello monorepo

This directory contains Claude Code lifecycle hook scripts that keep the project's guardrail files (CLAUDE.md, CHANGELOG.md, DESIGN.md, per-package CLAUDE.md files) current without manual intervention.

## What's here

| File | Purpose |
|---|---|
| `update-guardrails.sh` | `Stop` hook entry point. Runs when the main Claude Code agent yields control. Checks whether source commits have landed since the last guardrail update; if so, dispatches a headless `claude --print --bare` session to run the auto-librarian. |
| `update-guardrails-prompt.md` | The librarian's prompt. Defines what the headless `claude` session is allowed to do (docs only, append-only changelog, surgical CLAUDE.md edits, no code changes) and gives it the exact 6-step process. |
| `README.md` | This file. |

## Design principles

1. **Never block the parent session.** The hook script always exits 0. Librarian failures are logged but swallowed.
2. **Fire at most once per deploy, not once per "hi".** Commit gate: only fire when non-guardrail commits exist since the last guardrail touch. Rate limit: min 120s between runs. Lock file: prevents concurrent runs.
3. **No recursion.** The librarian runs with `claude --bare` which skips all hooks, including the `Stop` hook that would otherwise re-fire when the librarian yields.
4. **Single source of truth.** This directory is the canonical location. Updates to the script or prompt happen here and are version-controlled. `~/.claude/settings.json` points directly at `/Users/ramchitturi/hello/docs/hooks/update-guardrails.sh`.
5. **Surgical, not generative.** The librarian is allowed to fix factual drift (file counts, API signatures, new subsystems) and append changelog entries. It may NOT rewrite philosophy, add opinions, or touch code.

## How it's wired

`~/.claude/settings.json` has a `Stop` hook entry pointing at this script:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/Users/ramchitturi/hello/docs/hooks/update-guardrails.sh",
            "timeout": 310
          }
        ]
      }
    ]
  }
}
```

The 310-second timeout is slightly longer than the librarian's internal 300-second timeout so `timeout` inside the script fires before Claude Code kills the hook.

## How it decides whether to fire

The hook script runs these gates in order. Any gate failing → silent exit 0.

1. **Project gate:** `cd /Users/ramchitturi/hello` — if the directory or its `.git/` is missing, exit.
2. **Skip gate:** if `/tmp/hello-librarian-skip` exists, consume it and exit. Use this when you know you're mid-deploy and want to suppress the next fire: `touch /tmp/hello-librarian-skip`.
3. **Rate limit:** min 120 seconds between runs. Prevents a burst of rapid Stop events (chat exchanges, quick answers) from firing 10 librarians.
4. **Lock file:** `/tmp/hello-librarian.lock` prevents concurrent runs. Stale locks older than 15 minutes are forcibly cleared.
5. **Commit gate:** find the most recent commit that touched ANY guardrail file (`CLAUDE.md`, `**/CLAUDE.md`, `DESIGN.md`, `docs/CHANGELOG.md`). Then check whether any commits AFTER that touched source files (excluding `docs/superpowers/**`). If zero source commits found → exit.
6. **Fixtures:** the librarian prompt file + `claude` CLI must both exist. If either is missing, exit.

Only if ALL gates pass does the script dispatch the librarian.

## What the librarian does

Full flow is documented in `update-guardrails-prompt.md`. Short version:

1. Read `docs/CHANGELOG.md` for voice.
2. Compute the commit range from last-guardrail-commit to HEAD.
3. Classify the range (major deploy / trivial cluster / ambiguous).
4. For a major deploy: write one full CHANGELOG entry + surgical CLAUDE.md updates.
5. For a trivial cluster: write a one-line CHANGELOG entry, skip CLAUDE.md.
6. Commit with `docs(guardrails): auto-update for <title>`.
7. Exit.

Hard limits inside the prompt: max 40 tool calls, max 3 minutes wall-clock, max 40 lines per CHANGELOG entry, max 5 CLAUDE.md sections touched per run.

## Logs

All hook + librarian output goes to `~/.hello-librarian.log`. View the most recent runs:

```bash
tail -50 ~/.hello-librarian.log
```

Nothing goes to stdout — stdout would become context the parent agent sees, and we don't want to pollute the main session.

## Testing / debugging

**Standalone test (no new commits scenario):**
```bash
rm -f ~/.hello-librarian-last-run  # Clear rate limit
/Users/ramchitturi/hello/docs/hooks/update-guardrails.sh
# Should exit 0 silently. Log will say "No new source commits since <sha>"
```

**Force a fire even when you don't want the librarian to run a normal session:**
```bash
# Bypass the rate limit and actually invoke claude
rm -f ~/.hello-librarian-last-run /tmp/hello-librarian.lock
/Users/ramchitturi/hello/docs/hooks/update-guardrails.sh
# Then tail the log to watch the librarian run
tail -f ~/.hello-librarian.log
```

**Disable temporarily:**
```bash
touch /tmp/hello-librarian-skip   # Consumed on next fire
```

**Disable permanently:**
Remove the `Stop` entry from `~/.claude/settings.json`. Leave the scripts in this directory in case you want to re-enable.

## Known limitations

- **Per-package CLAUDE.md files are NOT auto-updated.** The librarian only touches root `CLAUDE.md` and `docs/CHANGELOG.md`. Per-package files drift on their own cadence and need manual refresh.
- **The librarian trusts commit messages.** If commit messages are unclear or wrong, the CHANGELOG entry will reflect that. Good commits → good entries.
- **Rate limit is coarse.** 120 seconds is a blunt instrument. If you end a session, wait 10 seconds, and end another session with new commits, only the first will fire. The second will be rate-limited even though its commits are legitimate.
- **The librarian can't ask questions.** It will skip anything it's uncertain about. Human review of the auto-generated CHANGELOG entries (glancing at the next `git log`) is recommended periodically.
- **The script's `PROJECT_ROOT` is hardcoded** to `/Users/ramchitturi/hello`. If you move the repo, update the script.

## Related docs

- `docs/CHANGELOG.md` — the file the librarian appends to
- Root `CLAUDE.md` — "Changelog" section explains the append-only policy and the auto-librarian's role
- `docs/superpowers/specs/` + `docs/superpowers/plans/` — these are OUT of scope for the librarian (specs don't get auto-updated; they're frozen artifacts)
