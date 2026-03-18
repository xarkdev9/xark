# POWER PROMPT: WhatsApp-Style Chat Creation

> **For coding agent**: Read CLAUDE.md, CONSTITUTION.md, SECURITY.md first. E2EE ABSOLUTE LAW: never bypass encryption.

**Repository**: `/Users/ramchitturi/xark9`

---

## THE GOAL

Make chat creation work exactly like WhatsApp:

1. User picks a contact (by phone number or name from the `users` table)
2. System checks: does a 1:1 space already exist between these two users?
3. If yes → navigate to it
4. If no → create it instantly with BOTH users as members (no invite link needed)
5. Messages are stored server-side. When the other person opens the app, the chat is already there with all messages waiting

---

## ABSOLUTE CONSTRAINTS

1. **E2EE ABSOLUTE LAW**: NEVER bypass E2EE. NEVER send plaintext. Read CLAUDE.md lines 75-86.
2. **NO BOLD**: font-weight 300/400 only.
3. **THEME TOKENS**: All colors from `src/lib/theme.ts`. No hardcoded hex.
4. **NO BORDERS**: Zero-Box Doctrine.

---

## WHAT TO CHANGE

### Change 1: Server-side "find or create chat" RPC

**File**: Create `supabase/migrations/029_find_or_create_chat.sql`

Create a Postgres RPC that does the WhatsApp logic atomically:

```sql
CREATE OR REPLACE FUNCTION find_or_create_chat(
  p_user_id text,
  p_other_user_id text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_space_id text;
  v_user users%ROWTYPE;
  v_other users%ROWTYPE;
BEGIN
  -- Validate both users exist
  SELECT * INTO v_user FROM users WHERE id = p_user_id;
  SELECT * INTO v_other FROM users WHERE id = p_other_user_id;
  IF v_user IS NULL OR v_other IS NULL THEN
    RETURN jsonb_build_object('error', 'user not found');
  END IF;

  -- Check if a 1:1 sanctuary already exists between these two users
  SELECT sm1.space_id INTO v_space_id
  FROM space_members sm1
  JOIN space_members sm2 ON sm1.space_id = sm2.space_id
  JOIN spaces s ON s.id = sm1.space_id
  WHERE sm1.user_id = p_user_id
    AND sm2.user_id = p_other_user_id
    AND s.atmosphere = 'sanctuary'
  LIMIT 1;

  IF v_space_id IS NOT NULL THEN
    -- Chat already exists — return it
    RETURN jsonb_build_object('spaceId', v_space_id, 'created', false);
  END IF;

  -- Create new sanctuary space
  v_space_id := 'space_' || replace(gen_random_uuid()::text, '-', '');

  INSERT INTO spaces (id, title, owner_id, atmosphere)
  VALUES (
    v_space_id,
    v_user.display_name || ' & ' || v_other.display_name,
    p_user_id,
    'sanctuary'
  );

  -- Add both as members
  INSERT INTO space_members (space_id, user_id, role)
  VALUES (v_space_id, p_user_id, 'owner'),
         (v_space_id, p_other_user_id, 'member')
  ON CONFLICT DO NOTHING;

  -- Seed message
  INSERT INTO messages (id, space_id, role, content, user_id, message_type)
  VALUES (
    'msg_' || gen_random_uuid()::text,
    v_space_id,
    'system',
    'connected. encrypted, always.',
    p_user_id,
    'system'
  );

  RETURN jsonb_build_object('spaceId', v_space_id, 'created', true);
END;
$$;

REVOKE EXECUTE ON FUNCTION find_or_create_chat(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION find_or_create_chat(text, text) TO service_role;
```

### Change 2: New API endpoint for starting a chat

**File**: Create `src/app/api/chat/start/route.ts`

```typescript
import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";
import { checkRateLimit } from "@/lib/rate-limit";

export async function POST(req: NextRequest) {
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  if (!checkRateLimit(`chat:${auth.userId}`, 20, 60_000)) {
    return NextResponse.json({ error: "rate limited" }, { status: 429 });
  }

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "not configured" }, { status: 500 });
  }

  const { otherUserId } = await req.json();
  if (!otherUserId || typeof otherUserId !== "string") {
    return NextResponse.json({ error: "otherUserId required" }, { status: 400 });
  }

  // Cannot chat with yourself
  if (otherUserId === auth.userId) {
    return NextResponse.json({ error: "cannot chat with yourself" }, { status: 400 });
  }

  const { data, error } = await supabaseAdmin.rpc("find_or_create_chat", {
    p_user_id: auth.userId,
    p_other_user_id: otherUserId,
  });

  if (error) {
    console.error("[chat/start] RPC failed:", error.message);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  if (data?.error) {
    return NextResponse.json({ error: data.error }, { status: 400 });
  }

  return NextResponse.json({ spaceId: data.spaceId, created: data.created });
}
```

### Change 3: Client-side — `handleNewChat` uses the new API

**File**: Modify `src/app/galaxy/page.tsx`

Replace the `handleNewChat` function. Instead of calling `createSpace()`, call `/api/chat/start`:

```typescript
const handleNewChat = useCallback(async (contact: { id: string; display_name: string }) => {
  if (!contact.id) return; // No user ID — can't start chat
  setIsCreating(true);
  try {
    const token = getSupabaseToken();
    const res = await fetch("/api/chat/start", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({ otherUserId: contact.id }),
    });

    if (!res.ok) throw new Error(`API error ${res.status}`);

    const { spaceId } = await res.json();
    if (!spaceId) throw new Error("No spaceId returned");

    setShowUserPicker(false);
    setShowNewSheet(false);
    handlePersonTap(spaceId);
  } catch (err) {
    console.error("[chat] start failed:", err);
  } finally {
    setIsCreating(false);
  }
}, [userId, handlePersonTap]);
```

Import `getSupabaseToken` from `@/lib/supabase` at the top of the file.

### Change 4: Fix contact name display in PeopleDock

**File**: Modify `src/lib/awareness.ts` — in `fetchPersonalChats()`

Currently line 277 uses `extractDisplayName(member.user_id)` which strips `phone_` prefix to get `9741783444`. This is wrong — it should show the real name.

After Step 4 (resolving contact members), add a user profile lookup:

```typescript
// After getting otherMembers, fetch their real display names
const otherUserIds = otherMembers.map(m => m.user_id).filter(Boolean);
const { data: userProfiles } = await supabase
  .from("users")
  .select("id, display_name, photo_url")
  .in("id", otherUserIds);

const profileMap = new Map((userProfiles ?? []).map(u => [u.id, u]));
```

Then when building the `PersonalChat` object, use:
```typescript
contactName: profileMap.get(otherMember.user_id)?.display_name ?? extractDisplayName(otherMember.user_id),
contactPhotoUrl: profileMap.get(otherMember.user_id)?.photo_url ?? null,
```

Also add `contactPhotoUrl` to the `PersonalChat` interface if it doesn't exist.

### Change 5: User picker shows ALL registered users

**File**: Modify `src/app/galaxy/page.tsx`

The "New Chat" flow currently shows `allUsers` fetched via:
```typescript
supabase.from("users").select("id, display_name").neq("id", userId)
```

This is correct — it shows all Xark users except yourself. When a user taps one, `handleNewChat` fires with their real `id`. The `find_or_create_chat` RPC handles deduplication (returns existing chat if one exists).

No changes needed here — just verify the picker passes `contact.id` correctly (which was already fixed in a previous commit).

### Change 6: Remove the old `createSpace` from 1:1 chat paths

The `createSpace()` function in `src/lib/spaces.ts` should ONLY be used for GROUP spaces (plans, trips). All 1:1 chat creation must go through `/api/chat/start`.

In `galaxy/page.tsx`:
- `handleNewChat` → uses `/api/chat/start` (Change 3 above)
- `startChat` (dream input) → if the input matches a user's display_name, use `/api/chat/start`. If no match, fall through to group space creation via `createSpace()`.
- `handleNewGroup` → still uses `createSpace()` (groups are not 1:1)

---

## WHAT NOT TO CHANGE

- Do NOT modify E2EE. Do NOT add plaintext paths.
- Do NOT remove the invite/summon system — it's still needed for inviting NEW users who aren't on Xark yet.
- Do NOT modify the space page (`space/[id]/page.tsx`) chat rendering.
- Do NOT rename "Galaxy" to "Home" in this commit — that's a separate UX task.
- Do NOT change font weights, colors, or borders.

---

## COMMIT SEQUENCE

1. `feat(db): migration 029 — find_or_create_chat atomic RPC`
2. `feat(api): POST /api/chat/start — WhatsApp-style find-or-create 1:1 chat`
3. `fix(galaxy): handleNewChat uses /api/chat/start instead of createSpace`
4. `fix(contacts): PeopleDock shows real display names from users table`

After all commits: `npx tsc --noEmit` and `npx vitest run` must pass.

---

## TEST PLAN

1. Phone 999 logs in → sees home screen
2. Phone 444 logs in separately → sees home screen
3. Phone 999 taps + → sees Phone 444 in the user list → taps → `/api/chat/start` fires → space created with both members → navigates to space
4. Phone 999 sends "hello" → message stored in DB
5. Phone 444 opens app → PeopleDock shows the chat with Phone 999's display name → taps → sees "hello" waiting
6. Phone 444 replies "hey" → message encrypted → sent → Phone 999 sees it
7. Phone 999 taps + again → taps Phone 444 → `find_or_create_chat` returns existing space (no duplicate)
