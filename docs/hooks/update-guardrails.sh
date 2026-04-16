#!/usr/bin/env bash
# Auto-librarian Stop hook for the hello monorepo.
#
# Fires when a Claude Code main session's main agent yields control
# (Stop event). Checks whether any source commits have landed since
# the most recent guardrail update; if so, dispatches a headless
# Claude session to refresh CLAUDE.md + docs/CHANGELOG.md.
#
# Design goals:
#   - Never block the parent session on librarian failure
#   - Fire at MOST once per deploy (not once per "hi")
#   - Loop-guarded (lockfile + --bare flag on the librarian)
#   - Rate-limited (min 120s between runs)
#   - Silent on normal exit — logs to $HOME/.hello-librarian.log
#
# Manual bypass: `touch /tmp/hello-librarian-skip` disables the
# next fire. Useful when you know you're mid-deploy and don't want
# the librarian to race your final commit.

set -uo pipefail
# NOTE: -e intentionally omitted — we NEVER want the hook to fail
# noisily and pollute the parent session's context. All errors are
# logged and swallowed.

PROJECT_ROOT="/Users/ramchitturi/hello"
LOCKFILE="/tmp/hello-librarian.lock"
LAST_RUN_FILE="$HOME/.hello-librarian-last-run"
SKIP_FILE="/tmp/hello-librarian-skip"
LOG_FILE="$HOME/.hello-librarian.log"
# Prompt file lives alongside this script so edits stay in one place.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="$SCRIPT_DIR/update-guardrails-prompt.md"
CLAUDE_BIN="/Users/ramchitturi/.local/bin/claude"
MIN_INTERVAL_SECONDS=120
LIBRARIAN_TIMEOUT_SECONDS=300

log() {
  printf '[%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$*" >> "$LOG_FILE" 2>/dev/null
}

# --- Gate 1: Only run in the hello project ---
if [ ! -d "$PROJECT_ROOT/.git" ]; then
  exit 0
fi

# Jump into the project. If cd fails (permission, deleted, etc.), exit silently.
cd "$PROJECT_ROOT" 2>/dev/null || exit 0

# --- Gate 2: Manual skip file ---
if [ -f "$SKIP_FILE" ]; then
  log "Skip file present — bypassing librarian and consuming skip"
  rm -f "$SKIP_FILE"
  exit 0
fi

# --- Gate 3: Rate limit ---
# At most one fire every MIN_INTERVAL_SECONDS.
if [ -f "$LAST_RUN_FILE" ]; then
  LAST_RUN=$(cat "$LAST_RUN_FILE" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  ELAPSED=$((NOW - LAST_RUN))
  if [ "$ELAPSED" -lt "$MIN_INTERVAL_SECONDS" ]; then
    log "Rate-limited: last run was ${ELAPSED}s ago (min ${MIN_INTERVAL_SECONDS}s)"
    exit 0
  fi
fi

# --- Gate 4: Lockfile (atomic create, survives crash) ---
if ! (set -C; : > "$LOCKFILE") 2>/dev/null; then
  # Lockfile already exists — another librarian is running OR
  # a previous run died uncleanly. Check age: if older than 15 min,
  # assume stale and remove.
  if [ -f "$LOCKFILE" ]; then
    LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCKFILE" 2>/dev/null || echo 0) ))
    if [ "$LOCK_AGE" -gt 900 ]; then
      log "Stale lockfile (${LOCK_AGE}s old) — removing and retrying"
      rm -f "$LOCKFILE"
      : > "$LOCKFILE"
    else
      log "Lockfile present (${LOCK_AGE}s old) — another librarian active, skipping"
      exit 0
    fi
  fi
fi
# Clean up lockfile on exit regardless of how we exit.
trap 'rm -f "$LOCKFILE"' EXIT

# --- Gate 5: Commit gate ---
# Find the most recent commit that touched any guardrail file.
# If no such commit exists, this is the bootstrap state — skip.
#
# Guardrail files include: root CLAUDE.md, per-package CLAUDE.md
# files, DESIGN.md, and docs/CHANGELOG.md.
LAST_GUARDRAIL_COMMIT=$(git log -1 --format=%H -- \
  CLAUDE.md DESIGN.md \
  docs/CHANGELOG.md \
  app/CLAUDE.md engine/CLAUDE.md web/CLAUDE.md algo/CLAUDE.md \
  xpensly/CLAUDE.md \
  xpensly/xpensly_core/CLAUDE.md xpensly/xpensly_ui/CLAUDE.md \
  2>/dev/null)

if [ -z "$LAST_GUARDRAIL_COMMIT" ]; then
  log "No prior guardrail commits found — bootstrap state, skipping"
  exit 0
fi

# Are there commits AFTER the last guardrail commit that touched
# source files (not guardrails, not specs, not plans)?
NEW_SOURCE_COMMITS=$(git log --format='%h %s' "${LAST_GUARDRAIL_COMMIT}..HEAD" -- \
  . \
  ':!CLAUDE.md' \
  ':(exclude,glob)**/CLAUDE.md' \
  ':!DESIGN.md' \
  ':!docs/CHANGELOG.md' \
  ':!docs/superpowers/' \
  2>/dev/null | head -50)

if [ -z "$NEW_SOURCE_COMMITS" ]; then
  log "No new source commits since ${LAST_GUARDRAIL_COMMIT:0:7} — up to date"
  exit 0
fi

COMMIT_COUNT=$(echo "$NEW_SOURCE_COMMITS" | wc -l | tr -d ' ')
log "Dispatching librarian for ${COMMIT_COUNT} source commit(s) since ${LAST_GUARDRAIL_COMMIT:0:7}"
log "Commits:"
echo "$NEW_SOURCE_COMMITS" | sed 's/^/    /' >> "$LOG_FILE"

# --- Gate 6: Require prompt file ---
if [ ! -f "$PROMPT_FILE" ]; then
  log "Prompt file missing at $PROMPT_FILE — cannot dispatch librarian"
  exit 0
fi

# --- Gate 7: Require claude CLI ---
if [ ! -x "$CLAUDE_BIN" ]; then
  log "claude CLI missing at $CLAUDE_BIN — cannot dispatch librarian"
  exit 0
fi

# --- Record the run BEFORE dispatch ---
# If the librarian fails for any reason (timeout, crash, API error),
# we still want the rate-limit to prevent a retry storm. Write the
# timestamp now.
date +%s > "$LAST_RUN_FILE"

# --- Dispatch the librarian ---
# Use --print for headless one-shot mode.
# Use --bare to skip all hooks (prevents recursive Stop hook firing)
#   and skip auto-memory + CLAUDE.md auto-discovery (faster, cleaner
#   context — the librarian prompt provides everything it needs).
# Use --add-dir to grant file access to the project directory.
# Pipe the prompt file as the input. `timeout` caps runaway jobs.
log "Starting librarian (timeout ${LIBRARIAN_TIMEOUT_SECONDS}s)"
if timeout "$LIBRARIAN_TIMEOUT_SECONDS" "$CLAUDE_BIN" \
    --print \
    --bare \
    --add-dir "$PROJECT_ROOT" \
    --dangerously-skip-permissions \
    < "$PROMPT_FILE" \
    >> "$LOG_FILE" 2>&1
then
  log "Librarian completed successfully"
else
  LIBRARIAN_EXIT=$?
  log "Librarian exited with status ${LIBRARIAN_EXIT} (timeout=124 if reached)"
fi

# Never block the parent session — always succeed.
exit 0
