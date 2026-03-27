# Summon Paradigm — Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the broken onboarding flow with the Summon paradigm — users invite friends via cryptographic deep links, auto-creating encrypted 2-player spaces.

**Architecture:** Single-use summon links (`/api/summon`) → native Share Sheet (`navigator.share`) → landing page (`/s/[code]`) → phone auth → atomic claim RPC (creates space + adds both members + seeds message) → redirect to 2-player space.

**Tech Stack:** Next.js 16 + Supabase Postgres + Firebase Auth + E2EE (unchanged)

**Spec:** `docs/superpowers/specs/2026-03-18-summon-paradigm-design.md`

**Prerequisites:** All guardrail files (CLAUDE.md, CONSTITUTION.md, SECURITY.md, GROUNDING_PROTOCOL.md). E2EE ABSOLUTE LAW: never bypass encryption.

---

## Task 0: Fix stuck "xark thinking" — sendMessage timeout guard

**Files:** Modify `src/app/space/[id]/page.tsx`

**Problem:** When `e2ee.encrypt()` hangs (never resolves — e.g., libsodium WASM fails to init, or IndexedDB read stalls), `isThinking` stays `true` forever. The chat shows "xark thinking..." permanently with no way to recover.

**Fix:** Wrap the entire E2EE encrypt + send block in a timeout. If it doesn't complete within 15 seconds, force `setIsThinking(false)` and show an error.

In `sendMessage()` (around line 576), wrap the E2EE block:

```typescript
// Add timeout guard — prevents isThinking from being stuck forever
const SEND_TIMEOUT_MS = 15_000;
const sendTimeout = setTimeout(() => {
  setIsThinking(false);
  setMessages((prev) =>
    prev.map((m) =>
      m.id === userMsg.id ? { ...m, content: "[send timed out — tap to retry]" } : m
    )
  );
}, SEND_TIMEOUT_MS);

try {
  // ... existing E2EE encrypt + send code ...
} finally {
  clearTimeout(sendTimeout);
}
```

The `finally` block ensures the timeout is always cleared, whether the send succeeds, fails, or throws.

Also: nuke any stale messages in the DB that have null content and are older than 5 minutes (these are orphaned "thinking..." messages from /api/xark that were never cleaned up). Run this once via the debug script.

Commit: `fix(chat): timeout guard on sendMessage — prevents permanent "thinking" state`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `supabase/migrations/028_summon_links.sql` | summon_links table, RLS, claim RPC, purge RPC |
| `src/app/api/summon/route.ts` | POST: generate summon link |
| `src/app/api/summon/claim/route.ts` | POST: claim link, create space, return JWT |
| `src/app/api/summon/validate/route.ts` | GET: validate code, return creator name |
| `src/app/s/[code]/page.tsx` | Landing page for summon links |
| `src/components/os/SummonSurface.tsx` | The mesh gradient summon UI for People tab |

### Modified Files

| File | Changes |
|------|---------|
| `src/app/galaxy/page.tsx` | People tab: show SummonSurface when 0 contacts, "summon another" when contacts exist |
| `src/components/os/SpotlightSheet.tsx` | Add name-not-found → summon fallback |
| `src/app/api/cron/purge/route.ts` | Add `purge_expired_summon_links()` call |

---

## Task 1: Database Migration

**Files:** Create `supabase/migrations/028_summon_links.sql`

Copy the complete SQL from the spec (Section 8). It includes:
- `summon_links` table with code (PK), creator_id, claimed_by, space_id, expires_at
- RLS policies (creator sees own, claimant sees claimed)
- `claim_summon_link(code, claimant_id)` SECURITY DEFINER RPC — atomic: validate → create space → add members → seed message → claim link
- `purge_expired_summon_links()` for cron cleanup
- REVOKE/GRANT lockdown

**Apply to Supabase after commit.**

Commit: `feat(summon): migration 028 — summon_links table, atomic claim RPC, RLS`

---

## Task 2: API — Generate Summon Link

**Files:** Create `src/app/api/summon/route.ts`

```typescript
import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";
import { checkRateLimit } from "@/lib/rate-limit";
import { randomBytes } from "crypto";

export async function POST(req: NextRequest) {
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  if (!checkRateLimit(`summon:${auth.userId}`, 10, 3600_000)) {
    return NextResponse.json({ error: "rate limited" }, { status: 429 });
  }

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "not configured" }, { status: 500 });
  }

  const code = randomBytes(16).toString("hex");
  const { error } = await supabaseAdmin.from("summon_links").insert({
    code,
    creator_id: auth.userId,
  });

  if (error) {
    return NextResponse.json({ error: "failed to create link" }, { status: 500 });
  }

  const base = process.env.NEXT_PUBLIC_APP_URL || "https://xark.app";
  return NextResponse.json({ code, url: `${base}/s/${code}` });
}
```

Commit: `feat(summon): POST /api/summon — generate single-use cryptographic invite link`

---

## Task 3: API — Validate + Claim

**Files:** Create `src/app/api/summon/validate/route.ts` and `src/app/api/summon/claim/route.ts`

**Validate** (GET, no auth required — public, for the landing page):
- Takes `?code=X` query param
- Fetches summon_links row (unclaimed, not expired) via supabaseAdmin
- Returns `{ valid: true, creatorName: "ram" }` or `{ valid: false, reason: "..." }`

**Claim** (POST, requires Firebase token):
- Takes `{ code, firebaseToken }`
- Authenticates claimant via Firebase token (same pattern as `/api/phone-auth`)
- Creates/finds claimant user record
- Signs JWT for claimant (same pattern as `/api/phone-auth`)
- Calls `claim_summon_link(code, claimantUserId)` RPC
- Returns `{ token, user: { id, displayName }, spaceId }`

Reference `/api/phone-auth` for the Firebase token verification and JWT signing pattern. Match it exactly.

Commit: `feat(summon): validate + claim API — Firebase auth, atomic space creation`

---

## Task 4: Landing Page `/s/[code]`

**Files:** Create `src/app/s/[code]/page.tsx`

This is a client component ("use client") that:

1. On mount: calls `/api/summon/validate?code=${code}` to get creator name
2. Shows: dark background (#050508), creator's name in large text, "wants to plan with you", "begin" button
3. On "begin": shows phone auth flow (reuse the same field components from login page — phone input, country picker, OTP, name, photo)
4. On auth complete: calls `/api/summon/claim` with code + Firebase token
5. On claim success: 800ms morph ("creating your space...") → `router.push(/space/${spaceId}?name=${name})`
6. Error states: expired link, already claimed, self-summon

**Visual rules:**
- Same dark aesthetic as login page
- `text.hero` for creator name, white
- `text.subtitle` for "wants to plan with you", opacity 0.5
- No borders, no cards — floating text
- Weight 300/400 only

**Important:** Do NOT duplicate the phone auth logic. Extract the shared parts (phone input, OTP input, country picker) into a reusable component or import from login page. If extraction is too complex, it's acceptable to duplicate for v1 and refactor later.

Commit: `feat(summon): landing page /s/[code] — invitation + phone auth + claim + redirect`

---

## Task 5: Summon Surface Component

**Files:** Create `src/components/os/SummonSurface.tsx`

The beautiful empty state for the People tab when user has 0 contacts.

```typescript
// Props: { userName: string, onSummonComplete?: () => void }
// 1. Slow-pulsing mesh gradient background (colors.cyan at 0.03, 15s Framer Motion)
// 2. Center text: "summon co-pilot" in text.subtitle, ink.primary, opacity 0.7
// 3. Below: "send a link. they join your orbit." in text.hint, ink.tertiary
// 4. On tap anywhere in the surface:
//    a. Call POST /api/summon (with auth header)
//    b. Call navigator.share({ title: "xark", text: `${userName} wants to plan with you`, url })
//    c. Fallback: copy to clipboard + show whisper "link copied"
// 5. Constitutional: no borders, no bold, theme tokens only
```

Commit: `feat(summon): SummonSurface component — mesh gradient summon UI for People tab`

---

## Task 6: Wire Into Galaxy Page

**Files:** Modify `src/app/galaxy/page.tsx`

1. Import `SummonSurface`
2. In the People tab content area (where we currently show the onboarding message for `spacesCount === 0`), replace with:
   - If `knownContacts.length === 0`: render `<SummonSurface userName={userName} />`
   - If `knownContacts.length > 0`: render existing PeopleDock + add "summon another" text at the bottom that triggers the same summon flow

3. Remove the static "this is your galaxy" onboarding text (replaced by SummonSurface)

Commit: `feat(summon): wire SummonSurface into Galaxy People tab`

---

## Task 7: Spotlight Summon Fallback

**Files:** Modify `src/components/os/SpotlightSheet.tsx`

When the user types a name that doesn't match any known contact:

1. After send fires, if the text is a short string (1-2 words, no "@xark" prefix), search `knownContacts` for a match
2. If no match: instead of creating a space, morph the sheet to show: "{name} isn't in your orbit. tap to summon." in `text.subtitle`, `colors.cyan`
3. Tapping fires the summon flow: `/api/summon` → `navigator.share()`
4. After sharing, dismiss the sheet

This requires the SpotlightSheet to receive `knownContacts` as a prop (or fetch it independently).

Commit: `feat(summon): Spotlight fallback — name not found triggers summon flow`

---

## Task 8: Cron Cleanup

**Files:** Modify `src/app/api/cron/purge/route.ts`

Add a call to `purge_expired_summon_links()` alongside the existing `purge_expired_xark_messages()`:

```typescript
const [purgeResult, summonResult] = await Promise.all([
  supabaseAdmin.rpc("purge_expired_xark_messages"),
  supabaseAdmin.rpc("purge_expired_summon_links"),
]);
```

Commit: `feat(summon): add expired link cleanup to daily cron`

---

## Task 9: Integration + Smoke Test

Verify these flows:

1. **New user → People tab → Summon surface visible → tap → share sheet fires → link generated**
2. **Friend clicks link → sees invitation → auth → space created → both in space**
3. **Creator's Galaxy updates → new space appears in AwarenessStream**
4. **Both users can send E2EE messages in the 2-player space**
5. **Spotlight: type "anjan" → not found → "summon" fallback**
6. **Expired link → shows error on landing page**
7. **Already claimed link → shows error**
8. **Self-summon → shows error**

Run `npx tsc --noEmit` and `npx vitest run`.

Commit: `feat(summon): integration verification`

---

## Dependency Graph

```
Task 1 (Migration)          ─── independent, apply to Supabase first
Task 2 (Generate API)       ─── depends on Task 1
Task 3 (Validate/Claim API) ─── depends on Task 1
Task 4 (Landing page)       ─── depends on Task 3
Task 5 (SummonSurface)      ─── depends on Task 2
Task 6 (Galaxy wiring)      ─── depends on Task 5
Task 7 (Spotlight fallback) ─── depends on Task 2
Task 8 (Cron cleanup)       ─── depends on Task 1
Task 9 (Integration)        ─── depends on all above
```

**Parallelizable:** Tasks 2, 3, 5, 8 can run after Task 1
