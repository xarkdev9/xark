# POWER PROMPT: Contact Discovery — Android Picker + iOS Invite Fallback

> **For coding agent**: Read CLAUDE.md, CONSTITUTION.md first. E2EE ABSOLUTE LAW: never bypass encryption.

**Repository**: `/Users/ramchitturi/xark9`

---

## THE GOAL

Users need to start chats with real people. The current "On Xark" list is empty because RLS blocks user discovery, and even if it didn't, showing "ram44" to strangers is useless. Nobody knows who "ram44" is.

**WhatsApp's approach**: Your phone's contact list provides the names. The server only confirms which phone numbers are registered. The display name comes from YOUR contacts, not the server.

**Platform reality**:
- **Android PWA (Chrome)**: Contact Picker API works — user picks a contact, we get name + phone number
- **iOS PWA (Safari)**: No contact access at all — Apple blocks it. Fallback to invite link.

---

## CHANGES

### Change 1: Server endpoint — check which phone numbers are registered

**File**: Create `src/app/api/contacts/check/route.ts`

This endpoint takes an array of phone numbers and returns which ones are registered on Xark. It does NOT return display names — the client already has names from the phone's contacts.

```typescript
import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";
import { checkRateLimit } from "@/lib/rate-limit";

export async function POST(req: NextRequest) {
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  if (!checkRateLimit(`contacts:${auth.userId}`, 5, 60_000)) {
    return NextResponse.json({ error: "rate limited" }, { status: 429 });
  }

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "not configured" }, { status: 500 });
  }

  const { phones } = await req.json();
  if (!Array.isArray(phones) || phones.length === 0 || phones.length > 500) {
    return NextResponse.json({ error: "phones array required (max 500)" }, { status: 400 });
  }

  // Normalize: strip all non-digits, keep last 10
  const normalized = phones
    .filter((p): p is string => typeof p === "string")
    .map((p) => p.replace(/\D/g, "").slice(-10))
    .filter((p) => p.length >= 7);

  if (normalized.length === 0) {
    return NextResponse.json({ registered: [] });
  }

  // Build user IDs in the format Xark uses: phone_{last10digits}
  const possibleIds = normalized.map((n) => `phone_${n}`);

  const { data, error } = await supabaseAdmin
    .from("users")
    .select("id, phone")
    .in("id", possibleIds);

  if (error) {
    return NextResponse.json({ error: "lookup failed" }, { status: 500 });
  }

  // Return only phone + userId — NOT display_name (client has names from contacts)
  const registered = (data ?? []).map((u) => ({
    phone: u.phone,
    userId: u.id,
  }));

  return NextResponse.json({ registered });
}
```

### Change 2: Rewrite the "New Chat" flow in Galaxy

**File**: Modify `src/app/galaxy/page.tsx`

Replace the current user picker with a two-path system:

**Path A — Android (Contact Picker API available):**
1. User taps + (compose)
2. Show a sheet with two options: "Pick from contacts" and "Send invite link"
3. "Pick from contacts" uses the Contact Picker API:
```typescript
const contacts = await navigator.contacts.select(
  ["name", "tel"],
  { multiple: false }
);
```
4. Extract the phone number from the selected contact
5. Call `POST /api/contacts/check` with that phone number
6. If registered → call `POST /api/chat/start` with the returned `userId` → navigate to space
7. If NOT registered → trigger invite link flow (generate `/s/[code]` link via `/api/summon` → `navigator.share` with the contact's name in the message)

**Path B — iOS / browsers without Contact Picker:**
1. User taps + (compose)
2. Show a sheet with: a text input "Enter phone number" AND "Send invite link"
3. User types a phone number → call `/api/contacts/check` with that number
4. If registered → call `/api/chat/start` → navigate
5. If NOT registered → "Not on Xark yet. Send invite?" → trigger invite link flow

**Detecting Contact Picker support:**
```typescript
const hasContactPicker = typeof navigator !== "undefined" && "contacts" in navigator && "ContactsManager" in window;
```

**IMPORTANT**: The Contact Picker API requires a user gesture (click/tap). It cannot be called on page load.

**Contact name display**: When the Contact Picker returns a contact, the NAME comes from the phone's address book. When `/api/contacts/check` confirms they're registered, we pass the LOCAL contact name to `handlePersonTap` for display — not the server's display_name. The user sees "Anjan" (from their contacts) not "ram44" (from the server).

### Change 3: Remove the "On Xark" user list

**File**: Modify `src/app/galaxy/page.tsx`

Delete the `fetchAllUsers` function and the `allUsers` state. Delete the "On Xark" section that lists all users. This was broken (RLS blocks it) and wrong (exposing display names to strangers).

Replace with the contact picker + phone number input from Change 2.

### Change 4: RLS policy for contacts check

**File**: Create `supabase/migrations/030_contacts_check.sql`

The `/api/contacts/check` endpoint uses `supabaseAdmin` (service_role), so NO RLS change is needed for that query. The existing `users_select_self` policy stays — users still can't see each other's rows directly.

However, add an index for the phone lookup:

```sql
-- Index for phone number lookup (used by /api/contacts/check)
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
```

That's the only migration needed.

---

## WHAT THE USER SEES

### Android:
1. Tap + → sheet slides up
2. "Pick from contacts" (uses Android contact picker) + "Send invite link"
3. Pick "Anjan" from phone contacts → Xark checks phone number → "Anjan is on Xark!" → chat opens
4. Pick "Mom" from phone contacts → Xark checks → "Mom isn't on Xark yet. Send invite?" → share link via WhatsApp/SMS

### iOS:
1. Tap + → sheet slides up
2. Phone number input field + "Send invite link"
3. Type +91 9741783444 → Xark checks → registered → chat opens
4. Type unknown number → "Not on Xark yet. Send invite?" → share link

---

## CONSTRAINTS

- **E2EE ABSOLUTE LAW**: Never bypass. Read CLAUDE.md.
- **NO BOLD**: weight 300/400 only.
- **THEME TOKENS**: Colors from `src/lib/theme.ts`.
- **NO BORDERS**: Zero-Box Doctrine.
- The server NEVER returns display_name to other users. Only confirms phone registration.
- Contact names come from the user's LOCAL phone contacts, not from the Xark server.
- The Contact Picker API requires HTTPS and a user gesture.

---

## COMMIT SEQUENCE

1. `feat(api): POST /api/contacts/check — phone number registration lookup`
2. `feat(db): migration 030 — phone index for contact lookup`
3. `feat(galaxy): contact picker (Android) + phone input (iOS) + invite fallback`

After all commits: `npx tsc --noEmit` and `npx vitest run` must pass.

---

## DO NOT

- Do NOT expose `users.display_name` to other users via RLS or API
- Do NOT expose `users.phone` to other users — the check endpoint only confirms registration
- Do NOT use the Contact Picker API without a user gesture
- Do NOT remove the invite link system — it's the iOS fallback
- Do NOT remove `createSpace()` — it's still used for group spaces
- Do NOT modify E2EE, font weights, or theme tokens
