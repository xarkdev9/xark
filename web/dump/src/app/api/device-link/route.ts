import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";

export async function POST(req: NextRequest) {
  try {
    if (!supabaseAdmin) {
      return NextResponse.json({ error: "server not configured." }, { status: 500 });
    }

    const auth = await verifyAuth(req.headers.get("authorization"));
    if (!auth) {
      return NextResponse.json({ error: "unauthorized" }, { status: 401 });
    }

    const { primaryPublicKeyB64, signedPublicKeyB64, signatureB64, deviceId } = await req.json();

    if (!primaryPublicKeyB64 || !signedPublicKeyB64 || !signatureB64 || !deviceId) {
      return NextResponse.json({ error: "missing cryptographic payload" }, { status: 400 });
    }

    // 1. Rehydrate CryptoProvider to verify the signature
    const { CryptoProviderFactory } = await import("@/lib/crypto/CryptoProvider");
    const { fromBase64 } = await import("@/lib/crypto/primitives");
    const provider = CryptoProviderFactory.getProvider();

    const importedPrimaryPubKey = await provider.importPublicKey(fromBase64(primaryPublicKeyB64).buffer as ArrayBuffer);

    // 2. Verify the linking signature
    const isVerified = await provider.verify(
      importedPrimaryPubKey,
      fromBase64(signatureB64).buffer as ArrayBuffer,
      fromBase64(signedPublicKeyB64).buffer as ArrayBuffer
    );

    if (!isVerified) {
      console.error("[/api/device-link] Secondary device signature rejected.");
      return NextResponse.json({ error: "invalid cryptographic linkage" }, { status: 403 });
    }

    // 3. Insert linked device record
    const { error } = await supabaseAdmin.from("linked_devices").insert({
      user_id: auth.userId,
      device_id: deviceId,
      public_key: signedPublicKeyB64,
      primary_signature: signatureB64,
    });

    if (error) {
      console.error("[/api/device-link] Insert error:", error);
      return NextResponse.json({ error: "failed to save link" }, { status: 500 });
    }

    return NextResponse.json({ success: true });

  } catch (err) {
    console.error("[/api/device-link] Error:", err);
    return NextResponse.json({ error: "internal server error" }, { status: 500 });
  }
}
