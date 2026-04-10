// Server-side JWT verification for API routes.
// Verifies the Authorization: Bearer <token> header using SUPABASE_JWT_SECRET.
// Returns the authenticated userId (sub claim) or null.

import { jwtVerify } from "jose";

export interface AuthResult {
  userId: string;
}

/** Verify JWT from Authorization header. Returns { userId } or null. */
export async function verifyAuth(
  authHeader: string | null
): Promise<AuthResult | null> {
  if (!authHeader || !authHeader.startsWith("Bearer ")) return null;

  const token = authHeader.slice(7);
  const secret = process.env.SUPABASE_JWT_SECRET;
  if (!secret) return null;

  try {
    const { payload } = await jwtVerify(
      token,
      new TextEncoder().encode(secret),
      { algorithms: ["HS256"] }
    );

    const userId = payload.sub;
    if (!userId || typeof userId !== "string") return null;

    return { userId };
  } catch {
    return null;
  }
}
