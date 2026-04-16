// hello OS v2.0 — Tier 1 Mutation Endpoint
// JWT-validated, supabaseAdmin writes. Atomic: mutation + ledger entry.
// Upserts space_dates for date commands.

import { NextResponse } from "next/server";
import { after } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";

export async function POST(req: Request) {
  // ── Auth ──
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const body = await req.json();
  const { action, groupId, payload, previous, actorName } = body;

  if (!action || !groupId) {
    return NextResponse.json({ error: "missing action or groupId" }, { status: 400 });
  }

  // Rate limiting moved to edge proxy (BACKEND-03)

  // ── Membership check (skip for create_space — space doesn't exist yet) ──
  if (action !== "create_space") {
    const { data: member } = await supabaseAdmin
      .from("space_members")
      .select("user_id")
      .eq("group_id", groupId)
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
        .eq("group_id", groupId)
        .single();

      // Upsert space_dates (downstream: purge TTL, retention, computeGroupState)
      await supabaseAdmin.from("space_dates").upsert({
        group_id: groupId,
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
        .eq("id", groupId)
        .single();

      const metadata = (space?.metadata as Record<string, unknown>) ?? {};
      await supabaseAdmin
        .from("spaces")
        .update({
          metadata: { ...metadata, start_date, end_date, label: label ?? undefined },
        })
        .eq("id", groupId);

      // Write ledger entry
      await supabaseAdmin.from("space_ledger").insert({
        group_id: groupId,
        actor_id: auth.userId,
        actor_name: actorName ?? null,
        action: "update_dates",
        payload: { start_date, end_date, label },
        previous: currentDates
          ? { start_date: currentDates.start_date, end_date: currentDates.end_date, label: currentDates.label }
          : {},
      });

      // ── Auto-trigger itinerary generation after dates are set ──
      // Resolve destination from space title (e.g., "Bali Trip" → "Bali")
      const { data: spaceData } = await supabaseAdmin
        .from("spaces")
        .select("title")
        .eq("id", groupId)
        .single();
      const spaceTitle = spaceData?.title || "";

      // Check if destination is resolvable (not a person's name like "ram & myna")
      const looksLikeDestination = spaceTitle.length > 2 &&
        !/^\w+\s*[&+]\s*\w+$/.test(spaceTitle) && // skip "name & name" patterns
        !/^new user/i.test(spaceTitle);

      if (looksLikeDestination) {
        // Check if itinerary items already exist for this group
        const { count } = await supabaseAdmin
          .from("decision_items")
          .select("id", { count: "exact", head: true })
          .eq("group_id", groupId)
          .eq("category", "recommendation");

        const hasExistingItinerary = (count ?? 0) > 0;

        after(async () => {
          try {
            if (hasExistingItinerary) {
              // Re-hydrate existing dream itinerary with real dates
              console.log(`[itinerary] Re-hydrating dream plan for ${groupId} with dates ${start_date} to ${end_date}`);
              const { data: existingItems } = await supabaseAdmin
                .from("decision_items")
                .select("*")
                .eq("group_id", groupId)
                .eq("category", "recommendation");

              if (existingItems && existingItems.length > 0) {
                const { rehydrateItinerary } = await import("@/lib/intelligence/itinerary-generator");
                const slots = existingItems.map((item: Record<string, unknown>) => {
                  const meta = (item.metadata ?? {}) as Record<string, unknown>;
                  return {
                    date: String(meta.itinerary_day || ""),
                    time: String(meta.itinerary_slot || ""),
                    type: String(item.category || ""),
                    label: String(meta.itinerary_label || ""),
                    query: String(meta.search_label || ""),
                    note: String(item.description || ""),
                    title: String(item.title || ""),
                    price: meta.price ? String(meta.price) : undefined,
                    imageUrl: meta.image_url ? String(meta.image_url) : undefined,
                  };
                });

                const rehydrated = await rehydrateItinerary(slots, start_date, end_date, spaceTitle);
                console.log(`[itinerary] Re-hydrated ${rehydrated.length} slots with real dates`);
              }
            } else {
              // Generate fresh itinerary
              console.log(`[itinerary] Auto-generating itinerary for ${groupId}: ${spaceTitle}, ${start_date} to ${end_date}`);
              const { generateItinerary } = await import("@/lib/intelligence/itinerary-generator");

              // Fetch group member count
              const { count: memberCount } = await supabaseAdmin
                .from("space_members")
                .select("id", { count: "exact", head: true })
                .eq("group_id", groupId);

              const itinerary = await generateItinerary({
                destination: spaceTitle,
                startDate: start_date,
                endDate: end_date,
                groupSize: memberCount ?? 2,
                constraints: "",
                tasteContext: "",
                lockedDecisions: "",
              });

              if (itinerary.slots.length > 0) {
                // Insert as recommendation decision_items
                const items = itinerary.slots
                  .filter((s) => s.type !== "travel" && s.title)
                  .map((s) => ({
                    id: `item_${crypto.randomUUID()}`,
                    group_id: groupId,
                    title: (s.title || s.query).toLowerCase(),
                    category: "recommendation",
                    description: s.description || s.note || "",
                    state: "proposed",
                    proposed_by: null,
                    agreement_score: 0,
                    weighted_score: 0,
                    is_locked: false,
                    version: 0,
                    metadata: {
                      itinerary_day: s.date,
                      itinerary_slot: s.time,
                      itinerary_label: s.label,
                      price: s.price,
                      image_url: s.imageUrl,
                      external_url: s.externalUrl,
                      booking_url: s.bookingUrl || s.externalUrl,
                      rating: s.rating,
                      source: s.source || "itinerary",
                      search_tier: "itinerary",
                      recent_review: s.recentReview,
                      cached_at: Date.now(),
                    },
                  }));

                await supabaseAdmin.from("decision_items").upsert(items, { onConflict: "id" });
                console.log(`[itinerary] Inserted ${items.length} recommendation items for ${groupId}`);

                // Send ONE batched message to chat (not 15 individual notifications)
                const dayCount = new Set(itinerary.slots.map((s) => s.date)).size;
                await supabaseAdmin.from("messages").insert({
                  id: crypto.randomUUID(),
                  group_id: groupId,
                  sender_id: null,
                  role: "hello",
                  content: `your ${spaceTitle} blueprint is ready — ${dayCount} days, ${items.length} spots. check Plans.`,
                  message_type: "ai",
                });
              }
            }
          } catch (err) {
            console.error("[itinerary] Auto-generation failed:", err instanceof Error ? err.message : String(err));
          }
        });
      }

      return NextResponse.json({ ok: true });
    }

    // ── rename_space ──
    if (action === "rename_space") {
      const { new_title } = payload ?? {};
      if (!new_title || typeof new_title !== "string") {
        return NextResponse.json({ error: "missing new_title" }, { status: 400 });
      }
      if (new_title.length > 100) {
        return NextResponse.json({ error: "title too long" }, { status: 400 });
      }

      const { data: space } = await supabaseAdmin
        .from("spaces")
        .select("title")
        .eq("id", groupId)
        .single();

      const previousTitle = space?.title ?? "";

      await supabaseAdmin
        .from("spaces")
        .update({ title: new_title.trim() })
        .eq("id", groupId);

      await supabaseAdmin.from("space_ledger").insert({
        group_id: groupId,
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
            group_id: groupId,
            start_date: prev.start_date,
            end_date: prev.end_date,
            label: prev.label ?? null,
            set_by: auth.userId,
            updated_at: new Date().toISOString(),
          });
        } else {
          await supabaseAdmin.from("space_dates").delete().eq("group_id", groupId);
        }
      } else if (revert_action === "rename_space") {
        const prev = revert_previous as { old_title?: string };
        if (prev.old_title) {
          await supabaseAdmin.from("spaces").update({ title: prev.old_title }).eq("id", groupId);
        }
      }

      await supabaseAdmin.from("space_ledger").insert({
        group_id: groupId,
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
      const { title, invite_username, groupType, atmosphere } = payload ?? {} as any;
      if (!title) return NextResponse.json({ error: "missing title" }, { status: 400 });
      if (String(title).length > 100) {
        return NextResponse.json({ error: "title too long" }, { status: 400 });
      }
      const VALID_TYPES = ["cyan_horizon", "dm", "amber_glow", "gold_warmth", ""];
      const safeType = VALID_TYPES.includes(atmosphere ?? "") ? (atmosphere ?? "cyan_horizon") : "cyan_horizon";

      const slug = String(title).toLowerCase().replace(/[^a-z0-9\s-]/g, "").trim().replace(/\s+/g, "-").slice(0, 40);
      // Non-deterministic ID — prevents cross-tenant hijacking via slug guessing
      const newGroupId = `space_${slug}_${crypto.randomUUID().slice(0, 8)}`;

      // INSERT only — never upsert. If space exists, fail with conflict.
      const { error: insertError } = await supabaseAdmin.from("spaces").insert({
        id: newGroupId,
        title: String(title).toLowerCase().trim(),
        owner_id: auth.userId,
        atmosphere: safeType,
      });

      if (insertError) {
        // Unique constraint violation = space already exists
        if (insertError.code === '23505') {
          return NextResponse.json({ error: "space already exists" }, { status: 409 });
        }
        throw insertError;
      }

      // Add creator as member (insert, not upsert)
      await supabaseAdmin.from("space_members").insert({
        group_id: newGroupId,
        user_id: auth.userId,
        role: "owner",
      });

      // Invite another user explicitly by precise ID or fallback to display_name match
      const inviteUserId = payload?.invite_user_id;
      if (inviteUserId && String(inviteUserId).length > 0) {
        await supabaseAdmin.from("space_members").insert({
          group_id: newGroupId,
          user_id: String(inviteUserId),
          role: "member",
        });
      } else if (invite_username) {
        const { data: invitedUser } = await supabaseAdmin
          .from("users")
          .select("id")
          .ilike("display_name", String(invite_username))
          .limit(1).maybeSingle();
        if (invitedUser) {
          await supabaseAdmin.from("space_members").insert({
            group_id: newGroupId,
            user_id: invitedUser.id,
            role: "member",
          });
        }
      }

      // Seed message
      await supabaseAdmin.from("messages").insert({
        id: `msg_${crypto.randomUUID()}`,
        group_id: newGroupId,
        role: "user",
        content: invite_username ? `started a chat` : `started planning ${String(title).toLowerCase()}`,
        user_id: auth.userId,
        sender_name: actorName ?? null,
      });

      return NextResponse.json({ ok: true, groupId: newGroupId });
    }

    return NextResponse.json({ error: `unknown action: ${action}` }, { status: 400 });
  } catch (err) {
    console.error("[local-action]", err);
    return NextResponse.json({ error: "mutation failed" }, { status: 500 });
  }
}
