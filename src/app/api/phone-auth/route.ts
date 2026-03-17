// XARK OS v2.0 — PHONE AUTH ENDPOINT
// POST /api/phone-auth — exchanges Firebase ID token for Supabase-compatible JWT.
// Flow: Firebase phone OTP → Firebase ID token → verify → find/create user → sign JWT.
// The JWT is compatible with Supabase RLS (sub = user.id, role = authenticated).

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { SignJWT } from "jose";
import { makeUserId } from "@/lib/user-id";
import { checkRateLimit } from "@/lib/rate-limit";

// Firebase Admin SDK for token verification (lightweight — just the auth piece)
import { initializeApp, getApps, cert, type ServiceAccount } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

// Initialize Firebase Admin (once)
function getFirebaseAdmin() {
  if (getApps().length > 0) return getAuth(getApps()[0]);

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (serviceAccountJson) {
    // Handle literal newlines in private_key (Vercel env vars may have actual \n bytes)
    const sanitized = serviceAccountJson.replace(/\n/g, "\\n").replace(/\\\\n/g, "\\n");
    const serviceAccount = JSON.parse(sanitized) as ServiceAccount;
    const app = initializeApp({ credential: cert(serviceAccount) });
    return getAuth(app);
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

  // H2 fix: rate limit by IP before any expensive Firebase verification
  const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  if (!checkRateLimit(`phone-auth:${ip}`, 10)) {
    return NextResponse.json({ error: "too many attempts" }, { status: 429 });
  }

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

  // Find or create user in Supabase
  // User ID format: phone_{last10digits} for consistency
  const phoneDigits = phoneNumber.replace(/\D/g, "").slice(-10);
  const userId = makeUserId("phone", phoneDigits);
  const name = displayName || phoneDigits.slice(-4);

  // Try to find existing user
  const { data: existingUser } = await supabaseAdmin
    .from("users")
    .select("id, display_name")
    .eq("id", userId)
    .single();

  if (!existingUser) {
    // Create new user
    await supabaseAdmin.from("users").insert({
      id: userId,
      display_name: name,
      phone: phoneNumber,
      firebase_uid: firebaseUid,
    });
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
