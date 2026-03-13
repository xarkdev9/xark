// XARK OS v2.0 — Notification Service
// Server-side FCM push via Firebase Admin SDK.
// Safe: no-op when firebase-admin is not configured.

import type { ServiceAccount } from "firebase-admin";

let adminInitialized = false;

async function getAdmin() {
  if (adminInitialized) {
    const admin = await import("firebase-admin");
    return admin.default;
  }

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!serviceAccountJson) return null;

  try {
    const admin = await import("firebase-admin");
    if (!admin.default.apps.length) {
      const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson);
      admin.default.initializeApp({
        credential: admin.default.credential.cert(serviceAccount),
      });
    }
    adminInitialized = true;
    return admin.default;
  } catch (err) {
    console.warn("Firebase Admin initialization failed:", err);
    return null;
  }
}

export async function sendPush(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  if (tokens.length === 0) return;

  const admin = await getAdmin();
  if (!admin) return;

  try {
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: data ?? {},
      webpush: {
        fcmOptions: { link: data?.url ?? "/galaxy" },
      },
    });
  } catch (err) {
    console.error("FCM sendPush error:", err);
  }
}
