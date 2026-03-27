# UserMenu Redesign — Design Spec

**Goal:** Redesign the UserMenu settings sheet to follow WhatsApp's flat-scannable pattern, support the 4-theme system (hearth, hearth_dark, vibe, vibe_dark), wire FCM notification preferences, and provide an app-level invite flow for growth.

**Architecture:** Hybrid approach — profile card + theme toggles inline on main screen, notifications and about as drill-in views. Avatar trigger moves from floating fixed position into the Galaxy page header row (aligned with `people · plans · memories` tabs). Sheet slides down from top. All text uses the `ink.*` solid color system.

**Tech Stack:** React 19, Framer Motion (AnimatePresence slide transitions), Supabase (users table, space_members, user_devices), Firebase (Storage for avatar, FCM for push), `ink.*` + `colors.*` from theme.ts.

**Prerequisite:** Update CLAUDE.md theme system section from "1 Theme" to reflect the 4-theme reality (hearth, hearth_dark, vibe, vibe_dark) before implementation begins.

---

## 1. Avatar Trigger Relocation

**Current:** `GlobalUserMenu` renders a `position: fixed; right: 24px; top: 46px + safe-area` avatar trigger. Disconnected from page content flow.

**New:** Avatar trigger (32px) moves into the Galaxy page tab header as a flex item.

```
┌──────────────────────────────────────────┐
│  people · plans · memories       [avatar]│
└──────────────────────────────────────────┘
```

- Galaxy page header becomes `display: flex; justify-content: space-between; align-items: center`
- Left side: tab labels (existing)
- Right side: 32px avatar (click opens UserMenu sheet)
- `GlobalUserMenu.tsx` deleted — `UserMenu` imported and rendered directly inside `GalaxyContent()` in `galaxy/page.tsx`
- `src/app/layout.tsx` — remove `<GlobalUserMenu />` import and usage
- UserMenu only exists on Galaxy page. Not on login, not inside spaces.

## 2. Main Screen

Top-down sheet, `colors.void` background, `layout.maxWidth` centered. Auto-height (content determines sheet height), `max-height: 80vh`, `overflow-y: auto` for long content.

```
[48px avatar]  ram
               +1 (555) 123-4567  →

flat · vibe
light · dark

notifications →
invite a friend
about →

log out
```

### Profile Card (top)
- 48px avatar (photo from `users.photo_url`, fallback to initial letter)
- Name: `text.body`, `ink.primary`
- Phone: `text.recency`, `ink.tertiary` (read from `users.phone` column)
  - If `users.phone` is null (name-only / dev auth mode): hide phone row entirely. Only show name.
- Arrow/chevron hint that card is tappable
- Tap anywhere on card → drill into Profile Edit view

### Theme Toggles (inline)
- Two rows of text toggles, no drill-in required
- Row 1: `flat · vibe` — style axis
- Row 2: `light · dark` — mode axis
- Active word: `colors.cyan`
- Inactive word: `ink.tertiary`
- Tap toggles instantly, theme applies via `setTheme()` from ThemeProvider context
- Mapping: flat+light = `hearth`, flat+dark = `hearth_dark`, vibe+light = `vibe`, vibe+dark = `vibe_dark`
- **Persistence:** Theme saved to both `localStorage` (instant restore on next load) and `users.preferences.theme` in Supabase (cross-device sync). Write to Supabase on toggle. On page load, localStorage wins (faster), but if Supabase has a different value and localStorage is empty, use Supabase value.

### Menu Rows
- `notifications →` — `text.body`, `ink.secondary`, drills into Notifications view
- `invite a friend` — `text.body`, `ink.secondary`, inline action (no drill)
  - Tap → `navigator.share({ title: "xark", text: "decide together, effortlessly.", url: "https://getxark.com" })` on mobile
  - Fallback → `navigator.clipboard.writeText("https://getxark.com")` on desktop
  - Text changes to "link copied" for 1.5s
- `about →` — `text.body`, `ink.secondary`, drills into About view
- Hover/tap: `ink.secondary` → `ink.primary` transition

### Log Out (bottom)
- `text.recency`, `ink.tertiary`
- Tap → Firebase `signOut()` + `setSupabaseToken(null)` + redirect to `/login`

## 3. Profile Edit View (drill-in)

Slide-right animation (existing AnimatePresence + direction pattern).

```
back

[48px avatar]
change photo

name
[ram_______________]
                saved

phone
+1 (555) 123-4567
```

- **"back"**: `text.recency`, `ink.tertiary` → taps back to main
- **Avatar**: 48px, same component as main screen
- **"change photo"**: `text.hint`, `ink.tertiary`. Tap → hidden file input → Firebase Storage upload to `profiles/{userId}/avatar` → update `users.photo_url`. Shows breathing cyan dot + "uploading" during upload. Max 2MB — if exceeded, show "too large" whisper for 1.5s (same pattern as "saved").
- **Name input**: `text.input`, `ink.primary`, `caretColor: colors.cyan`. Accent underline below. Save on blur or Enter. "saved" whisper (`text.hint`, `ink.tertiary`, 0→0.4 opacity, fades after 1.5s).
- **Phone display**: read-only. `text.body`, `ink.primary` for number. `text.recency`, `ink.tertiary` for "phone" label. Not editable — phone is auth identity. If `users.phone` is null, hide phone section entirely.
- **Field labels** ("name", "phone"): `text.recency`, `ink.tertiary`, positioned above each field.
- All interactive elements preserve `role="button"`, `tabIndex={0}`, `onKeyDown` for keyboard accessibility.

## 4. Notifications View (drill-in)

```
back

push notifications
on · off

spaces

san diego trip              on
tokyo neon nights           on
summer 2026                off
ananya                      on
```

### Master Toggle
- `on · off` text toggle (same pattern as theme toggles)
- Active: `colors.cyan`, inactive: `ink.tertiary`
- **First enable flow:**
  1. User taps "on"
  2. Browser `Notification.requestPermission()` fires
  3. If granted: get FCM token via lazy `import("firebase/messaging")` → `getToken(messaging, { vapidKey: process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY })`
  4. `src/lib/firebase.ts` must be extended to export a `messaging` instance (same null-safe pattern as `auth` and `storage`). Requires `NEXT_PUBLIC_FIREBASE_VAPID_KEY` env var.
  5. Store token in `user_devices` table: `{ user_id, fcm_token, platform: "web" }`
  6. Toggle shows "on" in accent color
  7. If denied: toggle reverts to "off", brief whisper "blocked by browser" for 1.5s
- **Disable flow:** delete FCM token row from `user_devices`

### Per-Space Mute List
- Only visible when master toggle is "on"
- Fetched from `space_members` joined with `spaces.title` — all spaces user belongs to
- **Loading state:** breathing cyan dot + "loading" whisper (same as photo upload pattern)
- **Empty state:** "no spaces yet" in `text.hint`, `ink.tertiary`
- **Error state:** silently show empty list (no error message — graceful degradation)
- Each row: space title (`text.body`, `ink.primary`) + `on`/`off` toggle (right-aligned, `ink.tertiary` / `colors.cyan`)
- **Storage:** `users.preferences` JSONB field, key `muted_spaces: string[]`
- **Null handling:** If `preferences` is null or `muted_spaces` key is missing, treat as empty array (no spaces muted). Server-side: `COALESCE(preferences->'muted_spaces', '[]'::jsonb)`.
- **Server-side enforcement:** `/api/notify` fetches target user's `preferences.muted_spaces` before sending push. If `space_id` is in `muted_spaces`, skip that user's devices.

### "spaces" Section Label
- `text.recency`, `ink.tertiary`
- Divider between master toggle and space list

## 5. About View (drill-in)

```
back

xark os
v2.0

feedback
```

- **"back"**: `text.recency`, `ink.tertiary` → taps back to main (same styling as Profile and Notifications back links)
- **"xark os"**: `text.body`, `ink.primary`
- **"v2.0"**: `text.recency`, `ink.tertiary` — read from `package.json` version field
- **"feedback"**: `text.body`, `ink.secondary` → `ink.primary` on hover. Tap opens `https://github.com/anthropics/claude-code/issues` (placeholder — replace with actual feedback URL before launch)
- Room for future additions: privacy policy, terms, licenses

## 6. Data Model Changes

### users.preferences JSONB
Add `muted_spaces` key (no migration needed — JSONB handles missing keys):
```json
{
  "theme": "hearth",
  "muted_spaces": ["space_summer-2026"]
}
```
Null-safe: if `preferences` is null or `muted_spaces` is absent, treat as `[]`.

### user_devices table (existing)
```sql
user_devices (
  user_id text REFERENCES users(id),
  fcm_token text NOT NULL,
  platform text DEFAULT 'web',
  created_at timestamptz,
  PRIMARY KEY (user_id, fcm_token)
)
```
FCM token registration triggered by notification enable toggle. Token row deleted on disable.

### /api/notify changes
Before sending push, check the target user's `preferences.muted_spaces`:
- Fetch `users.preferences` for each target user alongside device tokens
- If `space_id` is in `COALESCE(preferences->'muted_spaces', '[]')`, skip that user's devices
- Users with null preferences or missing `muted_spaces` key receive all notifications (default: not muted)

## 7. Component Architecture

### Files Modified
- `src/app/galaxy/page.tsx` — avatar trigger moves into header row, `UserMenu` imported and rendered here
- `src/components/os/UserMenu.tsx` — full rewrite: new main screen, theme toggles, notification/about drill-ins
- `src/app/layout.tsx` — remove `<GlobalUserMenu />` import and usage
- `src/app/api/notify/route.ts` — check muted_spaces before sending push
- `src/lib/firebase.ts` — export `messaging` instance (null-safe, same pattern as `auth`/`storage`)

### Files Deleted
- `src/components/os/GlobalUserMenu.tsx` — no longer needed

### Files Created
- None — all changes fit in existing files

### View Architecture (inside UserMenu.tsx)
```
SettingsView = "main" | "profile" | "notifications" | "about"
```
AnimatePresence with directional slide (existing pattern). Direction tracked for back animation.

## 8. Deferred (Not in Launch)

- Account settings (billing, 2FA)
- Privacy controls (read receipts, last seen, profile visibility)
- Per-space archive/leave from settings
- Storage and data management
- Chat lock (biometric)
- Per-space invite from settings (already handled by space page "share" button)
- Log out confirmation (no undo window for now)
- Theme cross-fade transition (instant swap is fine for launch)

## 9. Migration

No new migration required. `users.preferences` JSONB column already exists (migration 013). `user_devices` table already exists. Only server-side logic changes in `/api/notify` for `muted_spaces` check. `firebase.ts` extended with `messaging` export.
