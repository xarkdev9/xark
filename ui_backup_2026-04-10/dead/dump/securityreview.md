 Security / Privacy:

  1. External image URLs — metadata.image_url from Apify actors renders as <img src={...}>, exposing user IP to the image host. This is pre-existing (current
  code already does this). Mitigation for later: proxy images through a Next.js image route or use next/image with a configured remote pattern. Not blocking
  for this design, but worth noting.
  2. No XSS vector — React auto-escapes all text content. No dangerouslySetInnerHTML anywhere. Item titles, categories, prices — all safe.
  3. RLS intact — All queries filter by space_id. Supabase RLS policies enforce auth_user_space_ids(). Users only see items in spaces they belong to. The
  Realtime channel also filters on space_id.
  4. Input zone — Posts to /api/xark (same endpoint as Discuss). Server-side @xark prefix check already exists. No new attack surface.

