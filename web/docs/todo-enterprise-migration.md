# Enterprise Migration — TODO

> Pre-migration checklist for moving Xark OS to an enterprise Vercel + Supabase + Firebase account without downtime.

## Pre-Migration (do before migration day)

- [ ] **Write migration 014** — fix `auth.uid()::text` → `auth.jwt()->>'sub'` in SQL functions: `lock_item`, `transfer_ownership`, `invite_member`, `fn_force_proposed_by`, `join_via_invite`. These are existing bugs that corrupt ownership data for text-format user IDs. Files: `supabase/migrations/002_functions_triggers.sql`, `008_join_via_invite.sql`.
- [ ] **Add FCM token cleanup** — in `src/lib/notifications.ts`, when `sendEachForMulticast` returns `messaging/registration-token-not-registered` errors, delete those tokens from `user_devices` table. Currently failed tokens are silently ignored.
- [ ] **Verify .env.example** — ensure ALL required env vars are documented with descriptions for the new team.
- [ ] **Write Firebase Storage copy script** — script that copies all objects from old bucket to new bucket preserving path structure (`profiles/{userId}/avatar`, `heroes/{spaceId}/hero.jpg`, `spaces/{spaceId}/media/*`).
- [ ] **Write DB URL update script** — SQL script that updates `users.photo_url`, `media.storage_url`, `media.thumbnail_url`, and `spaces.metadata.hero_url` to point to the new Firebase Storage bucket hostname.

## Migration Day

- [ ] Create new Supabase project (Pro/Enterprise plan)
- [ ] Run `supabase db push` against new project (all 14 migrations)
- [ ] Set `app.jwt_secret` on new Supabase project if using SQL-level JWT functions
- [ ] Create new Firebase project, enable Phone Auth + Storage + FCM
- [ ] Run Firebase Storage copy script (old bucket → new bucket)
- [ ] Run DB URL update script on new Supabase (photo_url, storage_url, hero_url)
- [ ] Export data from old Supabase → import to new (pg_dump/pg_restore)
- [ ] Update ALL env vars on Vercel (new Supabase URL/keys, new Firebase config, new JWT secret)
- [ ] Deploy new build (triggers `NEXT_PUBLIC_` rebuild)
- [ ] Verify: all routes 200, login works, spaces load, images render
- [ ] Keep old Firebase project alive in read-only mode

## Post-Migration

- [ ] Day +1: Monitor FCM token refresh rate (users visiting = new tokens)
- [ ] Day +7: Check for stale FCM tokens, run cleanup
- [ ] Day +7: Retire old Firebase project (if all sessions expired)
- [ ] Day +30: Retire old Supabase project
- [ ] Verify no broken image links remain in production

## What's Already Safe (no action needed)

- Supabase schema: zero project-specific refs, fully portable
- Realtime channels: use spaceId, no project coupling
- Service Worker: Firebase config injected via postMessage
- manifest.json: all relative URLs
- User IDs: `phone_XXXXXXXXXX` format, decoupled from Firebase UID
- Unsplash/Apify/Gemini: pure API key swap
- Vercel: just re-link with `vercel link`

## Risk Summary

| Risk | Severity | Duration | Affected Users |
|------|----------|----------|---------------|
| JWT sessions invalidated | High | Hours | All authenticated users (re-login fixes) |
| Photos broken if old bucket deleted early | High | Permanent if not copied | All users with avatars/photos |
| FCM push stops | Medium | Days (auto-recovers) | All users with push enabled |
| localStorage lost on domain change | Low | One-time | All users (theme resets) |
