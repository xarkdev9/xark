# The Summon Paradigm — Spec

## Vision

You don't "add contacts" in Xark. You **summon co-pilots**. Every connection is a deliberate, cryptographic handshake. The act of inviting a friend is a premium, tactile experience — not boring data entry.

Zero contact permissions. Zero empty states. 100% native feel.

---

## 1. The Summon Action (People Tab)

### Current (broken)
People tab shows an empty contact list with "your people — share a space link" and a confusing "chat:" prefix. New users see a dead screen.

### New
When `knownContacts.length === 0`, the entire People tab becomes the Summon surface:

- **Visual**: Slow-pulsing mesh gradient (Framer Motion, theme-aware — `colors.cyan` at 0.03 opacity, 15s breath).
- **Center**: Large text "summon co-pilot" in `text.subtitle`, `ink.primary`, opacity 0.7. Below it: "send a link. they join your orbit." in `text.hint`, `ink.tertiary`.
- **Tap action**: Generates a single-use cryptographic deep link via `/api/summon`, then triggers `navigator.share()` with the native Share Sheet.
- **Share payload**: `{ title: "xark", text: "${userName} wants to plan with you", url: "https://xark.app/s/${code}" }`
- **Fallback** (if `navigator.share` unavailable): copy link to clipboard, show whisper "link copied".

When `knownContacts.length > 0`, the People tab shows the existing contact list PLUS a smaller "summon another" text at the bottom.

### Constitutional compliance
- No borders, no cards. Mesh gradient floats.
- `text.subtitle` + `text.hint` from theme.ts. No bold.
- `ink.primary` + `ink.tertiary`. No hardcoded colors.

---

## 2. The Summon Link System

### Database: `summon_links` table (migration 028)

```sql
CREATE TABLE summon_links (
  code text PRIMARY KEY,                    -- 16-byte hex (128-bit entropy)
  creator_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  claimed_by text REFERENCES users(id),     -- NULL until claimed
  claimed_at timestamptz,
  space_id text REFERENCES spaces(id),      -- The 2-player space created on claim
  expires_at timestamptz NOT NULL DEFAULT now() + interval '7 days'
);

CREATE INDEX idx_summon_creator ON summon_links(creator_id);
CREATE INDEX idx_summon_expires ON summon_links(expires_at) WHERE claimed_by IS NULL;
```

RLS:
- SELECT: creator can see their own links. Claimant can see links they claimed.
- INSERT: authenticated users only, `creator_id = auth.jwt()->>'sub'`.
- UPDATE: service_role only (claim happens server-side).
- No public read of unclaimed links (prevents enumeration).

### API: `POST /api/summon` — Generate link

```
Request: { } (auth required via JWT)
Response: { code: "a3f8b2c1d4e5f678", url: "https://xark.app/s/a3f8b2c1d4e5f678" }
```

- Generates 16-byte random hex code (`crypto.randomBytes(16).toString('hex')`)
- Inserts into `summon_links` with `creator_id` from JWT
- Rate limit: 10 per hour per user
- Returns the full URL

### API: `POST /api/summon/claim` — Claim link + create space

```
Request: { code: "a3f8b2c1...", firebaseToken: "..." }
Response: { token: "jwt...", user: { id, displayName }, spaceId: "space_..." }
```

- Validates the summon code exists, is unclaimed, and not expired
- Authenticates the claimant via Firebase token (same as `/api/phone-auth`)
- Creates the claimant's user record if new (or finds existing)
- Creates a 2-player space: title = `${creator.display_name} & ${claimant.display_name}`, atmosphere = `"sanctuary"`
- Adds both users as space members
- Updates `summon_links`: `claimed_by`, `claimed_at`, `space_id`
- Returns JWT + user + spaceId (claimant is redirected to the space)
- The creator gets a Realtime notification (space_members INSERT fires → AwarenessStream picks it up)

---

## 3. The Landing Page: `/s/[code]`

### New file: `src/app/s/[code]/page.tsx`

When someone clicks the summon link:

1. **Validate code**: fetch link metadata (creator name, expiry) from `/api/summon/validate?code=X`
2. **Show invitation**: "${creatorName} wants to plan with you" + "xark" wordmark + "begin" button
3. **On "begin"**: trigger phone auth flow (same as login page — phone number → OTP → name → photo)
4. **On auth complete**: call `/api/summon/claim` with the code + Firebase token
5. **Redirect**: navigate to `/space/${spaceId}` — the 2-player space is waiting

### Visual
- Dark background (#050508), same as login
- Creator's name in `text.hero`, white, centered
- "wants to plan with you" in `text.subtitle`, opacity 0.5
- "begin" button — same as WelcomeScreen (floating text, not a button)
- After auth: breathing brand orange dot + "creating your space..." morph (800ms) → redirect

---

## 4. Spotlight Summon Fallback

### In ControlCaret.tsx / SpotlightSheet.tsx

When the user types a name in the Spotlight that doesn't match any known contact:

1. User types "text anjan" or just "anjan"
2. Spotlight searches `knownContacts` for a match
3. **No match found**: the GhostInput morphs to show: "anjan isn't in your orbit. tap to summon."
4. Tapping fires the same summon flow: generate link → `navigator.share()` → native share sheet
5. The share text says: "hey anjan, join me on xark: {url}"

### Implementation
- Add a `onNoMatch` callback to SpotlightSheet
- When send fires and the text looks like a person name (no "@xark" prefix, single word or two words), check against known contacts
- If no match: show the summon fallback instead of creating a space

---

## 5. The 2-Player Space

When the summon is claimed, the auto-created space is a full Xark space:
- Title: "${creator} & ${claimant}" (shown as claimant's name for creator, creator's name for claimant — sanctuary dynamic title already built)
- Atmosphere: `"sanctuary"` (tabs hidden, pure chat — already built in previous commit)
- Seed message: "you're connected. encrypted, always." (system message)
- Both users have key bundles registered → E2EE Sender Key distribution works immediately
- PossibilityHorizon exists but is accessed via @xark Spotlight, not tabs
- Taste Graph works — both users' preferences are intersected at search time

---

## 6. What Gets Removed/Replaced

| Current | Replaced by |
|---------|-------------|
| Empty People tab "your people — share a space link" | Summon surface with mesh gradient |
| "chat:" prefix on People input | Removed (already fixed, but now the input itself changes purpose) |
| Galaxy dream input creating spaces from names | Spotlight handles @xark queries; dream input is for plan creation only |
| `/j/[token]` invite flow | Stays for group invites; `/s/[code]` is for 1-on-1 summons |
| Contact picker / user picker | Replaced by summon; existing contacts still shown in People tab |

---

## 7. E2EE Compliance

- Summon links are Layer 3 metadata (code, creator, claimant, timestamps). No message content.
- The 2-player space uses the standard E2EE pipeline (Sender Keys for group, Double Ratchet for 1:1 if sanctuary).
- Key exchange happens naturally when both users open the space (useE2EE hook).
- No plaintext fallback. Ever.

---

## 8. Migration 028: summon_links

```sql
-- XARK OS v2.0 — Summon Links
-- Single-use cryptographic invite links for 1-on-1 connections.

CREATE TABLE summon_links (
  code text PRIMARY KEY,
  creator_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  claimed_by text REFERENCES users(id) ON DELETE SET NULL,
  claimed_at timestamptz,
  space_id text REFERENCES spaces(id) ON DELETE SET NULL,
  expires_at timestamptz NOT NULL DEFAULT now() + interval '7 days'
);

CREATE INDEX idx_summon_creator ON summon_links(creator_id);
CREATE INDEX idx_summon_expires ON summon_links(expires_at) WHERE claimed_by IS NULL;

ALTER TABLE summon_links ENABLE ROW LEVEL SECURITY;

-- Creator can see their own links
CREATE POLICY "summon_select_creator" ON summon_links
  FOR SELECT USING (creator_id = (auth.jwt()->>'sub'));

-- Claimant can see links they claimed
CREATE POLICY "summon_select_claimant" ON summon_links
  FOR SELECT USING (claimed_by = (auth.jwt()->>'sub'));

-- Authenticated users can create links
CREATE POLICY "summon_insert" ON summon_links
  FOR INSERT WITH CHECK (creator_id = (auth.jwt()->>'sub'));

-- RPC for atomic claim (service_role only)
CREATE OR REPLACE FUNCTION claim_summon_link(
  p_code text,
  p_claimant_id text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_link summon_links%ROWTYPE;
  v_creator users%ROWTYPE;
  v_claimant users%ROWTYPE;
  v_space_id text;
BEGIN
  -- Fetch and lock the link
  SELECT * INTO v_link FROM summon_links
    WHERE code = p_code AND claimed_by IS NULL AND expires_at > now()
    FOR UPDATE SKIP LOCKED;

  IF v_link IS NULL THEN
    RETURN jsonb_build_object('error', 'link expired or already claimed');
  END IF;

  -- Cannot summon yourself
  IF v_link.creator_id = p_claimant_id THEN
    RETURN jsonb_build_object('error', 'cannot summon yourself');
  END IF;

  -- Fetch both users
  SELECT * INTO v_creator FROM users WHERE id = v_link.creator_id;
  SELECT * INTO v_claimant FROM users WHERE id = p_claimant_id;

  IF v_creator IS NULL OR v_claimant IS NULL THEN
    RETURN jsonb_build_object('error', 'user not found');
  END IF;

  -- Create 2-player space
  v_space_id := 'space_' || replace(gen_random_uuid()::text, '-', '');

  INSERT INTO spaces (id, title, owner_id, atmosphere)
  VALUES (
    v_space_id,
    v_creator.display_name || ' & ' || v_claimant.display_name,
    v_link.creator_id,
    'sanctuary'
  );

  -- Add both as members
  INSERT INTO space_members (space_id, user_id, role)
  VALUES (v_space_id, v_link.creator_id, 'owner'),
         (v_space_id, p_claimant_id, 'member');

  -- Seed message
  INSERT INTO messages (id, space_id, role, content, user_id, message_type)
  VALUES (
    'msg_' || gen_random_uuid()::text,
    v_space_id,
    'system',
    'connected. encrypted, always.',
    v_link.creator_id,
    'system'
  );

  -- Claim the link
  UPDATE summon_links
  SET claimed_by = p_claimant_id, claimed_at = now(), space_id = v_space_id
  WHERE code = p_code;

  RETURN jsonb_build_object(
    'spaceId', v_space_id,
    'creatorName', v_creator.display_name,
    'claimantName', v_claimant.display_name
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION claim_summon_link(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION claim_summon_link(text, text) TO service_role;

-- Cron cleanup: purge expired unclaimed links (add to existing purge cron)
CREATE OR REPLACE FUNCTION purge_expired_summon_links()
RETURNS integer
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  WITH deleted AS (
    DELETE FROM summon_links
    WHERE expires_at < now() AND claimed_by IS NULL
    RETURNING code
  )
  SELECT count(*)::integer FROM deleted;
$$;

REVOKE EXECUTE ON FUNCTION purge_expired_summon_links() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION purge_expired_summon_links() TO service_role;
```
