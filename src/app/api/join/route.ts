import { NextRequest, NextResponse } from "next/server";
import { SignJWT } from "jose";

export async function POST(req: NextRequest) {
  try {
    const { token, displayName } = await req.json();
    if (!token || !displayName) {
      return NextResponse.json({ error: "token and displayName required" }, { status: 400 });
    }

    const { supabaseAdmin } = await import("@/lib/supabase-admin");
    if (!supabaseAdmin) {
      return NextResponse.json({ error: "server not configured" }, { status: 500 });
    }

    // Validate invite token
    const { data: invite } = await supabaseAdmin
      .from("space_invites")
      .select("*")
      .eq("token", token)
      .single();

    if (!invite) {
      return NextResponse.json({ error: "invalid invite" }, { status: 404 });
    }

    if (new Date(invite.expires_at) < new Date()) {
      return NextResponse.json({ error: "invite expired" }, { status: 410 });
    }

    if (invite.max_uses !== null && invite.use_count >= invite.max_uses) {
      return NextResponse.json({ error: "invite limit reached" }, { status: 410 });
    }

    const safeName = displayName.trim().toLowerCase().replace(/[^a-z0-9_]/g, "").slice(0, 20);
    if (!safeName) {
      return NextResponse.json({ error: "invalid name" }, { status: 400 });
    }

    const userId = `name_${safeName}`;

    await supabaseAdmin.from("users").upsert(
      { id: userId, display_name: safeName },
      { onConflict: "id" }
    );

    await supabaseAdmin.from("space_members").upsert(
      { space_id: invite.space_id, user_id: userId },
      { onConflict: "space_id,user_id" }
    );

    await supabaseAdmin
      .from("space_invites")
      .update({ use_count: invite.use_count + 1 })
      .eq("id", invite.id);

    const jwtSecret = process.env.SUPABASE_JWT_SECRET;
    if (!jwtSecret) {
      return NextResponse.json({ error: "jwt not configured" }, { status: 500 });
    }

    const secret = new TextEncoder().encode(jwtSecret);
    const jwt = await new SignJWT({
      sub: userId,
      role: "authenticated",
      aud: "authenticated",
      iss: "supabase",
    })
      .setProtectedHeader({ alg: "HS256", typ: "JWT" })
      .setIssuedAt()
      .setExpirationTime("24h")
      .sign(secret);

    return NextResponse.json({
      token: jwt,
      user: { id: userId, displayName: safeName },
      spaceId: invite.space_id,
    });
  } catch (err) {
    console.error("[xark] join error:", err);
    return NextResponse.json({ error: "join failed" }, { status: 500 });
  }
}
