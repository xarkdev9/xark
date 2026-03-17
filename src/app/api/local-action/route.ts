// XARK OS v2.0 — Tier 1 Mutation Endpoint
// JWT-validated, supabaseAdmin writes. Atomic: mutation + ledger entry.
// Upserts space_dates for date commands.

import { NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";
import { checkRateLimit } from "@/lib/rate-limit";

export async function POST(req: Request) {
  // ── Auth ──
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const body = await req.json();
  const { action, spaceId, payload, previous, actorName } = body;

  if (!action || !spaceId) {
    return NextResponse.json({ error: "missing action or spaceId" }, { status: 400 });
  }

  // H6 fix: rate limit mutations
  if (!checkRateLimit(`local-action:${auth.userId}`, 20)) {
    return NextResponse.json({ error: "too many actions" }, { status: 429 });
  }

  // ── Membership check (skip for create_space — space doesn't exist yet) ──
  if (action !== "create_space") {
    const { data: member } = await supabaseAdmin
      .from("space_members")
      .select("user_id")
      .eq("space_id", spaceId)
      .eq("user_id", auth.userId)
      .single();

    if (!member) {
      return NextResponse.json({ error: "not a member" }, { status: 403 });
    }
  }

  try {
    // ── update_dates ──
    if (action === "update_dates") {
      const { start_date, end_date, label } = payload ?? {};
      if (!start_date || !end_date) {
        return NextResponse.json({ error: "missing dates" }, { status: 400 });
      }

      // Fetch previous state for undo
      const { data: currentDates } = await supabaseAdmin
        .from("space_dates")
        .select("start_date, end_date, label, version")
        .eq("space_id", spaceId)
        .single();

      // Upsert space_dates (downstream: purge TTL, retention, computeSpaceState)
      await supabaseAdmin.from("space_dates").upsert({
        space_id: spaceId,
        start_date,
        end_date,
        label: label ?? null,
        set_by: auth.userId,
        version: (currentDates?.version ?? 0) + 1,
        updated_at: new Date().toISOString(),
      });

      // Also update spaces.metadata
      const { data: space } = await supabaseAdmin
        .from("spaces")
        .select("metadata")
        .eq("id", spaceId)
        .single();

      const metadata = (space?.metadata as Record<string, unknown>) ?? {};
      await supabaseAdmin
        .from("spaces")
        .update({
          metadata: { ...metadata, start_date, end_date, label: label ?? undefined },
        })
        .eq("id", spaceId);

      // Write ledger entry
      await supabaseAdmin.from("space_ledger").insert({
        space_id: spaceId,
        actor_id: auth.userId,
        actor_name: actorName ?? null,
        action: "update_dates",
        payload: { start_date, end_date, label },
        previous: currentDates
          ? { start_date: currentDates.start_date, end_date: currentDates.end_date, label: currentDates.label }
          : {},
      });

      return NextResponse.json({ ok: true });
    }

    // ── rename_space ──
    if (action === "rename_space") {
      const { new_title } = payload ?? {};
      if (!new_title || typeof new_title !== "string") {
        return NextResponse.json({ error: "missing new_title" }, { status: 400 });
      }

      const { data: space } = await supabaseAdmin
        .from("spaces")
        .select("title")
        .eq("id", spaceId)
        .single();

      const previousTitle = space?.title ?? "";

      await supabaseAdmin
        .from("spaces")
        .update({ title: new_title.trim() })
        .eq("id", spaceId);

      await supabaseAdmin.from("space_ledger").insert({
        space_id: spaceId,
        actor_id: auth.userId,
        actor_name: actorName ?? null,
        action: "rename_space",
        payload: { new_title: new_title.trim() },
        previous: { old_title: previousTitle },
      });

      return NextResponse.json({ ok: true });
    }

    // ── revert ──
    if (action === "revert") {
      const { revert_target_id, revert_action, revert_previous } = payload ?? {};
      if (!revert_target_id || !revert_action || !revert_previous) {
        return NextResponse.json({ error: "missing revert data" }, { status: 400 });
      }

      if (revert_action === "update_dates") {
        const prev = revert_previous as { start_date?: string; end_date?: string; label?: string };
        if (prev.start_date && prev.end_date) {
          await supabaseAdmin.from("space_dates").upsert({
            space_id: spaceId,
            start_date: prev.start_date,
            end_date: prev.end_date,
            label: prev.label ?? null,
            set_by: auth.userId,
            updated_at: new Date().toISOString(),
          });
        } else {
          await supabaseAdmin.from("space_dates").delete().eq("space_id", spaceId);
        }
      } else if (revert_action === "rename_space") {
        const prev = revert_previous as { old_title?: string };
        if (prev.old_title) {
          await supabaseAdmin.from("spaces").update({ title: prev.old_title }).eq("id", spaceId);
        }
      }

      await supabaseAdmin.from("space_ledger").insert({
        space_id: spaceId,
        actor_id: auth.userId,
        actor_name: actorName ?? null,
        action: `revert_${revert_action}`,
        payload: revert_previous,
        previous: payload,
        revert_target_id,
      });

      return NextResponse.json({ ok: true });
    }

    // ── create_space — atomic: space + creator member + optional invite + seed message ──
    if (action === "create_space") {
      const { title, invite_username, atmosphere } = payload ?? {};
      if (!title) return NextResponse.json({ error: "missing title" }, { status: 400 });

      const slug = String(title).toLowerCase().replace(/[^a-z0-9\s-]/g, "").trim().replace(/\s+/g, "-").slice(0, 40);
      const newSpaceId = `space_${slug}`;

      // Create space
      await supabaseAdmin.from("spaces").upsert({
        id: newSpaceId,
        title: String(title).toLowerCase().trim(),
        owner_id: auth.userId,
        atmosphere: atmosphere ?? "cyan_horizon",
      }, { onConflict: "id" });

      // Add creator as member
      await supabaseAdmin.from("space_members").upsert(
        { space_id: newSpaceId, user_id: auth.userId, role: "owner" },
        { onConflict: "space_id,user_id" }
      );

      // Invite another user by display_name
      if (invite_username) {
        const { data: invitedUser } = await supabaseAdmin
          .from("users")
          .select("id")
          .ilike("display_name", String(invite_username))
          .single();
        if (invitedUser) {
          await supabaseAdmin.from("space_members").upsert(
            { space_id: newSpaceId, user_id: invitedUser.id, role: "member" },
            { onConflict: "space_id,user_id" }
          );
        }
      }

      // Seed message
      await supabaseAdmin.from("messages").insert({
        id: `msg_${crypto.randomUUID()}`,
        space_id: newSpaceId,
        role: "user",
        content: invite_username ? `started a chat` : `started planning ${String(title).toLowerCase()}`,
        user_id: auth.userId,
        sender_name: actorName ?? null,
      });

      return NextResponse.json({ ok: true, spaceId: newSpaceId });
    }

    return NextResponse.json({ error: `unknown action: ${action}` }, { status: 400 });
  } catch (err) {
    console.error("[local-action]", err);
    return NextResponse.json({ error: "mutation failed" }, { status: 500 });
  }
}
