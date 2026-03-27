// hello OS v2.0 — PHONE AUTH ENDPOINT
// POST /api/phone-auth — exchanges Firebase ID token for Supabase-compatible JWT.
// Flow: Firebase phone OTP → Firebase ID token → verify → find/create user → sign JWT.
// The JWT is compatible with Supabase RLS (sub = user.id, role = authenticated).

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { SignJWT } from "jose";
import { makeUserId } from "@/lib/user-id";
import { requireAppCheck } from "@/lib/appcheck-verify";

// Firebase Admin SDK for token verification (lightweight — just the auth piece)
import { initializeApp, getApps, cert, type ServiceAccount } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

// Initialize Firebase Admin (once)
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
      console.error("[phone-auth] Firebase service account parse error:", parseErr);
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
  // Device attestation: reject requests without valid AppCheck token (production only)
  const appCheck = await requireAppCheck(request);
  if (!appCheck.valid) {
    return NextResponse.json(
      { error: appCheck.error },
      { status: 403 }
    );
  }

  const jwtSecret = process.env.SUPABASE_JWT_SECRET;
  if (!jwtSecret) {
    return NextResponse.json(
      { error: "SUPABASE_JWT_SECRET not configured" },
      { status: 500 }
    );
  }

  let body: { firebaseToken?: string; displayName?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { error: "invalid request body" },
      { status: 400 }
    );
  }

  const { firebaseToken, displayName } = body;

  // Rate limiting moved to edge proxy (BACKEND-03)

  if (!firebaseToken) {
    return NextResponse.json(
      { error: "firebaseToken required" },
      { status: 400 }
    );
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
  const firebaseUid = decodedToken.uid;

  if (!phoneNumber) {
    return NextResponse.json(
      { error: "no phone number in token" },
      { status: 400 }
    );
  }

  // ── PRIVATE ACCESS GATE ──
  // If ALLOWED_PHONES is set, only whitelisted numbers can log in.
  // Format: comma-separated E.164 numbers, e.g. "+18598697979,+919741783444"
  // To open to everyone: remove ALLOWED_PHONES from env vars.
  // To add a user: add their number to the comma-separated list in Vercel env vars.
  const allowedPhones = process.env.ALLOWED_PHONES;
  if (allowedPhones) {
    const whitelist = allowedPhones.split(",").map((p) => p.trim());
    if (!whitelist.includes(phoneNumber)) {
      console.log(`[phone-auth] Blocked: ${phoneNumber} not in whitelist`);
      return NextResponse.json(
        { error: "this app is invite-only right now." },
        { status: 403 }
      );
    }
  }

  // Find or create user in Supabase
  // User ID format: phone_{last10digits} for consistency
  const phoneDigits = phoneNumber.replace(/\D/g, "").slice(-10);
  const userId = makeUserId("phone", phoneDigits);
  const name = displayName || "new user";

  // Try to find existing user
  const { data: existingUser } = await supabaseAdmin
    .from("users")
    .select("id, display_name")
    .eq("id", userId)
    .maybeSingle();

  if (!existingUser) {
    // Create new user
    const { error: insertError } = await supabaseAdmin.from("users").insert({
      id: userId,
      display_name: name,
      phone: phoneNumber,
    });
    if (insertError) {
      console.error("[phone-auth] user insert failed:", insertError.message);
    }
  }

  const resolvedName = existingUser?.display_name ?? name;

  // Sign Supabase-compatible JWT
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
  });
}
