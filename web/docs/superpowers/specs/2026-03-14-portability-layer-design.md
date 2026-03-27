# Portability Layer — Design Spec

**Goal:** Decouple Xark OS from specific Firebase/Supabase/API accounts so the app can migrate to any enterprise account or alternative provider without code changes or downtime.

**Architecture:** Three abstraction layers — storage adapter (any blob storage), user ID utilities (format-agnostic identity), and externalized config (API provider settings via env vars). DB abstraction is deferred (Supabase is too deeply integrated for a single pass).

---

## 1. Storage Adapter (`src/lib/storage.ts`)

Abstract Firebase Storage behind a provider-agnostic interface. New uploads go through the adapter. Switching providers requires only changing the adapter implementation + running a data migration script for existing URLs.

### Interface

```typescript
export interface StorageAdapter {
  upload(path: string, file: File | Blob, contentType?: string): Promise<string>;  // returns public URL
  delete(path: string): Promise<void>;
}
```

### Implementation

```typescript
// Firebase implementation (default)
class FirebaseStorageAdapter implements StorageAdapter {
  async upload(path, file, contentType) {
    const storageRef = ref(storage, path);
    await uploadBytes(storageRef, file, contentType ? { contentType } : undefined);
    return getDownloadURL(storageRef);
  }
  async delete(path) {
    await deleteObject(ref(storage, path));
  }
}

// Export singleton
export const storageAdapter: StorageAdapter = new FirebaseStorageAdapter();
```

### Migration Path
- New provider (S3, R2, etc.): implement `StorageAdapter`, swap the export
- Existing URLs in DB: run migration script to re-upload from old provider → new provider → update DB URLs
- No render-side changes needed — URLs are just URLs, `<img src={url}>` works for any CDN

### Callers to Update (4 files)
- `src/lib/media.ts:40-45` — `uploadBytes` + `getDownloadURL` → `storageAdapter.upload()`
- `src/lib/spaces.ts:134-136` — hero image upload → `storageAdapter.upload()`
- `src/components/os/UserMenu.tsx:108-111` — avatar upload → `storageAdapter.upload()`
- `src/app/login/page.tsx:223-225` — login avatar upload → `storageAdapter.upload()`

### Storage Paths (preserved as-is)
```
profiles/{userId}/avatar
heroes/{spaceId}/hero.jpg
spaces/{spaceId}/media/{mediaId}
```
Paths are convention-based, not provider-specific. Same paths work on any storage backend.

## 2. User ID Utilities (`src/lib/user-id.ts`)

Replace all hardcoded `name_`/`phone_` prefix construction and stripping with utility functions.

### Interface

```typescript
export type UserIdType = "name" | "phone";

export function makeUserId(type: UserIdType, value: string): string;
export function extractDisplayName(userId: string): string;
export function getUserIdType(userId: string): UserIdType | "unknown";
```

### Implementation

```typescript
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
  // Also handle legacy "user_" prefix from ai-grounding.ts
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

### Callers to Update (14 instances across 10 files)

**Construction (9 instances):**
- `src/hooks/useAuth.ts:126` — `name_${name}` → `makeUserId("name", name)`
- `src/app/galaxy/page.tsx:40` — `name_${userName}` → `makeUserId("name", userName)`
- `src/app/login/page.tsx:222` — `name_${...}` → `makeUserId("name", ...)`
- `src/app/api/join/route.ts:40` — `name_${safeName}` → `makeUserId("name", safeName)`
- `src/app/api/phone-auth/route.ts:94` — `phone_${phoneDigits}` → `makeUserId("phone", phoneDigits)`
- `src/components/os/UserMenu.tsx:42,90,107` — `name_${...}` → `makeUserId("name", ...)`
- `src/lib/seed.ts:62` — `name_${u.name}` → `makeUserId("name", u.name)`

**Stripping (5 instances):**
- `src/lib/ai-grounding.ts:169` — `.replace(...)` → `extractDisplayName(ownerId)`
- `src/lib/ledger.ts:50` — `.replace(...)` → `extractDisplayName(userId)`
- `src/lib/awareness.ts:276` — `.replace(...)` → `extractDisplayName(member.user_id)`
- `src/components/os/ClaimSheet.tsx:49` — `.replace(...)` → `extractDisplayName(userId)`
- `src/components/os/PurchaseSheet.tsx:80` — `.replace(...)` → `extractDisplayName(userId)`

## 3. Config Externalization

### Apify Actor IDs → Env Vars

**File:** `src/lib/intelligence/tool-registry.ts`

| Current Hardcoded | New Env Var | Default |
|-------------------|-------------|---------|
| `voyager/booking-scraper` | `APIFY_HOTEL_ACTOR` | `voyager/booking-scraper` |
| `johnvc/Google-Flights-Data-Scraper-Flight-and-Price-Search` | `APIFY_FLIGHT_ACTOR` | (current value) |
| `compass/crawler-google-places` | `APIFY_ACTIVITY_ACTOR` | `compass/crawler-google-places` |
| `compass/crawler-google-places` | `APIFY_RESTAURANT_ACTOR` | `compass/crawler-google-places` |

Env var with fallback to current default, so no breaking change.

### Gemini Model → Env Var

**File:** `src/lib/intelligence/orchestrator.ts:119`

```typescript
// Before:
const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

// After:
const modelName = process.env.GEMINI_MODEL || "gemini-2.5-flash";
const model = genAI.getGenerativeModel({ model: modelName });
```

## 4. What's NOT Abstracted (and why)

### Database (Supabase)
Supabase client is used directly in 20+ files with Supabase-specific features (RLS, Realtime, `.from().select().eq()` query builder). Full DB abstraction (repository pattern) would require a massive rewrite that doesn't serve the immediate goal. The Supabase coupling is managed through:
- Env-var-driven connection (trivial to point at new Supabase project)
- Portable migrations (no project-specific SQL)
- Standard SQL in all RPCs

### Auth (Firebase Auth)
Firebase Auth is deeply integrated in login flow, phone OTP, and token management. Abstracting auth would require:
- Auth provider interface
- Multiple OTP implementations
- Token format changes
This is a v3 concern. For now, switching Firebase projects is an env var change.

## 5. Files Created
- `src/lib/storage.ts` — storage adapter interface + Firebase implementation
- `src/lib/user-id.ts` — user ID utility functions

## 6. Files Modified
- `src/lib/media.ts` — use `storageAdapter.upload()`
- `src/lib/spaces.ts` — use `storageAdapter.upload()`
- `src/components/os/UserMenu.tsx` — use `storageAdapter.upload()` + `makeUserId()`
- `src/app/login/page.tsx` — use `storageAdapter.upload()` + `makeUserId()`
- `src/hooks/useAuth.ts` — use `makeUserId()`
- `src/app/galaxy/page.tsx` — use `makeUserId()`
- `src/app/api/join/route.ts` — use `makeUserId()`
- `src/app/api/phone-auth/route.ts` — use `makeUserId()`
- `src/lib/ai-grounding.ts` — use `extractDisplayName()`
- `src/lib/ledger.ts` — use `extractDisplayName()`
- `src/lib/awareness.ts` — use `extractDisplayName()`
- `src/components/os/ClaimSheet.tsx` — use `extractDisplayName()`
- `src/components/os/PurchaseSheet.tsx` — use `extractDisplayName()`
- `src/lib/seed.ts` — use `makeUserId()`
- `src/lib/intelligence/tool-registry.ts` — env var actor IDs
- `src/lib/intelligence/orchestrator.ts` — env var model name
