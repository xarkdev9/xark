/// Server-side AppCheck token verification for API routes.

export async function verifyAppCheckToken(token: string | null): Promise<boolean> {
  if (!token) return false;
  if (!process.env.FIREBASE_PROJECT_ID) return true; // Skip in dev

  try {
    // Firebase Admin SDK AppCheck verification
    // Using REST API to avoid heavy admin SDK dependency
    const response = await fetch(
      `https://firebaseappcheck.googleapis.com/v1/projects/${process.env.FIREBASE_PROJECT_ID}/apps/-:exchangeAppCheckToken`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ app_check_token: token }),
      }
    );
    return response.ok;
  } catch {
    // Verification failure — reject the request
    return false;
  }
}

/// Middleware helper: extract and verify AppCheck token from request
export async function requireAppCheck(req: Request): Promise<{ valid: boolean; error?: string }> {
  const token = req.headers.get('X-Firebase-AppCheck');

  // In development, skip AppCheck
  if (process.env.NODE_ENV !== 'production') {
    return { valid: true };
  }

  if (!token) {
    return { valid: false, error: 'missing_appcheck_token' };
  }

  const valid = await verifyAppCheckToken(token);
  if (!valid) {
    return { valid: false, error: 'invalid_appcheck_token' };
  }

  return { valid: true };
}
