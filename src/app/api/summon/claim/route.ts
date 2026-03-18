// XARK OS v2.0 — SUMMON LINK CLAIM
// POST /api/summon/claim — verifies Firebase token, finds/creates user, claims link, creates space.
// Body: { code: string, firebaseToken: string }
// Returns { token, user: { id, displayName }, spaceId }

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { SignJWT } from "jose";
import { makeUserId } from "@/lib/user-id";
import { checkRateLimit } from "@/lib/rate-limit";

// Firebase Admin SDK for token verification (matches phone-auth pattern exactly)
import { initializeApp, getApps, cert, type ServiceAccount } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

// Initialize Firebase Admin (once — shared with phone-auth if already initialized)
function getFirebaseAdmin() {
  if (getApps().length > 0) return getAuth(getApps()[0]);

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (serviceAccountJson) {
    try {
      // Handle literal newlines in private_key (Vercel env vars may have actual \n bytes)
      // Extract just the JSON object (in case trailing data got appended)
      const jsonStart = serviceAccountJson.indexOf("{");
      const jsonEnd = serviceAccountJson.lastIndexOf("}");
      if (jsonStart === -1 || jsonEnd === -1) throw new Error("No JSON object found");
      const extracted = serviceAccountJson.slice(jsonStart, jsonEnd + 1);
      const sanitized = extracted.replace(/\n/g, "\\n").replace(/\\\\n/g, "\\n");
      const serviceAccount = JSON.parse(sanitized) as ServiceAccount;
      const app = initializeApp({ credential: cert(serviceAccount) });
      return getAuth(app);
    } catch (parseErr) {
      console.error("[summon/claim] Firebase service account parse error:", parseErr);
      return null;
    }
  }

  // Fallback: use project ID only (works in GCP environments)
  const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
  if (projectId) {
    const app = initializeApp({ projectId });
    return getAuth(app);
  }

  return null;
}

export async function POST(request: NextRequest) {
  const jwtSecret = process.env.SUPABASE_JWT_SECRET;
  if (!jwtSecret) {
    return NextResponse.json(
      { error: "SUPABASE_JWT_SECRET not configured" },
      { status: 500 }
    );
  }

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "not configured" }, { status: 500 });
  }

  let body: { code?: string; firebaseToken?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "invalid request body" }, { status: 400 });
  }

  const { code, firebaseToken } = body;

  if (!code || typeof code !== "string") {
    return NextResponse.json({ error: "code required" }, { status: 400 });
  }

  if (!firebaseToken) {
    return NextResponse.json({ error: "firebaseToken required" }, { status: 400 });
  }

  // Rate limit by IP before expensive Firebase verification
  const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  if (!checkRateLimit(`summon-claim:${ip}`, 10, 60_000)) {
    return NextResponse.json({ error: "too many attempts" }, { status: 429 });
  }

  // Verify Firebase ID token
  const firebaseAuth = getFirebaseAdmin();
  if (!firebaseAuth) {
    return NextResponse.json(
      { error: "Firebase Admin not configured" },
      { status: 500 }
    );
  }

  let decodedToken;
  try {
    decodedToken = await firebaseAuth.verifyIdToken(firebaseToken);
  } catch {
    return NextResponse.json(
      { error: "invalid or expired Firebase token" },
      { status: 401 }
    );
  }

  const phoneNumber = decodedToken.phone_number;

  if (!phoneNumber) {
    return NextResponse.json({ error: "no phone number in token" }, { status: 400 });
  }

  // Find or create claimant user (matches phone-auth pattern exactly)
  const phoneDigits = phoneNumber.replace(/\D/g, "").slice(-10);
  const userId = makeUserId("phone", phoneDigits);
  const name = phoneDigits.slice(-4);

  const { data: existingUser } = await supabaseAdmin
    .from("users")
    .select("id, display_name")
    .eq("id", userId)
    .single();

  if (!existingUser) {
    const { error: insertError } = await supabaseAdmin.from("users").insert({
      id: userId,
      display_name: name,
      phone: phoneNumber,
    });
    if (insertError) {
      console.error("[summon/claim] user insert failed:", insertError.message);
    }
  }

  const resolvedName = existingUser?.display_name ?? name;

  // Claim the summon link + create space via RPC
  const { data: result, error: rpcError } = await supabaseAdmin.rpc(
    "claim_summon_link",
    { p_code: code, p_claimant_id: userId }
  );

  if (rpcError) {
    console.error("[summon/claim] RPC failed:", rpcError.message);
    return NextResponse.json({ error: rpcError.message }, { status: 400 });
  }

  if (result?.error) {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }

  // Sign Supabase-compatible JWT (matches phone-auth pattern exactly)
  const secret = new TextEncoder().encode(jwtSecret);
  const now = Math.floor(Date.now() / 1000);

  const token = await new SignJWT({
    sub: userId,
    role: "authenticated",
    aud: "authenticated",
    iss: "supabase",
    iat: now,
    exp: now + 86400, // 24h
    phone: phoneNumber,
  })
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .sign(secret);

  return NextResponse.json({
    token,
    user: {
      id: userId,
      displayName: resolvedName,
    },
    spaceId: result?.spaceId ?? null,
  });
}
