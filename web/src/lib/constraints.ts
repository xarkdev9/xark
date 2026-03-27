// XARK OS v2.0 — On-Device Constraint Detection
// Bridges Layer 2 (encrypted messages) → Layer 3 (structured data).
// Runs on sender's device only. Conservative allowlists, no open regex.

import { supabase } from './supabase';
import type { DetectedConstraint } from './crypto/types';

// ── Allowlists (hardcoded, conservative) ──

const DIETARY_TRIGGERS: Record<string, string[]> = {
  'vegan':        ["i'm vegan", 'i am vegan', 'i eat vegan'],
  'vegetarian':   ["i'm vegetarian", 'i am vegetarian'],
  'halal':        ['i eat halal', 'halal only', 'i need halal'],
  'kosher':       ['i keep kosher', 'kosher only'],
  'no_shellfish': ['allergic to shellfish', 'shellfish allergy'],
  'no_peanuts':   ['allergic to peanuts', 'peanut allergy', 'nut allergy'],
  'no_dairy':     ['allergic to dairy', 'dairy free', 'lactose intolerant'],
  'no_gluten':    ['gluten free', 'celiac', 'allergic to gluten'],
};

const BUDGET_PATTERN = /budget\s+(?:is\s+)?(?:around|under|max|of|about)?\s*\$?(\d+)/i;
const ACCESSIBILITY = ['wheelchair', 'accessible', 'mobility aid'];
const ALCOHOL = ["i don't drink", 'i am sober', 'no alcohol', "i'm sober"];

/** Detect constraints from decrypted message text. Sender's device only. */
export function detectConstraints(text: string): DetectedConstraint | null {
  const lower = text.toLowerCase();

  // Dietary (first match wins)
  for (const [value, triggers] of Object.entries(DIETARY_TRIGGERS)) {
    if (triggers.some(t => lower.includes(t))) {
      return { type: 'dietary', value, scope: 'global' };
    }
  }

  // Budget (space-specific)
  const budgetMatch = lower.match(BUDGET_PATTERN);
  if (budgetMatch) {
    return { type: 'budget', value: `$${budgetMatch[1]}`, scope: 'space' };
  }

  // Accessibility
  if (ACCESSIBILITY.some(t => lower.includes(t))) {
    return { type: 'accessibility', value: 'wheelchair', scope: 'global' };
  }

  // Alcohol
  if (ALCOHOL.some(t => lower.includes(t))) {
    return { type: 'alcohol', value: 'no_alcohol', scope: 'global' };
  }

  return null;
}

/** Save a detected constraint to the database */
export async function saveConstraint(
  constraint: DetectedConstraint,
  userId: string,
  spaceId?: string
): Promise<void> {
  if (constraint.scope === 'global') {
    await supabase.from('user_constraints').upsert(
      {
        id: `uc_${crypto.randomUUID()}`,
        user_id: userId,
        type: constraint.type,
        value: constraint.value,
      },
      { onConflict: 'user_id,type,value' }
    );
  } else if (spaceId) {
    await supabase.from('space_constraints').upsert(
      {
        id: `sc_${crypto.randomUUID()}`,
        space_id: spaceId,
        user_id: userId,
        type: constraint.type,
        value: constraint.value,
      },
      { onConflict: 'space_id,user_id,type' }
    );
  }
}

/** Record constraint prompt dismissal (cross-device sync) */
export async function dismissConstraintPrompt(
  messageId: string,
  userId: string
): Promise<void> {
  await supabase.from('constraint_prompts').upsert({
    message_id: messageId,
    user_id: userId,
    action: 'dismissed',
  });
}

/** Record constraint prompt acceptance */
export async function acceptConstraintPrompt(
  messageId: string,
  userId: string
): Promise<void> {
  await supabase.from('constraint_prompts').upsert({
    message_id: messageId,
    user_id: userId,
    action: 'accepted',
  });
}

/** Check if a prompt has already been acted on (cross-device dedup) */
export async function getPromptAction(
  messageId: string,
  userId: string
): Promise<'accepted' | 'dismissed' | null> {
  const { data } = await supabase
    .from('constraint_prompts')
    .select('action')
    .eq('message_id', messageId)
    .eq('user_id', userId)
    .single();

  return (data?.action as 'accepted' | 'dismissed') ?? null;
}

/** Fetch all user constraints for grounding context */
export async function fetchUserConstraints(
  userId: string
): Promise<Array<{ type: string; value: string }>> {
  const { data } = await supabase
    .from('user_constraints')
    .select('type, value')
    .eq('user_id', userId);

  return data ?? [];
}

/** Fetch space constraints for grounding context */
export async function fetchSpaceConstraints(
  spaceId: string
): Promise<Array<{ userId: string; type: string; value: string }>> {
  const { data } = await supabase
    .from('space_constraints')
    .select('user_id, type, value')
    .eq('space_id', spaceId);

  return (data ?? []).map(d => ({
    userId: d.user_id,
    type: d.type,
    value: d.value,
  }));
}
