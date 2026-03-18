# POWER PROMPT: Fix New User Onboarding (4 Critical Issues)

> **For coding agent**: Read ALL guardrail files before touching any code. Sequence: CLAUDE.md → CONSTITUTION.md → SECURITY.md → GROUNDING_PROTOCOL.md → .xark-state.json. These contain constitutional rules that override everything.

**Repository**: `/Users/ramchitturi/xark9`
**Branch**: `main`
**Deploy target**: `vercel deploy --prod --scope xarks-projects-700da30e --yes`

---

## ABSOLUTE CONSTRAINTS (violating any = restart turn)

1. **E2EE ABSOLUTE LAW**: NEVER bypass, downgrade, or disable E2EE. Not for solo spaces. Not for testing. Not temporarily. If encryption fails, message does not send. Solo spaces encrypt to SELF (user's own device key). Read CLAUDE.md lines 75-86 and SECURITY.md Section 0.
2. **NO BOLD**: font-weight 300 or 400 only. 500+ is banned.
3. **ZERO BOX**: No borders, no cards, no rounded-lg on feed items. Information floats.
4. **THEME TOKENS**: All colors via CSS variables from `src/lib/theme.ts`. Never hardcode hex in components.
5. **TYPE SCALE**: All typography from `theme.ts` `text` object. No Tailwind text-size classes.

---

## ISSUE 1: "chat:" prefix — meaningless for new users

**Severity**: UX — Day 1 blocker
**File**: `src/app/galaxy/page.tsx`
**Lines**: 431-438

### Root Cause
When the People tab is active and the input is focused, a hardcoded `<span>chat:</span>` is rendered next to the textarea (line 434-437). For a new user with `knownContacts.length === 0`, there is no one to mention. The prefix looks like a broken CLI instead of a helpful autocomplete hint.

### Fix
Only show the "chat:" prefix when the user has at least one known contact. Wrap the existing conditional:

**Current** (line 434):
```tsx
{mounted && activeTab === "people" && inputFocused && (
```

**Change to**:
```tsx
{mounted && activeTab === "people" && inputFocused && knownContacts.length > 0 && (
```

Find where `knownContacts` is defined in the same file — it's derived from `space_members` queries. Use the same variable name.

### Verification
- New user (zero spaces, zero contacts): input shows placeholder "type a name to start chatting..." with NO "chat:" prefix
- Existing user (has contacts): "chat:" prefix still appears on focus

---

## ISSUE 2: @xark Spotlight is undiscoverable

**Severity**: UX — Day 1 blocker
**File**: `src/components/os/ControlCaret.tsx`

### Root Cause
The SpotlightSheet (and thus the @xark AI interface) is hidden behind a secret gesture — a short tap on the tiny "xark" text at the bottom of the screen. There is zero visual affordance for a new user. No tooltip, no label, no animation pointing them to it.

### Fix
Add an onboarding hint below the "xark" anchor for first-time users. When the user has zero spaces (fresh account), show a breathing hint text above the anchor: "tap to ask xark anything" that fades out after first interaction.

**Implementation**:

1. In `ControlCaret.tsx`, detect if the user has zero spaces. The component already fetches `spaces` via `fetchSpaceList()`. If `spaces.length === 0` and the user hasn't dismissed the hint (track via `localStorage.getItem("xark_spotlight_hint_dismissed")`), render a hint.

2. The hint sits directly above the "xark" text:
```tsx
{showHint && (
  <motion.span
    animate={{ opacity: [0.3, 0.6, 0.3] }}
    transition={{ duration: 4, repeat: Infinity }}
    style={{
      position: "fixed",
      bottom: 56, // above the "xark" text which is at ~32px
      left: "50%",
      transform: "translateX(-50%)",
      ...text.hint,  // from theme.ts
      color: ink.tertiary,
      whiteSpace: "nowrap",
      pointerEvents: "none",
    }}
  >
    tap to ask xark anything
  </motion.span>
)}
```

3. When the user taps "xark" (opens Spotlight for the first time), set `localStorage.setItem("xark_spotlight_hint_dismissed", "1")` and hide the hint.

**Constitutional compliance**:
- Uses `text.hint` from theme.ts (not hardcoded font size)
- Uses `ink.tertiary` (not hardcoded color)
- No borders, no boxes — floating text
- Weight comes from `text.hint` which is 300 — compliant

### Verification
- New user: sees "tap to ask xark anything" breathing above "xark" anchor
- After first tap on xark: hint disappears permanently
- Returning user: no hint

---

## ISSUE 3: Solo space E2EE — sender cannot decrypt own messages

**Severity**: CRITICAL — messages fail in any space with 1 member
**Files**: `src/lib/crypto/encryption-service.ts`

### Root Cause — Key Storage Asymmetry

When a user sends a message in a group space, `encryptForSpace()` does this:
1. Generates or loads an outbound Sender Key
2. Saves it to IndexedDB under key: **`spaceId`** (lines 644, 670, 696)
3. Calls `distributeSenderKey()` which sends the key to other members
4. For solo spaces, distribution bails out (0 other members) — which is correct

When the sender's own message echoes back via Supabase Realtime, `decryptMessage()` does this:
1. Sees `recipientId === '_group_'` (line 743)
2. Looks up sender key under: **`${spaceId}:${senderId}`** (line 755)
3. **FAILS** — the key was stored as `spaceId`, not `${spaceId}:${senderId}`

The key was stored at `spaceId` but looked up at `${spaceId}:${senderId}`. Mismatch.

### Fix

In `decryptMessage()`, when the sender is the current user (i.e., decrypting your own echoed message), also check the `spaceId`-only key as a fallback.

**In `src/lib/crypto/encryption-service.ts`, around line 755**, change:

```typescript
// CURRENT (line 755-760):
let senderKeyData = await keyStore.getSenderKey(`${spaceId}:${senderId}`);
if (!senderKeyData) {
  await new Promise(r => setTimeout(r, 2000));
  senderKeyData = await keyStore.getSenderKey(`${spaceId}:${senderId}`);
}
```

**TO**:

```typescript
// Check standard received-key path first
let senderKeyData = await keyStore.getSenderKey(`${spaceId}:${senderId}`);

// Fallback: check self-authored key (stored as spaceId only by encryptForSpace)
// This handles: (a) solo spaces, (b) decrypting your own echoed messages
if (!senderKeyData) {
  const myUserId = await getCurrentUserId();
  if (senderId === myUserId) {
    senderKeyData = await keyStore.getSenderKey(spaceId);
  }
}

if (!senderKeyData) {
  // Original retry logic — SK distribution may still be processing
  await new Promise(r => setTimeout(r, 2000));
  senderKeyData = await keyStore.getSenderKey(`${spaceId}:${senderId}`);
}
```

### Why this preserves E2EE
- No plaintext fallback. The message is still encrypted with the Sender Key.
- Self-decryption uses the SAME cryptographic key that was used to encrypt.
- The key never leaves the device. It was generated locally and stored locally.
- This is the same pattern Signal uses for "Note to Self" — encrypt to your own key.
- `getCurrentUserId()` already exists in this file — search for it.

### Verification
- Solo space: user sends "hello" → message appears decrypted (not "[queued — will send when online]")
- Group space (2+ members): no behavior change — distributed keys are stored under `${spaceId}:${senderId}` as before
- User's own messages in group spaces: also work via the self-key fallback

---

## ISSUE 4: Empty Galaxy — barren screen for new users

**Severity**: UX — Day 1 dead end
**File**: `src/app/galaxy/page.tsx`

### Root Cause
A new user arrives at Galaxy with:
- `knownContacts = []` (no spaces → no members → no contacts)
- People tab shows empty state: "your people — share a space link"
- Plans tab shows empty state with a dream input
- No actionable next step. No mention of @xark. No first action.

### Fix
When the user has zero spaces AND zero contacts, show a simple onboarding message in the Galaxy content area that guides them to @xark.

Replace the empty state for the People tab (when `knownContacts.length === 0`) with:

```tsx
<div style={{
  padding: "32px 24px",
  display: "flex",
  flexDirection: "column",
  gap: "12px"
}}>
  <span style={{
    ...text.subtitle,
    color: ink.primary,
    opacity: 0.7
  }}>
    this is your galaxy.
  </span>
  <span style={{
    ...text.hint,
    color: ink.tertiary
  }}>
    tap the xark logo below to search restaurants, plan trips, or start a group.
  </span>
</div>
```

The existing "your people — share a space link" text should remain as a fallback for users who have spaces but no contacts in them.

**Constitutional compliance**: `text.subtitle`, `text.hint`, `ink.primary`, `ink.tertiary` — all from theme.ts. No borders. No bold.

### Verification
- Brand new user (zero spaces): sees "this is your galaxy." + hint about tapping xark
- User with spaces but no contacts: sees existing "your people" empty state
- User with contacts: sees contact list as normal

---

## COMMIT SEQUENCE

Make ONE commit per issue, in this order:

1. `fix(galaxy): hide "chat:" prefix when user has zero contacts`
2. `fix(onboarding): add Spotlight discovery hint for new users`
3. `fix(e2ee): self-key fallback for own-message decryption in solo/group spaces`
4. `fix(galaxy): onboarding message for empty Galaxy`

After all 4 commits, run:
```bash
npx tsc --noEmit
npx vitest run
```

Both must pass before deployment.

---

## FILES TOUCHED

| Issue | File | Lines | Action |
|-------|------|-------|--------|
| 1 | `src/app/galaxy/page.tsx` | 434 | Add `knownContacts.length > 0` condition |
| 2 | `src/components/os/ControlCaret.tsx` | near anchor render | Add breathing hint + localStorage dismiss |
| 3 | `src/lib/crypto/encryption-service.ts` | 755-760 | Add self-key fallback in decrypt path |
| 4 | `src/app/galaxy/page.tsx` | People empty state section | Replace with onboarding copy |

---

## DO NOT

- Do NOT bypass E2EE. Do NOT add plaintext fallback paths. Do NOT suggest "just skip encryption for solo spaces."
- Do NOT use font-weight above 400.
- Do NOT add borders, cards, or rounded containers.
- Do NOT hardcode hex colors — use theme tokens.
- Do NOT use Tailwind text-size classes — use theme.ts `text` object.
- Do NOT modify any file not listed in the FILES TOUCHED table.
- Do NOT refactor surrounding code. Only make the minimal changes described.
