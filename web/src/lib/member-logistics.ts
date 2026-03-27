// XARK OS v2.0 — Per-User Logistics (Three-Source Passive Assembly)
// Spec: docs/superpowers/specs/2026-03-13-xark-capabilities-design.md (Section 3)

import { supabaseAdmin } from "./supabase-admin";

// ── Types ──

export interface LogisticsRow {
  space_id: string;
  user_id: string;
  category: string;
  origin: string | null;
  destination: string | null;
  state: string;
  item_id?: string | null;
  source: string | null;
  confidence: number | null;
}

export interface LogisticsExtraction {
  user_name: string;
  category?: string;
  origin?: string;
  destination?: string;
  confidence: number;
}

// ── Source Resolution (deterministic, no ambiguity) ──

export function resolveOrigin(
  tripOverride: string | null,
  creatorProvided: string | null,
  profileDefault: string | null
): { origin: string | null; source: string } {
  if (tripOverride) return { origin: tripOverride, source: "chat" };
  if (creatorProvided) return { origin: creatorProvided, source: "creator" };
  if (profileDefault) return { origin: profileDefault, source: "profile" };
  return { origin: null, source: "missing" };
}

// ── Skeleton Row Builder (pure function) ──

export function buildLogisticsSkeletonRows(
  spaceId: string,
  userId: string,
  homeCity: string | null,
  destination: string | null
): LogisticsRow[] {
  return ["flight_outbound", "flight_return"].map((cat) => ({
    space_id: spaceId,
    user_id: userId,
    category: cat,
    origin: cat === "flight_outbound" ? homeCity : destination,
    destination: cat === "flight_outbound" ? destination : homeCity,
    state: "missing" as const,
    source: homeCity ? ("profile" as const) : null,
    confidence: homeCity ? 1.0 : null,
  }));
}

// ── Auto-Population on Member Join ──

export async function onMemberJoin(
  spaceId: string,
  userId: string
): Promise<void> {
  const { data: user } = await supabaseAdmin
    .from("users")
    .select("home_city")
    .eq("id", userId)
    .single();

  const { data: dates } = await supabaseAdmin
    .from("space_dates")
    .select("destination")
    .eq("space_id", spaceId)
    .single();

  const rows = buildLogisticsSkeletonRows(
    spaceId,
    userId,
    user?.home_city ?? null,
    dates?.destination ?? null
  );

  await supabaseAdmin
    .from("member_logistics")
    .upsert(rows, {
      onConflict: "space_id,user_id,category",
      ignoreDuplicates: true,
    });
}

// ── Fetch logistics for a space ──

export async function fetchSpaceLogistics(
  spaceId: string
): Promise<LogisticsRow[]> {
  const { data } = await supabaseAdmin
    .from("member_logistics")
    .select("*")
    .eq("space_id", spaceId);
  return (data as LogisticsRow[]) ?? [];
}

// ── Apply extractions from Gemini ──

export async function applyLogisticsExtractions(
  spaceId: string,
  extractions: LogisticsExtraction[]
): Promise<{ applied: string[]; skipped: string[] }> {
  const applied: string[] = [];
  const skipped: string[] = [];

  // Resolve user_name → user_id via space_members JOIN users
  const { data: members } = await supabaseAdmin
    .from("space_members")
    .select("user_id, users!inner(display_name)")
    .eq("space_id", spaceId);

  const nameMap = new Map<string, string[]>();
  for (const m of members ?? []) {
    const usersData = m.users as unknown as { display_name: string } | { display_name: string }[];
    const userObj = Array.isArray(usersData) ? usersData[0] : usersData;
    if (!userObj) continue;
    const name = userObj.display_name.toLowerCase();
    const existing = nameMap.get(name) ?? [];
    existing.push(m.user_id);
    nameMap.set(name, existing);
  }

  for (const ext of extractions) {
    // Skip low confidence
    if (ext.confidence <= 0.8) {
      skipped.push(ext.user_name);
      continue;
    }

    const matches = nameMap.get(ext.user_name.toLowerCase()) ?? [];

    // Ambiguous name → skip (confidence drop)
    if (matches.length !== 1) {
      skipped.push(ext.user_name);
      continue;
    }

    const userId = matches[0];
    const category = ext.category ?? "flight_outbound";

    await supabaseAdmin
      .from("member_logistics")
      .update({
        origin: ext.origin ?? undefined,
        destination: ext.destination ?? undefined,
        source: "chat",
        confidence: ext.confidence,
        updated_at: new Date().toISOString(),
      })
      .match({ space_id: spaceId, user_id: userId, category });

    applied.push(ext.user_name);
  }

  return { applied, skipped };
}

// ── Staleness cascade on date change ──

export async function flagStaleLogistics(spaceId: string): Promise<number> {
  const { data } = await supabaseAdmin
    .from("member_logistics")
    .update({ state: "needs_review", updated_at: new Date().toISOString() })
    .eq("space_id", spaceId)
    .in("state", ["proposed", "locked"])
    .select("space_id");

  return data?.length ?? 0;
}
