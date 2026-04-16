import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

/// <reference lib="deno.ns" />

/**
 * E2EE "Tickle" Push Notification Pipeline
 *
 * Triggered by Supabase Database Webhooks on `INSERT` to `message_ciphertexts`.
 * This function GUARANTEES that no plaintext or sensitive metadata is ever
 * transmitted through Apple APNs or Google FCM.
 * 
 * It sends a strictly "data-only" payload containing the `message_id`.
 * The client OS wakes up the Flutter app in the background, fetches the ciphertext,
 * decrypts it securely using the local SQLCipher Double Ratchet state, and 
 * triggers a local notification.
 */

serve(async (req) => {
  try {
    const body = await req.json();
    const record = body.record;

    if (!record || !record.id) {
      return new Response(JSON.stringify({ error: "Missing record payload" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const messageId = record.id;
    // For 1:1, we assume there's a receiver_id. For groups, a space_id.
    const spaceId = record.space_id || record.conversation_id || "unknown";

    // 1. You would query your `user_devices` table here to get the recipient's FCM tokens
    // using Supabase Service Role Key.
    // e.g. const tokens = await supabase.from('devices').select('fcm_token').eq('user_id', record.receiver_id)
    const fcmTarget = "target-fcm-token-from-database"; // Placeholder for the actual lookup

    // 2. Obtain OAuth2 access token for Firebase HTTP v1 API
    // (Usually via googleapis package or signed JWT using service account credentials)
    const firebaseAccessToken = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_TOKEN") || "";

    // 3. Construct the PRIVACY-PRESERVING data-only push.
    // NOTICE: The "notification" block is COMPLETELY OMITTED.
    const fcmPayload = {
      message: {
        token: fcmTarget,
        data: {
          type: "tickle",
          message_id: messageId.toString(),
          space_id: spaceId.toString(),
        },
        android: {
          priority: "high", // Required for Android Doze mode wake-ups
        },
        apns: {
          headers: {
            "apns-priority": "5",       // Background priority
            "apns-push-type": "background"
          },
          payload: {
            aps: {
              "content-available": 1,   // Crucial: iOS interprets this as a silent background wake-up
            },
          },
        },
      },
    };

    // 4. Send to Firebase Cloud Messaging (FCM)
    const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${firebaseAccessToken}`,
        },
        body: JSON.stringify(fcmPayload),
      }
    );

    if (!response.ok) {
      const errText = await response.text();
      console.error("FCM Send Failure:", errText);
      throw new Error("Failed to dispatch tickle push");
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Tickle payload dispatched",
        message_id: messageId,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    console.error("Tickle Pipeline Fatal Error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
