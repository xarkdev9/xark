// XARK OS v2.0 — SEED PROTOCOL
// Populates Supabase Postgres with test users, spaces, members, items, messages.
// Uses service_role key to bypass RLS.
// Run via: npx tsx src/lib/seed.ts

import { createClient } from "@supabase/supabase-js";
import * as dotenv from "dotenv";
import { resolve } from "path";

// Load .env.local from project root
dotenv.config({ path: resolve(process.cwd(), ".env.local") });

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !serviceKey) {
  console.error(
    "Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY"
  );
  console.error("Set them in .env.local before running seed.");
  process.exit(1);
}

const supabase = createClient(url, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// ── Generate bcrypt hash via pgcrypto in Supabase ──
async function hashPassword(password: string): Promise<string> {
  const { data, error } = await supabase.rpc("gen_hash", {
    p_password: password,
  });
  if (error) throw new Error(`Failed to hash password: ${error.message}`);
  return data as string;
}

export async function seedXarkGalaxy() {
  console.log("seeding xark galaxy...\n");

  // ══════════════════════════════════
  // 0. Generate password hashes via pgcrypto
  // ══════════════════════════════════
  const userDefs = [
    { name: "ram", password: "myna" },
    { name: "myna", password: "ram" },
    { name: "anjan", password: "anjan9" },
    { name: "shiva", password: "shiva9" },
    { name: "venky", password: "venky9" },
  ];

  console.log("  generating password hashes...");
  const hashes: Record<string, string> = {};
  for (const u of userDefs) {
    hashes[u.name] = await hashPassword(u.password);
  }
  console.log("  5 password hashes generated");

  // ══════════════════════════════════
  // 1. TEST USERS
  // ══════════════════════════════════
  const users = userDefs.map((u) => ({
    id: `name_${u.name}`,
    display_name: u.name,
    password_hash: hashes[u.name],
  }));

  const { error: usersError } = await supabase
    .from("users")
    .upsert(users, { onConflict: "id" });

  if (usersError) {
    console.error("failed to seed users:", usersError.message);
    return;
  }
  console.log("  5 test users seeded");

  // ══════════════════════════════════
  // 2. SPACES
  // ══════════════════════════════════
  const spaceDefs = [
    {
      id: "space_san-diego-trip",
      title: "san diego trip",
      owner_id: "name_ram",
      atmosphere: "cyan_horizon",
    },
    {
      id: "space_ananya",
      title: "ananya",
      owner_id: "name_ram",
      atmosphere: "sanctuary",
      is_public: false,
    },
    {
      id: "space_tokyo-neon-nights",
      title: "tokyo neon nights",
      owner_id: "name_myna",
      atmosphere: "amber_glow",
    },
    {
      id: "space_summer-2026",
      title: "summer 2026",
      owner_id: "name_ram",
      atmosphere: "gold_warmth",
    },
  ];

  for (const space of spaceDefs) {
    const { error } = await supabase
      .from("spaces")
      .upsert(space, { onConflict: "id" });
    if (error) console.error(`  ${space.title}:`, error.message);
    else console.log(`  space: ${space.id} — ${space.title}`);
  }

  // ══════════════════════════════════
  // 3. SPACE MEMBERS
  // trg_auto_add_space_owner fires on INSERT but not on upsert conflict.
  // Add all members explicitly.
  // ══════════════════════════════════
  const members = [
    // San Diego: all 5
    { space_id: "space_san-diego-trip", user_id: "name_ram", role: "owner" },
    { space_id: "space_san-diego-trip", user_id: "name_myna", role: "member" },
    {
      space_id: "space_san-diego-trip",
      user_id: "name_anjan",
      role: "member",
    },
    {
      space_id: "space_san-diego-trip",
      user_id: "name_shiva",
      role: "member",
    },
    {
      space_id: "space_san-diego-trip",
      user_id: "name_venky",
      role: "member",
    },
    // Ananya sanctuary: 2
    { space_id: "space_ananya", user_id: "name_ram", role: "owner" },
    { space_id: "space_ananya", user_id: "name_myna", role: "member" },
    // Tokyo: 3
    {
      space_id: "space_tokyo-neon-nights",
      user_id: "name_myna",
      role: "owner",
    },
    {
      space_id: "space_tokyo-neon-nights",
      user_id: "name_ram",
      role: "member",
    },
    {
      space_id: "space_tokyo-neon-nights",
      user_id: "name_anjan",
      role: "member",
    },
    // Summer: 3
    { space_id: "space_summer-2026", user_id: "name_ram", role: "owner" },
    { space_id: "space_summer-2026", user_id: "name_myna", role: "member" },
    { space_id: "space_summer-2026", user_id: "name_venky", role: "member" },
  ];

  const { error: membersError } = await supabase
    .from("space_members")
    .upsert(members, { onConflict: "space_id,user_id" });

  if (membersError) console.error("  members:", membersError.message);
  else console.log("  13 space memberships seeded");

  // ══════════════════════════════════
  // 4. DECISION ITEMS
  // ══════════════════════════════════
  const items = [
    {
      id: "item_hotel-del",
      space_id: "space_san-diego-trip",
      title: "hotel del coronado",
      category: "Hotel",
      description: "iconic beachfront resort on coronado island",
      state: "locked",
      proposed_by: "name_myna",
      agreement_score: 0.92,
      weighted_score: 22,
      is_locked: true,
      locked_at: "2026-02-28T14:30:00Z",
      commitment_proof: {
        type: "confirmation_number",
        value: "HDC-29441",
        submittedBy: "name_ram",
        submittedAt: "2026-02-28T14:30:00Z",
      },
      ownership: {
        ownerId: "name_ram",
        assignedAt: "2026-02-28T14:30:00Z",
        reason: "booker",
      },
      version: 1,
      metadata: { price: "$450/nt" },
    },
    {
      id: "item_surf-lessons",
      space_id: "space_san-diego-trip",
      title: "surf lessons",
      category: "Activity",
      description:
        "morning surf session at la jolla shores with local instructor",
      state: "proposed",
      proposed_by: "name_myna",
      agreement_score: 0.45,
      weighted_score: 7,
      is_locked: false,
      version: 0,
      metadata: { price: "$95/person" },
    },
    {
      id: "item_balboa-park",
      space_id: "space_san-diego-trip",
      title: "balboa park tour",
      category: "Activity",
      description:
        "guided walking tour through the cultural heart of san diego",
      state: "proposed",
      proposed_by: "name_anjan",
      agreement_score: 0.45,
      weighted_score: 5,
      is_locked: false,
      version: 0,
      metadata: { price: "Free" },
    },
    {
      id: "item_gaslamp-dinner",
      space_id: "space_san-diego-trip",
      title: "gaslamp quarter dinner",
      category: "Dining",
      description: "group dinner at a rooftop restaurant downtown",
      state: "locked",
      proposed_by: "name_shiva",
      agreement_score: 0.92,
      weighted_score: 22,
      is_locked: true,
      locked_at: "2026-03-05T19:00:00Z",
      commitment_proof: {
        type: "confirmation_number",
        value: "RSV-77201",
        submittedBy: "name_myna",
        submittedAt: "2026-03-05T19:00:00Z",
      },
      ownership: {
        ownerId: "name_myna",
        assignedAt: "2026-03-05T19:00:00Z",
        reason: "booker",
      },
      version: 1,
      metadata: { price: "$65/person" },
    },
    {
      id: "item_shibuya",
      space_id: "space_tokyo-neon-nights",
      title: "shibuya crossing at midnight",
      category: "Experience",
      description: "witness the world's busiest intersection under neon",
      state: "proposed",
      proposed_by: "name_anjan",
      agreement_score: 0.15,
      weighted_score: 2,
      is_locked: false,
      version: 0,
    },
    {
      id: "item_teamlab",
      space_id: "space_tokyo-neon-nights",
      title: "teamlab borderless",
      category: "Activity",
      description: "immersive digital art museum in odaiba",
      state: "proposed",
      proposed_by: "name_venky",
      agreement_score: 0.72,
      weighted_score: 11,
      is_locked: false,
      version: 0,
    },
  ];

  const { error: itemsError } = await supabase
    .from("decision_items")
    .upsert(items, { onConflict: "id" });

  if (itemsError) console.error("  items:", itemsError.message);
  else console.log("  6 decision items seeded");

  // ══════════════════════════════════
  // 5. MESSAGES
  // sender_name is set by trigger for user messages.
  // xark messages have no sender_name.
  // ══════════════════════════════════
  const now = Date.now();
  const minute = 60_000;

  const msgs = [
    // San Diego group chat (10 messages)
    {
      id: "msg_sd_01",
      space_id: "space_san-diego-trip",
      role: "user",
      content: "alright who's looking into hotels?",
      user_id: "name_ram",
      created_at: new Date(now - 10 * minute).toISOString(),
    },
    {
      id: "msg_sd_02",
      space_id: "space_san-diego-trip",
      role: "user",
      content: "i found a few near coronado beach",
      user_id: "name_myna",
      created_at: new Date(now - 9 * minute).toISOString(),
    },
    {
      id: "msg_sd_03",
      space_id: "space_san-diego-trip",
      role: "xark",
      content:
        "hotel del coronado fits the group's vibe — beachfront, historic, within budget range. coronado island marriott is bayfront, lower price.",
      user_id: null,
      created_at: new Date(now - 8 * minute).toISOString(),
    },
    {
      id: "msg_sd_04",
      space_id: "space_san-diego-trip",
      role: "user",
      content: "what about the price though?",
      user_id: "name_ram",
      created_at: new Date(now - 7 * minute).toISOString(),
    },
    {
      id: "msg_sd_05",
      space_id: "space_san-diego-trip",
      role: "user",
      content: "450 a night but the beach access is worth it",
      user_id: "name_myna",
      created_at: new Date(now - 6 * minute).toISOString(),
    },
    {
      id: "msg_sd_06",
      space_id: "space_san-diego-trip",
      role: "user",
      content: "i'm in for hotel del",
      user_id: "name_ram",
      created_at: new Date(now - 5 * minute).toISOString(),
    },
    {
      id: "msg_sd_07",
      space_id: "space_san-diego-trip",
      role: "user",
      content: "same. let's lock it",
      user_id: "name_myna",
      created_at: new Date(now - 4 * minute).toISOString(),
    },
    {
      id: "msg_sd_08",
      space_id: "space_san-diego-trip",
      role: "xark",
      content:
        "consensus reached on hotel del coronado. locked with confirmation HDC-29441.",
      user_id: null,
      created_at: new Date(now - 3 * minute).toISOString(),
    },
    {
      id: "msg_sd_09",
      space_id: "space_san-diego-trip",
      role: "user",
      content: "locked. what activities are we doing?",
      user_id: "name_ram",
      created_at: new Date(now - 2 * minute).toISOString(),
    },
    {
      id: "msg_sd_10",
      space_id: "space_san-diego-trip",
      role: "user",
      content: "i proposed surf lessons at la jolla — check it out",
      user_id: "name_myna",
      created_at: new Date(now - 1 * minute).toISOString(),
    },
    // Ananya sanctuary (5 messages)
    {
      id: "msg_an_01",
      space_id: "space_ananya",
      role: "user",
      content: "hey, are you excited about the trip?",
      user_id: "name_myna",
      created_at: new Date(now - 30 * minute).toISOString(),
    },
    {
      id: "msg_an_02",
      space_id: "space_ananya",
      role: "user",
      content: "so excited. finally getting the whole group together",
      user_id: "name_ram",
      created_at: new Date(now - 28 * minute).toISOString(),
    },
    {
      id: "msg_an_03",
      space_id: "space_ananya",
      role: "user",
      content: "i've been looking at activities near la jolla",
      user_id: "name_myna",
      created_at: new Date(now - 20 * minute).toISOString(),
    },
    {
      id: "msg_an_04",
      space_id: "space_ananya",
      role: "user",
      content: "the kayaking looks amazing, those sea caves",
      user_id: "name_ram",
      created_at: new Date(now - 15 * minute).toISOString(),
    },
    {
      id: "msg_an_05",
      space_id: "space_ananya",
      role: "user",
      content: "did you see the surf lesson proposal?",
      user_id: "name_myna",
      created_at: new Date(now - 5 * minute).toISOString(),
    },
  ];

  const { error: msgsError } = await supabase
    .from("messages")
    .upsert(msgs, { onConflict: "id" });

  if (msgsError) console.error("  messages:", msgsError.message);
  else console.log("  15 messages seeded");

  console.log("\nseed complete.");
}

// Allow direct execution: npx tsx src/lib/seed.ts
seedXarkGalaxy().catch(console.error);
