// hello OS v2.0 — Notification Service
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

/**
 * Send push notification to devices.
 * E2EE COMPLIANT: Never include message plaintext in the push payload.
 * The payload contains ONLY metadata (senderName, spaceId, event).
 * The Service Worker shows a generic notification. Decryption happens on app open.
 */
export async function sendPush(
  tokens: string[],
  data: Record<string, string>
): Promise<void> {
  if (tokens.length === 0) return;

  const admin = await getAdmin();
  if (!admin) return;

  try {
    await admin.messaging().sendEachForMulticast({
      tokens,
      // NO `notification` field — this would bypass the SW and show plaintext directly.
      // ALL content goes through `data` so the SW controls what's displayed.
      data,
      webpush: {
        fcmOptions: { link: `/space/${data.spaceId ?? ''}` },
      },
      // Safari/APNs fallback — generic text, zero plaintext
      apns: {
        payload: {
          aps: {
            alert: {
              title: data.senderName ? `${data.senderName}` : "hello",
              body: "new encrypted message",
            },
            sound: "default",
          },
        },
      },
    });
  } catch (err) {
    console.error("FCM sendPush error:", err);
  }
}
