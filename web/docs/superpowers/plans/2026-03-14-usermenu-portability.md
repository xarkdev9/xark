# UserMenu Redesign + Portability Layer — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a provider-agnostic portability layer (storage adapter, user ID utilities, config externalization), then redesign the UserMenu settings sheet to support 4-theme system, FCM notifications, invite flow, and WhatsApp-style flat-scannable layout.

**Architecture:** Portability layer creates three abstraction units: `StorageAdapter` interface (swappable blob storage), user ID utilities (format-agnostic identity construction/stripping), and env-var-driven config (Apify actors, Gemini model). UserMenu is then rewritten as a 4-view drill-in sheet (main → profile, notifications, about) with theme toggles inline on main, FCM wiring, and invite action.

**Tech Stack:** TypeScript, React 19, Framer Motion, Firebase Storage/Auth/FCM, Supabase Postgres, Next.js 15.

**Specs:**
- `docs/superpowers/specs/2026-03-14-portability-layer-design.md`
- `docs/superpowers/specs/2026-03-14-usermenu-redesign-design.md`

---

## Chunk 1: Portability Layer

### Task 1: Create User ID Utilities (`src/lib/user-id.ts`)

**Files:**
- Create: `src/lib/user-id.ts`

- [ ] **Step 1: Create user-id.ts**

```typescript
// src/lib/user-id.ts
// Centralizes user ID format logic. Replaces 14 hardcoded prefix instances.

export type UserIdType = "name" | "phone";

const PREFIXES: Record<UserIdType, string> = {
  name: "name_",
  phone: "phone_",
};

export function makeUserId(type: UserIdType, value: string): string {
  return `${PREFIXES[type]}${value}`;
}

export function extractDisplayName(userId: string): string {
  for (const prefix of Object.values(PREFIXES)) {
    if (userId.startsWith(prefix)) return userId.slice(prefix.length);
  }
  // Legacy "user_" prefix from ai-grounding.ts
  if (userId.startsWith("user_")) return userId.slice(5);
  return userId;
}

export function getUserIdType(userId: string): UserIdType | "unknown" {
  for (const [type, prefix] of Object.entries(PREFIXES)) {
    if (userId.startsWith(prefix)) return type as UserIdType;
  }
  return "unknown";
}
```

- [ ] **Step 2: Commit**

```bash
git add src/lib/user-id.ts
git commit -m "feat: add user ID utilities — centralized prefix logic"
```

---

### Task 2: Update All User ID Construction Sites (9 instances)

**Files:**
- Modify: `src/hooks/useAuth.ts:126` — `name_${name}` → `makeUserId("name", name)`
- Modify: `src/app/galaxy/page.tsx:40` — `name_${userName}` → `makeUserId("name", userName)`
- Modify: `src/app/login/page.tsx:222` — `name_${name.trim().toLowerCase()}` → `makeUserId("name", name.trim().toLowerCase())`
- Modify: `src/app/api/join/route.ts:40` — `name_${safeName}` → `makeUserId("name", safeName)`
- Modify: `src/app/api/phone-auth/route.ts:94` — `phone_${phoneDigits}` → `makeUserId("phone", phoneDigits)`
- Modify: `src/components/os/UserMenu.tsx:42,90,107` — 3 instances of `name_${...}` → `makeUserId("name", ...)`
- Modify: `src/lib/seed.ts:62` — `name_${u.name}` → `makeUserId("name", u.name)`

- [ ] **Step 1: Update useAuth.ts**

Add import at top:
```typescript
import { makeUserId } from "@/lib/user-id";
```

Change line 126:
```typescript
// Before:
setUser({ uid: `name_${name}`, displayName: name });
// After:
setUser({ uid: makeUserId("name", name), displayName: name });
```

- [ ] **Step 2: Update galaxy/page.tsx**

Add import:
```typescript
import { makeUserId } from "@/lib/user-id";
```

Change line 40:
```typescript
// Before:
const userId = user?.uid ?? `name_${userName}`;
// After:
const userId = user?.uid ?? makeUserId("name", userName);
```

- [ ] **Step 3: Update login/page.tsx**

Add import:
```typescript
import { makeUserId } from "@/lib/user-id";
```

Change line 222:
```typescript
// Before:
const userId = `name_${name.trim().toLowerCase()}`;
// After:
const userId = makeUserId("name", name.trim().toLowerCase());
```

- [ ] **Step 4: Update api/join/route.ts**

Add import:
```typescript
import { makeUserId } from "@/lib/user-id";
```

Change line 40:
```typescript
// Before:
const userId = `name_${safeName}`;
// After:
const userId = makeUserId("name", safeName);
```

- [ ] **Step 5: Update api/phone-auth/route.ts**

Add import:
```typescript
import { makeUserId } from "@/lib/user-id";
```

Change line 94:
```typescript
// Before:
const userId = `phone_${phoneDigits}`;
// After:
const userId = makeUserId("phone", phoneDigits);
```

- [ ] **Step 6: Update UserMenu.tsx (3 instances)**

Add import:
```typescript
import { makeUserId } from "@/lib/user-id";
```

Change line 42:
```typescript
// Before:
const userId = `name_${userName.toLowerCase()}`;
// After:
const userId = makeUserId("name", userName.toLowerCase());
```

Change line 90:
```typescript
// Before:
const userId = `name_${userName.toLowerCase()}`;
// After:
const userId = makeUserId("name", userName.toLowerCase());
```

Change line 107:
```typescript
// Before:
const userId = `name_${userName.toLowerCase()}`;
// After:
const userId = makeUserId("name", userName.toLowerCase());
```

- [ ] **Step 7: Update seed.ts**

Add import:
```typescript
import { makeUserId } from "@/lib/user-id";
```

Change line 62:
```typescript
// Before:
id: `name_${u.name}`,
// After:
id: makeUserId("name", u.name),
```

- [ ] **Step 8: Commit**

```bash
git add src/hooks/useAuth.ts src/app/galaxy/page.tsx src/app/login/page.tsx \
  src/app/api/join/route.ts src/app/api/phone-auth/route.ts \
  src/components/os/UserMenu.tsx src/lib/seed.ts
git commit -m "refactor: replace 9 hardcoded user ID constructions with makeUserId()"
```

---

### Task 3: Update All User ID Stripping Sites (5 instances)

**Files:**
- Modify: `src/lib/ai-grounding.ts:169` — `.replace(...)` → `extractDisplayName(ownerId)`
- Modify: `src/lib/ledger.ts:49-50` — `displayName()` function → `extractDisplayName()`
- Modify: `src/lib/awareness.ts:276` — `.replace(/^name_/, "")` → `extractDisplayName(member.user_id)`
- Modify: `src/components/os/ClaimSheet.tsx:49` — `.replace(/^name_/, "")` → `extractDisplayName(userId)`
- Modify: `src/components/os/PurchaseSheet.tsx:80` — `.replace(/^name_/, "")` → `extractDisplayName(userId)`

- [ ] **Step 1: Update ai-grounding.ts**

Add import:
```typescript
import { extractDisplayName } from "@/lib/user-id";
```

Change line 169:
```typescript
// Before:
ownerName: ownerId.replace(/^user_/, "").replace(/^name_/, ""),
// After:
ownerName: extractDisplayName(ownerId),
```

- [ ] **Step 2: Update ledger.ts**

Add import:
```typescript
import { extractDisplayName } from "@/lib/user-id";
```

Replace the local `displayName` function (lines 49-51):
```typescript
// Before:
function displayName(userId: string): string {
  return userId.replace(/^user_/, "").replace(/^name_/, "");
}

// After: delete the function entirely — use extractDisplayName from import.
```

Then update all call sites in the file: `displayName(...)` → `extractDisplayName(...)`.

- [ ] **Step 3: Update awareness.ts**

Add import:
```typescript
import { extractDisplayName } from "@/lib/user-id";
```

Change line 276:
```typescript
// Before:
contactBySpace.set(member.space_id, member.user_id.replace(/^name_/, ""));
// After:
contactBySpace.set(member.space_id, extractDisplayName(member.user_id));
```

- [ ] **Step 4: Update ClaimSheet.tsx**

Add import:
```typescript
import { extractDisplayName } from "@/lib/user-id";
```

Change line 49:
```typescript
// Before:
setWhisper(`${userId.replace(/^name_/, "")} is on it`);
// After:
setWhisper(`${extractDisplayName(userId)} is on it`);
```

- [ ] **Step 5: Update PurchaseSheet.tsx**

Add import:
```typescript
import { extractDisplayName } from "@/lib/user-id";
```

Change line 80:
```typescript
// Before:
const name = userId.replace(/^name_/, "");
// After:
const name = extractDisplayName(userId);
```

- [ ] **Step 6: Commit**

```bash
git add src/lib/ai-grounding.ts src/lib/ledger.ts src/lib/awareness.ts \
  src/components/os/ClaimSheet.tsx src/components/os/PurchaseSheet.tsx
git commit -m "refactor: replace 5 hardcoded user ID strippings with extractDisplayName()"
```

---

### Task 4: Create Storage Adapter (`src/lib/storage.ts`)

**Files:**
- Create: `src/lib/storage.ts`

- [ ] **Step 1: Create storage.ts**

```typescript
// src/lib/storage.ts
// Provider-agnostic storage interface. Firebase implementation is default.
// To switch providers: implement StorageAdapter, swap the export.

import { storage } from "@/lib/firebase";
import { ref, uploadBytes, getDownloadURL, deleteObject } from "firebase/storage";

export interface StorageAdapter {
  upload(path: string, file: File | Blob, contentType?: string): Promise<string>; // returns public URL
  delete(path: string): Promise<void>;
}

class FirebaseStorageAdapter implements StorageAdapter {
  async upload(path: string, file: File | Blob, contentType?: string): Promise<string> {
    if (!storage) throw new Error("Firebase Storage not configured");
    const storageRef = ref(storage, path);
    await uploadBytes(storageRef, file, contentType ? { contentType } : undefined);
    return getDownloadURL(storageRef);
  }

  async delete(path: string): Promise<void> {
    if (!storage) throw new Error("Firebase Storage not configured");
    await deleteObject(ref(storage, path));
  }
}

export const storageAdapter: StorageAdapter = new FirebaseStorageAdapter();
```

- [ ] **Step 2: Commit**

```bash
git add src/lib/storage.ts
git commit -m "feat: add storage adapter — provider-agnostic blob storage interface"
```

---

### Task 5: Update All Storage Upload Call Sites (4 files)

**Files:**
- Modify: `src/lib/media.ts:40-45` — `uploadBytes` + `getDownloadURL` → `storageAdapter.upload()`
- Modify: `src/lib/spaces.ts:131-136` — hero image upload → `storageAdapter.upload()`
- Modify: `src/components/os/UserMenu.tsx:108-111` — avatar upload → `storageAdapter.upload()`
- Modify: `src/app/login/page.tsx:223-225` — login avatar upload → `storageAdapter.upload()`

- [ ] **Step 1: Update media.ts**

Replace Firebase imports with storage adapter:
```typescript
// Before:
import { storage } from "@/lib/firebase";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";

// After:
import { storageAdapter } from "@/lib/storage";
```

Update `uploadMedia` function (lines 34-45):
```typescript
// Before:
if (!storage) {
  console.warn("Firebase Storage not configured");
  return null;
}
const mediaId = `media_${generateId()}`;
const storagePath = `spaces/${spaceId}/media/${mediaId}`;
const storageRef = ref(storage, storagePath);
await uploadBytes(storageRef, file);
const downloadUrl = await getDownloadURL(storageRef);

// After:
const mediaId = `media_${generateId()}`;
const storagePath = `spaces/${spaceId}/media/${mediaId}`;
let downloadUrl: string;
try {
  downloadUrl = await storageAdapter.upload(storagePath, file, file.type);
} catch {
  console.warn("Storage not configured");
  return null;
}
```

- [ ] **Step 2: Update spaces.ts**

Replace Firebase Storage imports with storage adapter. In the import section, remove `ref, uploadBytes, getDownloadURL` from firebase/storage and `storage` from firebase. Add:
```typescript
import { storageAdapter } from "@/lib/storage";
```

Update hero image upload (lines 131-136):
```typescript
// Before:
if (storage) {
  try {
    const storagePath = `heroes/${spaceId}/hero.jpg`;
    const storageRef = ref(storage, storagePath);
    await uploadBytes(storageRef, photo.imageBlob, { contentType: "image/jpeg" });
    heroUrl = await getDownloadURL(storageRef);
  } catch {
    // Firebase upload failed — fall back to Unsplash URL
  }
}

// After:
try {
  const storagePath = `heroes/${spaceId}/hero.jpg`;
  heroUrl = await storageAdapter.upload(storagePath, photo.imageBlob, "image/jpeg");
} catch {
  // Storage upload failed — fall back to Unsplash URL
}
```

- [ ] **Step 3: Update UserMenu.tsx**

Remove Firebase Storage imports:
```typescript
// Remove these:
import { storage } from "@/lib/firebase";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
```

Add:
```typescript
import { storageAdapter } from "@/lib/storage";
```

Update `handlePhotoSelect` (lines 99-121):
```typescript
// Before:
if (!storage) return;
...
const storageRef = ref(storage, storagePath);
await uploadBytes(storageRef, file);
const downloadUrl = await getDownloadURL(storageRef);

// After:
try {
  const userId = makeUserId("name", userName.toLowerCase());
  const storagePath = `profiles/${userId}/avatar`;
  const downloadUrl = await storageAdapter.upload(storagePath, file);
  await supabase
    .from("users")
    .update({ photo_url: downloadUrl })
    .eq("id", userId);
  setPhotoUrl(downloadUrl);
} catch (err) {
  console.error("Photo upload failed:", err);
}
```

- [ ] **Step 4: Update login/page.tsx**

Remove Firebase Storage imports:
```typescript
// Remove:
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
// Keep: import { storage } from "@/lib/firebase"; ONLY if used elsewhere (check auth usage)
// If storage is the only firebase import, remove entirely
```

Add:
```typescript
import { storageAdapter } from "@/lib/storage";
```

Update `handlePhotoSelect` (lines 217-230):
```typescript
// Before:
if (!storage) { goToGalaxy(); return; }
if (file.size > 2 * 1024 * 1024) { goToGalaxy(); return; }
setPhotoUploading(true);
try {
  const userId = `name_${name.trim().toLowerCase()}`;
  const storageRef = ref(storage, `profiles/${userId}/avatar`);
  await uploadBytes(storageRef, file);
  const downloadUrl = await getDownloadURL(storageRef);
  await supabase.from("users").update({ photo_url: downloadUrl }).eq("id", userId);
} catch { /* continue */ }

// After:
if (file.size > 2 * 1024 * 1024) { goToGalaxy(); return; }
setPhotoUploading(true);
try {
  const userId = makeUserId("name", name.trim().toLowerCase());
  const downloadUrl = await storageAdapter.upload(`profiles/${userId}/avatar`, file);
  await supabase.from("users").update({ photo_url: downloadUrl }).eq("id", userId);
} catch { /* continue */ }
```

- [ ] **Step 5: Verify build**

Run: `npx next build`
Expected: Clean build, no type errors.

- [ ] **Step 6: Commit**

```bash
git add src/lib/media.ts src/lib/spaces.ts src/components/os/UserMenu.tsx src/app/login/page.tsx
git commit -m "refactor: replace 4 Firebase Storage call sites with storageAdapter"
```

---

### Task 6: Externalize Config — Apify Actor IDs + Gemini Model

**Files:**
- Modify: `src/lib/intelligence/tool-registry.ts:29,46,60,74` — env var actor IDs with fallback
- Modify: `src/lib/intelligence/orchestrator.ts:119` — env var model name

- [ ] **Step 1: Update tool-registry.ts**

Change the 4 Apify actor registrations to read from env vars with fallback:

```typescript
// hotel (line 29):
// Before:
actorId: "voyager/booking-scraper",
// After:
actorId: process.env.APIFY_HOTEL_ACTOR || "voyager/booking-scraper",

// flight (line 46):
// Before:
actorId: "johnvc/Google-Flights-Data-Scraper-Flight-and-Price-Search",
// After:
actorId: process.env.APIFY_FLIGHT_ACTOR || "johnvc/Google-Flights-Data-Scraper-Flight-and-Price-Search",

// activity (line 60):
// Before:
actorId: "compass/crawler-google-places",
// After:
actorId: process.env.APIFY_ACTIVITY_ACTOR || "compass/crawler-google-places",

// restaurant (line 74):
// Before:
actorId: "compass/crawler-google-places",
// After:
actorId: process.env.APIFY_RESTAURANT_ACTOR || "compass/crawler-google-places",
```

- [ ] **Step 2: Update orchestrator.ts**

Change line 119:
```typescript
// Before:
const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
// After:
const modelName = process.env.GEMINI_MODEL || "gemini-2.5-flash";
const model = genAI.getGenerativeModel({ model: modelName });
```

- [ ] **Step 3: Commit**

```bash
git add src/lib/intelligence/tool-registry.ts src/lib/intelligence/orchestrator.ts
git commit -m "refactor: externalize Apify actor IDs and Gemini model to env vars"
```

---

## Chunk 2: UserMenu Redesign

### Task 7: Update CLAUDE.md Theme System

**Files:**
- Modify: `CLAUDE.md` — update theme system section from "1 Theme" to 4 themes

- [ ] **Step 1: Update CLAUDE.md**

In the THEME SYSTEM section, change:
```
THEME SYSTEM (1 Theme): Xark OS ships with hearth (light, default). Single theme.
```
to:
```
THEME SYSTEM (4 Themes): Xark OS ships with 4 themes across 2 axes — style (flat/depth) and mode (light/dark). hearth (flat light, default), hearth_dark (flat dark), vibe (depth light), vibe_dark (depth dark). All colors are CSS variables set by ThemeProvider. No hardcoded hex colors in components.
```

Also update `ink.*` reference if not already present.

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md theme system to reflect 4-theme reality"
```

---

### Task 8: Remove GlobalUserMenu + Relocate Avatar Trigger to Galaxy Header

**Files:**
- Modify: `src/app/layout.tsx` — remove `<GlobalUserMenu />` import and usage
- Delete: `src/components/os/GlobalUserMenu.tsx`
- Modify: `src/app/galaxy/page.tsx` — import `UserMenu`, add avatar trigger to tab header row

- [ ] **Step 1: Remove GlobalUserMenu from layout.tsx**

```typescript
// Remove import:
import { GlobalUserMenu } from "@/components/os/GlobalUserMenu";

// Remove from JSX:
<GlobalUserMenu />
```

The layout.tsx should become:
```typescript
import type { Metadata, Viewport } from "next";
import { Syne, Inter } from "next/font/google";
import "./globals.css";
import { ThemeProvider } from "@/components/os/ThemeProvider";
import { GlobalCaret } from "@/components/os/GlobalCaret";
import { ServiceWorkerRegistration } from "@/components/os/ServiceWorkerRegistration";

// ... fonts, metadata, viewport unchanged ...

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${syne.variable} ${inter.variable}`}>
        <ThemeProvider>
          {children}
          <GlobalCaret />
          <ServiceWorkerRegistration />
        </ThemeProvider>
      </body>
    </html>
  );
}
```

- [ ] **Step 2: Delete GlobalUserMenu.tsx**

```bash
rm src/components/os/GlobalUserMenu.tsx
```

- [ ] **Step 3: Add UserMenu + avatar trigger to Galaxy page header**

In `src/app/galaxy/page.tsx`, add import:
```typescript
import { UserMenu } from "@/components/os/UserMenu";
```

Modify the tab header (lines 111-170) to become a flex container with avatar on the right:

The current header structure:
```tsx
<div className="mx-auto flex gap-6" style={{ maxWidth: layout.maxWidth }}>
  {/* tabs */}
</div>
```

Change to:
```tsx
<div
  className="mx-auto flex items-center"
  style={{ maxWidth: layout.maxWidth }}
>
  <div className="flex gap-6">
    {/* existing tab labels — unchanged */}
  </div>
  <div style={{ marginLeft: "auto" }}>
    <UserMenu userName={userName} userId={userId} />
  </div>
</div>
```

Note: UserMenu will now receive `userName` and `userId` as props instead of reading from searchParams internally. This is set up in Task 9.

- [ ] **Step 4: Commit**

```bash
git add src/app/layout.tsx src/app/galaxy/page.tsx
git rm src/components/os/GlobalUserMenu.tsx
git commit -m "feat: relocate UserMenu into Galaxy page header, delete GlobalUserMenu"
```

---

### Task 9: Rewrite UserMenu.tsx — Full Redesign

**Files:**
- Modify: `src/components/os/UserMenu.tsx` — complete rewrite with 4-view architecture

This is the largest task. The new UserMenu has:
- Props: `userName`, `userId` (no longer reads from searchParams)
- 4 views: `main | profile | notifications | about`
- Main: profile card (avatar + name + phone), theme toggles (flat/vibe + light/dark), menu rows (notifications, invite, about), log out
- Profile: back, avatar, change photo, name input, phone display
- Notifications: back, master toggle, per-space mute list
- About: back, xark os, version, feedback link

- [ ] **Step 1: Rewrite UserMenu.tsx**

Full rewrite of `src/components/os/UserMenu.tsx`. Key changes from current implementation:

**Props interface:**
```typescript
interface UserMenuProps {
  userName: string;
  userId: string;
}

export function UserMenu({ userName, userId }: UserMenuProps) {
```

**View type:**
```typescript
type SettingsView = "main" | "profile" | "notifications" | "about";
```

**Avatar trigger:** 32px avatar inline (no fixed positioning). Rendered at the component's location in the Galaxy header. Click opens sheet.

**Sheet:** Slides down from top (same as current). `colors.void` background. Auto-height, `maxHeight: "80vh"`, `overflowY: "auto"`.

**Data fetching on open — fetch photo_url AND phone:**
```typescript
useEffect(() => {
  if (!userId) return;
  supabase
    .from("users")
    .select("photo_url, phone, preferences")
    .eq("id", userId)
    .single()
    .then(({ data }) => {
      if (data?.photo_url) setPhotoUrl(data.photo_url);
      if (data?.phone) setPhone(data.phone);
      if (data?.preferences) setPreferences(data.preferences);
    });
}, [userId]);
```

**Main view layout:**
```
[48px avatar]  {userName}
               {phone if available} →     ← taps to profile

flat · vibe                               ← style axis toggle
light · dark                              ← mode axis toggle

notifications →
invite a friend
about →

log out
```

**Theme toggles (inline on main):**
- Row 1: `flat · vibe` — style axis. Note: toggle label "vibe" maps to `style: "depth"` internally in theme.ts. `ThemeStyle` is `"flat" | "depth"`.
- Row 2: `light · dark` — mode axis
- Active word: `colors.cyan`, inactive: `ink.tertiary`
- Mapping: flat+light = hearth, flat+dark = hearth_dark, vibe+light = vibe, vibe+dark = vibe_dark
- Uses `useThemeContext()` to get/set theme
- Persistence: `setTheme()` handles localStorage. Theme also synced to Supabase (see Task 13).

**Theme toggle implementation:**
```typescript
// Derive current style/mode from theme
const currentStyle = themes[theme].style; // "flat" | "depth"
const currentMode = themes[theme].mode;   // "light" | "dark"

// Map toggle to theme name
function resolveTheme(style: ThemeStyle, mode: "light" | "dark"): ThemeName {
  if (style === "flat" && mode === "light") return "hearth";
  if (style === "flat" && mode === "dark") return "hearth_dark";
  if (style === "depth" && mode === "light") return "vibe";
  return "vibe_dark";
}

const handleStyleToggle = (style: ThemeStyle) => {
  const newTheme = resolveTheme(style, currentMode);
  setTheme(newTheme);
  syncThemeToDb(newTheme); // Task 13
};

const handleModeToggle = (mode: "light" | "dark") => {
  const newTheme = resolveTheme(currentStyle, mode);
  setTheme(newTheme);
  syncThemeToDb(newTheme); // Task 13
};
```

**Profile card tap → drills to profile view.**

**Notifications → drills to notifications view.**

**About → drills to about view.**

**Invite action (inline, no drill):**
```typescript
const handleInvite = async () => {
  const shareData = { title: "xark", text: "decide together, effortlessly.", url: "https://getxark.com" };
  if (navigator.share) {
    await navigator.share(shareData);
  } else {
    await navigator.clipboard.writeText("https://getxark.com");
    setInviteCopied(true);
    setTimeout(() => setInviteCopied(false), 1500);
  }
};
```

**Profile view:**
- Avatar 48px + "change photo" (uses `storageAdapter.upload()` — already wired from Task 5)
- Name input with save-on-blur and "saved" whisper
- Phone: read-only from `phone` state (fetched on open). Hidden if null.
- Max 2MB photo enforcement. "too large" whisper on exceed.

**Notifications view:**
- Master toggle: `on · off` text toggle
- On first enable: `Notification.requestPermission()` → get FCM token → store in `user_devices`
- On disable: delete FCM token row from `user_devices`
- Per-space mute list (only visible when master is on)
- **"spaces" section label** between master toggle and space list: `text.recency`, `ink.tertiary`
- Fetch spaces from `space_members` joined with `spaces.title`
- **Loading state:** breathing cyan dot (6px, `colors.cyan`, `animation: ambientBreath 4.5s`) + "loading" whisper (`text.hint`, `ink.tertiary`)
- **Empty state:** "no spaces yet" in `text.hint`, `ink.tertiary`
- **Error state:** silently show empty list (no error message — graceful degradation)
- Mute stored in `users.preferences.muted_spaces` JSONB array

**About view:**
```
back                          ← text.recency, ink.tertiary

xark os                       ← text.body, ink.primary
v2.0                          ← text.recency, ink.tertiary

feedback                      ← text.body, ink.secondary → ink.primary on hover
```
- "back" taps back to main (same styling as Profile and Notifications back links)
- "xark os" + "v2.0" (hardcode for now)
- "feedback" opens feedback URL

- [ ] **Step 2: Verify build**

Run: `npx next build`
Expected: Clean build.

- [ ] **Step 3: Commit**

```bash
git add src/components/os/UserMenu.tsx
git commit -m "feat: redesign UserMenu — 4-view architecture, theme toggles, notifications, about"
```

---

### Task 10: Add Firebase Messaging Export

**Files:**
- Modify: `src/lib/firebase.ts` — add `messaging` export for FCM token registration

- [ ] **Step 1: Add messaging export to firebase.ts**

Add at the end of the file, after `storage` export:
```typescript
// FCM push notifications — lazy import to avoid SSR issues.
// Only call getMessagingInstance() on client-side after user enables notifications.
export async function getMessagingInstance() {
  if (!app) return null;
  if (typeof window === "undefined") return null;
  try {
    const { getMessaging, getToken } = await import("firebase/messaging");
    const messaging = getMessaging(app);
    return { messaging, getToken };
  } catch {
    return null;
  }
}
```

This uses lazy import (same null-safe pattern as `auth` and `storage`) to avoid SSR issues since Firebase Messaging requires browser APIs.

- [ ] **Step 2: Commit**

```bash
git add src/lib/firebase.ts
git commit -m "feat: add Firebase messaging export for FCM token registration"
```

---

### Task 11: Wire FCM Token Registration in UserMenu Notifications View

**Files:**
- Modify: `src/components/os/UserMenu.tsx` — wire the notification enable/disable flow

- [ ] **Step 1: Add FCM wiring to notifications view**

In the notifications view of UserMenu.tsx, the master toggle enable flow:

```typescript
const handleNotificationEnable = async () => {
  const permission = await Notification.requestPermission();
  if (permission !== "granted") {
    setNotifWhisper("blocked by browser");
    setTimeout(() => setNotifWhisper(null), 1500);
    return;
  }

  const vapidKey = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY;
  if (!vapidKey) return;

  const instance = await getMessagingInstance();
  if (!instance) return;

  const { messaging, getToken: getTokenFn } = instance;
  const token = await getTokenFn(messaging, { vapidKey });

  await supabase.from("user_devices").upsert(
    { user_id: userId, fcm_token: token, platform: "web" },
    { onConflict: "user_id,fcm_token" }
  );

  setNotificationsEnabled(true);
};
```

Disable flow:
```typescript
const handleNotificationDisable = async () => {
  await supabase.from("user_devices").delete().eq("user_id", userId);
  setNotificationsEnabled(false);
};
```

Per-space mute toggle — **always fetch fresh preferences before writing** to avoid overwriting sibling keys (e.g., theme):
```typescript
const toggleMuteSpace = async (spaceId: string, currentlyMuted: boolean) => {
  const newMuted = currentlyMuted
    ? mutedSpaces.filter((id) => id !== spaceId)
    : [...mutedSpaces, spaceId];
  setMutedSpaces(newMuted);

  // Fetch fresh preferences to avoid overwriting theme or other keys
  const { data: fresh } = await supabase
    .from("users")
    .select("preferences")
    .eq("id", userId)
    .single();
  const currentPrefs = fresh?.preferences ?? {};

  await supabase
    .from("users")
    .update({ preferences: { ...currentPrefs, muted_spaces: newMuted } })
    .eq("id", userId);
};
```

- [ ] **Step 2: Commit**

```bash
git add src/components/os/UserMenu.tsx
git commit -m "feat: wire FCM token registration and per-space mute in notifications view"
```

---

### Task 12: Update `/api/notify` for Muted Spaces Check

**Files:**
- Modify: `src/app/api/notify/route.ts` — check `preferences.muted_spaces` before sending push

- [ ] **Step 1: Update notify route**

Replace the existing RPC-based approach with direct queries that include muted_spaces filtering. The old `get_push_tokens_for_space` RPC only returns `fcm_token` (no `user_id`), so we use direct queries instead.

```typescript
export async function POST(req: NextRequest) {
  const { event, spaceId, title, body, excludeUserId } = await req.json();

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "not configured" }, { status: 500 });
  }

  // 1. Get all member user IDs for this space
  const { data: members } = await supabaseAdmin
    .from("space_members")
    .select("user_id")
    .eq("space_id", spaceId);

  const memberUserIds = (members ?? [])
    .map((m: { user_id: string }) => m.user_id)
    .filter((id: string) => id !== excludeUserId);

  if (memberUserIds.length === 0) {
    return NextResponse.json({ sent: 0 });
  }

  // 2. Fetch preferences to find who muted this space
  const { data: userPrefs } = await supabaseAdmin
    .from("users")
    .select("id, preferences")
    .in("id", memberUserIds);

  const mutedUserIds = new Set<string>();
  for (const u of userPrefs ?? []) {
    const muted = u.preferences?.muted_spaces ?? [];
    if (Array.isArray(muted) && muted.includes(spaceId)) {
      mutedUserIds.add(u.id);
    }
  }

  // 3. Get devices for non-muted members
  const eligibleUserIds = memberUserIds.filter((id: string) => !mutedUserIds.has(id));
  if (eligibleUserIds.length === 0) {
    return NextResponse.json({ sent: 0 });
  }

  const { data: deviceRows } = await supabaseAdmin
    .from("user_devices")
    .select("fcm_token")
    .in("user_id", eligibleUserIds);

  const tokens = (deviceRows ?? []).map((d: { fcm_token: string }) => d.fcm_token);

  if (tokens.length === 0) {
    return NextResponse.json({ sent: 0 });
  }

  await sendPush(tokens, title, body, { spaceId, event });
  return NextResponse.json({ sent: tokens.length });
}
```

- [ ] **Step 2: Commit**

```bash
git add src/app/api/notify/route.ts
git commit -m "feat: check muted_spaces before sending push notifications"
```

---

### Task 13: Theme Persistence to Supabase (Read + Write)

**Files:**
- Modify: `src/components/os/ThemeProvider.tsx` — add Supabase fallback read on mount (when localStorage empty)
- Modify: `src/components/os/UserMenu.tsx` — write theme to `users.preferences.theme` on toggle

This task has TWO parts:

**Part A — Read from Supabase when localStorage is empty (cross-device sync):**

ThemeProvider doesn't have the userId, but it can check if localStorage has a theme. If not, it should provide a way for the UserMenu to push a Supabase-loaded theme down.

Simplest approach: ThemeProvider stays as-is for localStorage reads. UserMenu fetches `preferences.theme` on mount (already done in the `useEffect` from Task 9 that fetches `photo_url, phone, preferences`). If localStorage is empty and Supabase has a theme, UserMenu calls `setTheme()` with the DB value:

```typescript
// In UserMenu's data-fetching useEffect (Task 9):
useEffect(() => {
  if (!userId) return;
  supabase
    .from("users")
    .select("photo_url, phone, preferences")
    .eq("id", userId)
    .single()
    .then(({ data }) => {
      if (data?.photo_url) setPhotoUrl(data.photo_url);
      if (data?.phone) setPhone(data.phone);
      if (data?.preferences) setPreferences(data.preferences);

      // Cross-device theme sync: if localStorage is empty, use DB value
      const localTheme = localStorage.getItem("xark-theme");
      if (!localTheme && data?.preferences?.theme) {
        setTheme(data.preferences.theme as ThemeName);
      }
    });
}, [userId]);
```

**Part B — Write to Supabase on theme toggle (fresh-fetch-before-write):**

ThemeProvider doesn't have the userId, so the DB write lives in UserMenu. Add a `syncThemeToDb` helper:

```typescript
// In UserMenu.tsx:
const syncThemeToDb = async (newTheme: ThemeName) => {
  // Fetch fresh preferences to avoid overwriting muted_spaces or other keys
  const { data: fresh } = await supabase
    .from("users")
    .select("preferences")
    .eq("id", userId)
    .single();
  const currentPrefs = fresh?.preferences ?? {};

  supabase.from("users").update({
    preferences: { ...currentPrefs, theme: newTheme }
  }).eq("id", userId).then(() => {});
};
```

Called after `setTheme()` in the theme toggle handlers (see Task 9).

- [ ] **Step 1: Add Supabase theme read fallback in UserMenu data fetch**

In the UserMenu `useEffect` that fetches user data on open, add the `!localTheme` check as shown above.

- [ ] **Step 2: Add `syncThemeToDb` helper in UserMenu**

Add the fresh-fetch-before-write helper as shown above. Wire it into the theme toggle handlers from Task 9.

- [ ] **Step 3: Commit**

This keeps ThemeProvider simple (localStorage only) and the DB write in UserMenu where we have the userId.

- [ ] **Step 2: Commit**

```bash
git add src/components/os/UserMenu.tsx
git commit -m "feat: sync theme to Supabase — read fallback on mount + fresh-fetch-before-write"
```

---

### Task 14: Verify Build + Integration Test

- [ ] **Step 1: Build**

```bash
npx next build
```

Expected: Clean build, 0 type errors.

- [ ] **Step 2: Manual smoke test**

1. Run locally: `npx next dev`
2. Navigate to Galaxy page
3. Verify avatar trigger appears in header row (aligned with tabs)
4. Click avatar → UserMenu slides down
5. Verify profile card shows name (and phone if available)
6. Tap profile card → drill into profile edit
7. Change photo → verify upload works
8. Back → main
9. Tap `flat`/`vibe` and `light`/`dark` toggles → theme changes instantly
10. Tap notifications → drill into notifications view
11. Enable push → browser permission prompt
12. Tap about → drill into about view
13. Tap "invite a friend" → share dialog or clipboard copy
14. Log out → redirect to login

- [ ] **Step 3: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: address integration issues from smoke test"
```

---

## File Summary

### Files Created
| File | Purpose |
|------|---------|
| `src/lib/user-id.ts` | User ID utilities: `makeUserId()`, `extractDisplayName()`, `getUserIdType()` |
| `src/lib/storage.ts` | Storage adapter interface + Firebase implementation |

### Files Modified
| File | Changes |
|------|---------|
| `src/hooks/useAuth.ts` | `makeUserId()` |
| `src/app/galaxy/page.tsx` | `makeUserId()` + UserMenu integration in header |
| `src/app/login/page.tsx` | `makeUserId()` + `storageAdapter.upload()` |
| `src/app/api/join/route.ts` | `makeUserId()` |
| `src/app/api/phone-auth/route.ts` | `makeUserId()` |
| `src/components/os/UserMenu.tsx` | Full rewrite: 4-view architecture, theme toggles, notifications, about, invite |
| `src/lib/seed.ts` | `makeUserId()` |
| `src/lib/ai-grounding.ts` | `extractDisplayName()` |
| `src/lib/ledger.ts` | `extractDisplayName()` (replaces local function) |
| `src/lib/awareness.ts` | `extractDisplayName()` |
| `src/components/os/ClaimSheet.tsx` | `extractDisplayName()` |
| `src/components/os/PurchaseSheet.tsx` | `extractDisplayName()` |
| `src/lib/media.ts` | `storageAdapter.upload()` |
| `src/lib/spaces.ts` | `storageAdapter.upload()` |
| `src/lib/intelligence/tool-registry.ts` | Env var Apify actor IDs |
| `src/lib/intelligence/orchestrator.ts` | Env var Gemini model |
| `src/lib/firebase.ts` | `getMessagingInstance()` export |
| `src/app/api/notify/route.ts` | Muted spaces check |
| `src/app/layout.tsx` | Remove `<GlobalUserMenu />` |
| `CLAUDE.md` | Update theme system docs |

### Files Deleted
| File | Reason |
|------|--------|
| `src/components/os/GlobalUserMenu.tsx` | UserMenu now lives directly in Galaxy page |
