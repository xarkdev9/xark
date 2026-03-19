// XARK OS v2.0 — POST /api/contacts/check
// Takes an array of phone numbers, returns which ones are registered on Xark.
// Does NOT return display_name — the client has names from the phone's contacts.

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";
import { checkRateLimit } from "@/lib/rate-limit";

export async function POST(req: NextRequest) {
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  if (!checkRateLimit(`contacts:${auth.userId}`, 5, 60_000)) {
    return NextResponse.json({ error: "rate limited" }, { status: 429 });
  }

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "not configured" }, { status: 500 });
  }

  let body: { phones?: unknown };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "invalid json" }, { status: 400 });
  }

  const { phones } = body;
  if (!Array.isArray(phones) || phones.length === 0 || phones.length > 500) {
    return NextResponse.json({ error: "phones array required (max 500)" }, { status: 400 });
  }

  // Normalize: strip all non-digits, keep last 10
  const normalized = phones
    .filter((p): p is string => typeof p === "string")
    .map((p) => p.replace(/\D/g, "").slice(-10))
    .filter((p) => p.length >= 7);

  if (normalized.length === 0) {
    return NextResponse.json({ registered: [] });
  }

  // Build user IDs in the format Xark uses: phone_{last10digits}
  const possibleIds = normalized.map((n) => `phone_${n}`);

  const { data, error } = await supabaseAdmin
    .from("users")
    .select("id, phone")
    .in("id", possibleIds);

  if (error) {
    return NextResponse.json({ error: "lookup failed" }, { status: 500 });
  }

  // Return only phone + userId — NOT display_name (client has names from contacts)
  const registered = (data ?? []).map((u) => ({
    phone: u.phone,
    userId: u.id,
  }));

  return NextResponse.json({ registered });
}
