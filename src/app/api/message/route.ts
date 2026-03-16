// XARK OS v2.0 — Unified Message Endpoint
// Atomic: encrypted message storage + optional @xark trigger.
// Replaces separate message insert + /api/xark for E2EE messages.
// Existing /api/xark remains for backward compatibility (legacy messages).

export const maxDuration = 60;

import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { verifyAuth } from '@/lib/auth-verify';
import { orchestrate, isGarbageResponse } from '@/lib/intelligence/orchestrator';
import { buildGroundingContext, generateGroundingPrompt } from '@/lib/ai-grounding';
import { fetchMessages } from '@/lib/messages';
import { sanitizeForIntelligence } from '@/lib/intelligence/sanitize';
import { checkRateLimit } from '@/lib/rate-limit';

export async function POST(req: NextRequest) {
  try {
    if (!supabaseAdmin) {
      return NextResponse.json({ error: 'server not configured' }, { status: 500 });
    }

    // ── Auth ──
    const auth = await verifyAuth(req.headers.get('authorization'));
    if (!auth) {
      return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
    }

    const body = await req.json();
    const {
      space_id,
      sender_device_id,
      ciphertext,
      ratchet_header,
      recipient_id,
      recipient_device_id,
      xark_trigger,
      message_type_override,
      distribution_ciphertexts,
    } = body;

    // ── Input validation ──
    if (!space_id || typeof space_id !== 'string') {
      return NextResponse.json({ error: 'space_id required' }, { status: 400 });
    }
    if (!ciphertext || typeof ciphertext !== 'string') {
      return NextResponse.json({ error: 'ciphertext required' }, { status: 400 });
    }
    if (ciphertext.length > 65536) {
      return NextResponse.json({ error: 'ciphertext too large' }, { status: 400 });
    }

    // ── C2 fix: validate message_type_override against strict allowlist ──
    const ALLOWED_CLIENT_TYPES = ['e2ee', 'e2ee_xark', 'sender_key_dist'] as const;
    if (message_type_override && !ALLOWED_CLIENT_TYPES.includes(message_type_override as typeof ALLOWED_CLIENT_TYPES[number])) {
      return NextResponse.json({ error: 'invalid message_type_override' }, { status: 400 });
    }

    // ── H5 fix: cap xark_trigger length (matches /api/xark 1000-char cap) ──
    if (xark_trigger) {
      if (typeof xark_trigger.plaintext_command === 'string' && xark_trigger.plaintext_command.length > 1000) {
        return NextResponse.json({ error: 'xark command too long' }, { status: 400 });
      }
      if (typeof xark_trigger.bundled_context === 'string' && xark_trigger.bundled_context.length > 2000) {
        return NextResponse.json({ error: 'context too long' }, { status: 400 });
      }
    }

    // ── Rate limit @xark triggers ──
    if (xark_trigger && !checkRateLimit(`xark:${auth.userId}`, 10)) {
      return NextResponse.json({
        error: 'rate limited',
        messageId: null,
      }, { status: 429 });
    }

    // ── Space membership check — prevent cross-space injection ──
    const { data: membership } = await supabaseAdmin
      .from('space_members')
      .select('user_id')
      .eq('space_id', space_id)
      .eq('user_id', auth.userId)
      .single();

    if (!membership) {
      return NextResponse.json({ error: 'not a member of this space' }, { status: 403 });
    }

    // ── Step 1: Insert encrypted message envelope ──
    const msgId = `msg_${crypto.randomUUID()}`;
    const messageType = message_type_override ?? (xark_trigger ? 'e2ee_xark' : 'e2ee');

    const { error: msgError } = await supabaseAdmin.from('messages').insert({
      id: msgId,
      space_id,
      user_id: auth.userId,
      sender_device_id: sender_device_id ?? null,
      message_type: messageType,
      role: 'user',
      content: null,       // E2EE — server never sees plaintext
      sender_name: null,   // resolved client-side from space_members
      created_at: new Date().toISOString(),
    });

    if (msgError) {
      console.error('[/api/message] insert message failed:', msgError.message);
      return NextResponse.json({ error: 'message insert failed' }, { status: 500 });
    }

    // ── Step 2: Insert ciphertext ──
    const { error: cipherError } = await supabaseAdmin.from('message_ciphertexts').insert({
      id: `mc_${crypto.randomUUID()}`,
      message_id: msgId,
      recipient_id: recipient_id ?? '_group_',
      recipient_device_id: recipient_device_id ?? 0,
      ciphertext,
      ratchet_header: ratchet_header ?? null,
    });

    if (cipherError) {
      console.error('[/api/message] insert ciphertext failed:', cipherError.message);
      // Rollback the message
      await supabaseAdmin.from('messages').delete().eq('id', msgId);
      return NextResponse.json({ error: 'ciphertext insert failed' }, { status: 500 });
    }

    // ── Step 2b: Insert per-recipient distribution ciphertexts (Sender Key dist) ──
    if (distribution_ciphertexts && Array.isArray(distribution_ciphertexts) && distribution_ciphertexts.length > 0) {
      // Security: cap array size and whitelist fields to prevent type injection
      if (distribution_ciphertexts.length > 100) {
        return NextResponse.json({ error: 'too many distribution ciphertexts (max 100)' }, { status: 400 });
      }
      const distRows = distribution_ciphertexts.map((ct: Record<string, unknown>) => ({
        id: typeof ct.id === 'string' ? ct.id : `mc_${crypto.randomUUID()}`,
        message_id: msgId,
        recipient_id: typeof ct.recipient_id === 'string' ? ct.recipient_id : '_group_',
        recipient_device_id: typeof ct.recipient_device_id === 'number' ? ct.recipient_device_id : 0,
        ciphertext: typeof ct.ciphertext === 'string' ? ct.ciphertext : '',
        ratchet_header: typeof ct.ratchet_header === 'string' ? ct.ratchet_header : null,
      }));
      const { error: distError } = await supabaseAdmin.from('message_ciphertexts').insert(distRows);
      if (distError) {
        console.warn('[/api/message] distribution ciphertext insert failed:', distError.message);
        // Non-fatal — some members may not get the key, they'll request it later
      }
    }

    // ── Step 3: If @xark trigger, process asynchronously ──
    let xarkMessageId: string | null = null;

    if (xark_trigger) {
      xarkMessageId = `msg_${crypto.randomUUID()}`;

      // Insert thinking placeholder
      await supabaseAdmin.from('messages').insert({
        id: xarkMessageId,
        space_id,
        user_id: null,
        message_type: 'xark',
        role: 'xark',
        content: 'thinking...',
        sender_name: null,
        created_at: new Date().toISOString(),
      });

      // Fire-and-forget orchestration (don't block response)
      orchestrateAndUpdate(xarkMessageId, space_id, xark_trigger).catch(err => {
        console.error('[/api/message] orchestration error:', err);
      });
    }

    return NextResponse.json({
      messageId: msgId,
      xarkMessageId,
    });

  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err);
    console.error('[/api/message] error:', errMsg);
    return NextResponse.json({ error: 'internal error' }, { status: 500 });
  }
}

// ── @xark orchestration (preserved from /api/xark) ──

async function orchestrateAndUpdate(
  xarkMsgId: string,
  spaceId: string,
  trigger: { plaintext_command: string; bundled_context?: string }
): Promise<void> {
  try {
    // Parallel fetch: space title + grounding context + recent messages
    const [spaceRow, groundingContext, recentMsgs] = await Promise.all([
      supabaseAdmin
        .from('spaces')
        .select('title')
        .eq('id', spaceId)
        .single()
        .then(r => r.data),
      buildGroundingContext(spaceId),
      fetchMessages(spaceId, { limit: 15 }),
    ]);

    const spaceTitle = spaceRow?.title
      ?? spaceId.replace(/^space_/, '').replace(/-/g, ' ');

    let userMessage = trigger.plaintext_command;
    if (trigger.bundled_context) {
      userMessage = `${trigger.bundled_context} ${userMessage}`;
    }

    const groundingPrompt = generateGroundingPrompt(groundingContext);
    const sanitizedMessages = sanitizeForIntelligence(recentMsgs);
    const recentMessages = sanitizedMessages.map(m => ({
      role: m.role,
      content: m.content,
      sender_name: m.sender_name ?? undefined,
    }));

    const result = await orchestrate({
      userMessage,
      groundingPrompt,
      recentMessages,
      spaceId,
      spaceTitle,
    });

    // Handle search results
    if (result.searchResults && result.searchResults.length > 0) {
      const searchBatch = `batch_${crypto.randomUUID().slice(0, 8)}`;
      const queryText = (trigger.plaintext_command ?? '').replace(/@xark\s*/i, '').trim().toLowerCase();
      const searchLabel = queryText || `${spaceTitle} ${result.tool ?? 'general'}`.trim();
      const items = result.searchResults.map(r => ({
        id: `item_${crypto.randomUUID()}`,
        space_id: spaceId,
        title: r.title.toLowerCase(),
        category: result.tool ?? 'general',
        description: r.description ?? '',
        state: 'proposed',
        proposed_by: null,
        agreement_score: 0,
        weighted_score: 0,
        is_locked: false,
        version: 0,
        metadata: {
          price: r.price,
          image_url: r.imageUrl,
          external_url: r.externalUrl,
          source: r.source ?? 'apify',
          search_tier: r.source === 'gemini-local' ? 'gemini-local' : r.source === 'gemini-search' ? 'gemini-search' : 'apify',
          rating: r.rating,
          search_batch: searchBatch,
          search_label: searchLabel,
        },
      }));

      await supabaseAdmin.from('decision_items').upsert(items, { onConflict: 'id' });
    }

    // Garbage check
    if (isGarbageResponse(result.response)) {
      await supabaseAdmin.from('messages').delete().eq('id', xarkMsgId);
      return;
    }

    // Update thinking → final response
    await supabaseAdmin.from('messages').update({
      content: result.response,
    }).eq('id', xarkMsgId);

    // Broadcast @xark response for instant Realtime delivery
    // (E2EE path is async — client doesn't get response in HTTP body)
    try {
      const channel = supabaseAdmin.channel(`chat:${spaceId}`);
      await channel.subscribe();
      await channel.send({
        type: 'broadcast',
        event: 'message',
        payload: {
          id: xarkMsgId,
          space_id: spaceId,
          role: 'xark',
          content: result.response,
          user_id: null,
          sender_name: null,
          created_at: new Date().toISOString(),
          message_type: 'xark',
        },
      });
      supabaseAdmin.removeChannel(channel);
    } catch (broadcastErr) {
      console.warn('[/api/message] broadcast @xark response failed:', broadcastErr);
    }

  } catch (err) {
    const isTimeout = err instanceof Error && err.message.includes('timeout');
    const errorContent = isTimeout ? 'took too long. try again.' : "something glitched. try that again?";
    await supabaseAdmin.from('messages').update({
      content: errorContent,
    }).eq('id', xarkMsgId);

    // Broadcast error response so client isn't left hanging
    try {
      const channel = supabaseAdmin.channel(`chat:${spaceId}`);
      await channel.subscribe();
      await channel.send({
        type: 'broadcast',
        event: 'message',
        payload: {
          id: xarkMsgId,
          space_id: spaceId,
          role: 'xark',
          content: errorContent,
          user_id: null,
          sender_name: null,
          created_at: new Date().toISOString(),
          message_type: 'xark',
        },
      });
      supabaseAdmin.removeChannel(channel);
    } catch {
      // Silent — error message is in DB at least
    }
  }
}
