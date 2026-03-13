// XARK OS v2.0 — SEED PROTOCOL
// Populates Supabase Postgres with high-signal data for the Galaxy View.
// This script bypasses the UI to inject reality into the database.
// Run via: npx tsx src/lib/seed.ts

import { supabase } from "./supabase";

export async function seedXarkGalaxy() {
  console.log("seeding xark galaxy...\n");

  // ═══════════════════════════════════════════
  // 1. SAN DIEGO TRIP — group coordination space
  // ═══════════════════════════════════════════
  const { data: sanDiego, error: sdError } = await supabase
    .from("spaces")
    .insert({
      title: "san diego trip",
      owner_id: "user_ram",
      atmosphere: "cyan_horizon",
      agreement_score: 0.65,
    })
    .select()
    .single();

  if (sdError) {
    console.error("failed to create san diego space:", sdError.message);
    return;
  }

  console.log(`  space: ${sanDiego.id} — san diego trip`);

  // ── Decision items for San Diego ──
  const { error: itemsError } = await supabase
    .from("decision_items")
    .insert([
      {
        space_id: sanDiego.id,
        title: "hotel del coronado",
        category: "Hotel",
        description: "iconic beachfront resort on coronado island",
        agreement_score: 0.92,
        weighted_score: 22,
        state: "Locked",
        is_locked: true,
        locked_at: new Date("2026-02-28T14:30:00Z").toISOString(),
        commitment_proof: {
          type: "confirmation_number",
          value: "HDC-29441",
          submittedBy: "user_ram",
          submittedAt: new Date("2026-02-28T14:30:00Z").toISOString(),
        },
        ownership: {
          ownerId: "user_ram",
          assignedAt: new Date("2026-02-28T14:30:00Z").toISOString(),
          reason: "booker",
        },
        proposed_by: "name_ananya",
        version: 1,
        metadata: { price: "$450/nt" },
      },
      {
        space_id: sanDiego.id,
        title: "surf lessons",
        category: "Activity",
        description: "morning surf session at la jolla shores with local instructor",
        agreement_score: 0.45,
        weighted_score: 7,
        state: "Proposed",
        is_locked: false,
        proposed_by: "name_ananya",
        version: 0,
        metadata: { price: "$95/person" },
      },
      {
        space_id: sanDiego.id,
        title: "balboa park tour",
        category: "Activity",
        description: "guided walking tour through the cultural heart of san diego",
        agreement_score: 0.45,
        weighted_score: 5,
        state: "Proposed",
        is_locked: false,
        proposed_by: "name_maya",
        version: 0,
        metadata: { price: "Free" },
      },
      {
        space_id: sanDiego.id,
        title: "gaslamp quarter dinner",
        category: "Dining",
        description: "group dinner at a rooftop restaurant downtown",
        agreement_score: 0.92,
        weighted_score: 22,
        state: "Locked",
        is_locked: true,
        locked_at: new Date("2026-03-05T19:00:00Z").toISOString(),
        commitment_proof: {
          type: "confirmation_number",
          value: "RSV-77201",
          submittedBy: "user_ananya",
          submittedAt: new Date("2026-03-05T19:00:00Z").toISOString(),
        },
        ownership: {
          ownerId: "user_ananya",
          assignedAt: new Date("2026-03-05T19:00:00Z").toISOString(),
          reason: "booker",
        },
        proposed_by: "name_jake",
        version: 1,
        metadata: { price: "$65/person" },
      },
    ]);

  if (itemsError) {
    console.error("  failed to seed items:", itemsError.message);
  } else {
    console.log("  4 decision items seeded");
  }

  // ── 10 Group Messages — tests Foveal Opacity at scale ──
  const now = Date.now();
  const minute = 60_000;
  await supabase.from("messages").insert([
    { id: crypto.randomUUID(), space_id: sanDiego.id, role: "user", content: "alright who's looking into hotels?", user_id: "user_ram", sender_name: "ram", created_at: new Date(now - 10 * minute).toISOString() },
    { id: crypto.randomUUID(), space_id: sanDiego.id, role: "user", content: "i found a few near coronado beach", user_id: "user_ananya", sender_name: "ananya", created_at: new Date(now - 9 * minute).toISOString() },
    { id: crypto.randomUUID(), space_id: sanDiego.id, role: "xark", content: "hotel del coronado fits the group's vibe — beachfront, historic, within budget range. coronado island marriott is bayfront, lower price.", user_id: null, sender_name: null, created_at: new Date(now - 8 * minute).toISOString() },
    { id: crypto.randomUUID(), space_id: sanDiego.id, role: "user", content: "what about the price though?", user_id: "user_ram", sender_name: "ram", created_at: new Date(now - 7 * minute).toISOString() },
    { id: crypto.randomUUID(), space_id: sanDiego.id, role: "user", content: "450 a night but the beach access is worth it", user_id: "user_ananya", sender_name: "ananya", created_at: new Date(now - 6 * minute).toISOString() },
    { id: crypto.randomUUID(), space_id: sanDiego.id, role: "user", content: "i'm in for hotel del", user_id: "user_ram", sender_name: "ram", created_at: new Date(now - 5 * minute).toISOString() },
    { id: crypto.randomUUID(), space_id: sanDiego.id, role: "user", content: "same. let's lock it", user_id: "user_ananya", sender_name: "ananya", created_at: new Date(now - 4 * minute).toISOString() },
    { id: crypto.randomUUID(), space_id: sanDiego.id, role: "xark", content: "consensus reached on hotel del coronado. locked with confirmation HDC-29441.", user_id: null, sender_name: null, created_at: new Date(now - 3 * minute).toISOString() },
    { id: crypto.randomUUID(), space_id: sanDiego.id, role: "user", content: "locked. what activities are we doing?", user_id: "user_ram", sender_name: "ram", created_at: new Date(now - 2 * minute).toISOString() },
    { id: crypto.randomUUID(), space_id: sanDiego.id, role: "user", content: "i proposed surf lessons at la jolla — check it out", user_id: "user_ananya", sender_name: "ananya", created_at: new Date(now - 1 * minute).toISOString() },
  ]);
  console.log("  10 group messages seeded");

  // ═══════════════════════════════════════════
  // 2. ANANYA — 1:1 Sanctuary (private stream)
  // ═══════════════════════════════════════════
  const { data: sanctuary, error: sError } = await supabase
    .from("spaces")
    .insert({
      title: "ananya",
      owner_id: "user_ram",
      atmosphere: "sanctuary",
      agreement_score: 0,
      is_public: false,
    })
    .select()
    .single();

  if (sError) {
    console.error("failed to create sanctuary:", sError.message);
  } else {
    console.log(`  space: ${sanctuary.id} — ananya (sanctuary)`);

    // ── 5 Sanctuary Messages ──
    await supabase.from("messages").insert([
      { id: crypto.randomUUID(), space_id: sanctuary.id, role: "user", content: "hey, are you excited about the trip?", user_id: "user_ananya", sender_name: "ananya", created_at: new Date(now - 30 * minute).toISOString() },
      { id: crypto.randomUUID(), space_id: sanctuary.id, role: "user", content: "so excited. finally getting the whole group together", user_id: "user_ram", sender_name: null, created_at: new Date(now - 28 * minute).toISOString() },
      { id: crypto.randomUUID(), space_id: sanctuary.id, role: "user", content: "i've been looking at activities near la jolla", user_id: "user_ananya", sender_name: "ananya", created_at: new Date(now - 20 * minute).toISOString() },
      { id: crypto.randomUUID(), space_id: sanctuary.id, role: "user", content: "the kayaking looks amazing, those sea caves", user_id: "user_ram", sender_name: null, created_at: new Date(now - 15 * minute).toISOString() },
      { id: crypto.randomUUID(), space_id: sanctuary.id, role: "user", content: "did you see the surf lesson proposal?", user_id: "user_ananya", sender_name: "ananya", created_at: new Date(now - 5 * minute).toISOString() },
    ]);
    console.log("  5 sanctuary messages seeded");
  }

  // ═══════════════════════════════════════════
  // 3. TOKYO NEON NIGHTS — discovery space
  // ═══════════════════════════════════════════
  const { data: tokyo, error: tkError } = await supabase
    .from("spaces")
    .insert({
      title: "tokyo neon nights",
      owner_id: "user_community",
      atmosphere: "amber_glow",
      is_public: true,
      agreement_score: 0.35,
    })
    .select()
    .single();

  if (tkError) {
    console.error("failed to create tokyo space:", tkError.message);
  } else {
    console.log(`  space: ${tokyo.id} — tokyo neon nights`);

    await supabase
      .from("decision_items")
      .insert([
        {
          space_id: tokyo.id,
          title: "shibuya crossing at midnight",
          category: "Experience",
          description: "witness the world's busiest intersection under neon",
          agreement_score: 0.15,
          weighted_score: 2,
          state: "Proposed",
          is_locked: false,
          proposed_by: "name_maya",
          version: 0,
        },
        {
          space_id: tokyo.id,
          title: "teamlab borderless",
          category: "Activity",
          description: "immersive digital art museum in odaiba",
          agreement_score: 0.72,
          weighted_score: 11,
          state: "Proposed",
          is_locked: false,
          proposed_by: "name_jake",
          version: 0,
        },
      ]);
    console.log("  2 decision items seeded for tokyo");
  }

  // ═══════════════════════════════════════════
  // 4. SUMMER 2026 — empty space
  // ═══════════════════════════════════════════
  const { error: summerError } = await supabase.from("spaces").insert({
    title: "summer 2026",
    owner_id: "user_ram",
    atmosphere: "gold_warmth",
    agreement_score: 0.1,
  });

  if (!summerError) {
    console.log("  space: summer 2026");
  }

  console.log("\nseed complete.");
}

// Allow direct execution: npx tsx src/lib/seed.ts
seedXarkGalaxy().catch(console.error);
