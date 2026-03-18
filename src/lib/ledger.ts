// XARK OS v2.0 — SETTLEMENT LEDGER
// Calculates financial settlement from locked decision items.
// Logic: Sum the value of all isLocked items per user.
// Calculate the "Debt Delta" between members.
// Deep links to venmo:// and upi:// for settlement.

import { supabase } from "./supabase";
import { extractDisplayName } from "./user-id";

// ── Types ──

export interface LedgerEntry {
  userId: string;
  displayName: string;
  totalPaid: number;
  items: { title: string; amount: number }[];
}

export interface DebtDelta {
  fromUser: string;
  fromName: string;
  toUser: string;
  toName: string;
  amount: number;
}

export interface Settlement {
  entries: LedgerEntry[];
  deltas: DebtDelta[];
  totalSpent: number;
  fairShare: number;
  memberCount: number;
}

// ── Parse price from metadata ──
// Handles: "$450/nt", "$95/person", "$65/person", "Free", "$120"

function parsePrice(metadata: Record<string, string> | null): number {
  if (!metadata?.price) return 0;
  const raw = metadata.price;
  if (raw.toLowerCase() === "free") return 0;
  const match = raw.match(/[\d,.]+/);
  if (!match) return 0;
  return parseFloat(match[0].replace(/,/g, ""));
}

// Display name from userId — uses extractDisplayName from user-id.ts

// ── Fetch Settlement ──
// Queries all locked items for a space, groups by owner, calculates deltas.

export async function fetchSettlement(spaceId: string): Promise<Settlement> {
  const { data, error } = await supabase
    .from("decision_items")
    .select("id, title, ownership, metadata")
    .eq("space_id", spaceId)
    .eq("is_locked", true);

  if (error || !data || data.length === 0) {
    return { entries: [], deltas: [], totalSpent: 0, fairShare: 0, memberCount: 0 };
  }

  // Group by owner
  const ownerMap = new Map<string, LedgerEntry>();

  for (const item of data) {
    const ownerId = (item.ownership as { ownerId?: string })?.ownerId;
    if (!ownerId) continue;

    const amount = parsePrice(item.metadata as Record<string, string> | null);
    if (amount === 0) continue;

    if (!ownerMap.has(ownerId)) {
      ownerMap.set(ownerId, {
        userId: ownerId,
        displayName: extractDisplayName(ownerId),
        totalPaid: 0,
        items: [],
      });
    }

    const entry = ownerMap.get(ownerId)!;
    entry.totalPaid += amount;
    entry.items.push({ title: item.title, amount });
  }

  const entries = Array.from(ownerMap.values());

  // Bug B3 fix: use true space member count from space_members, not just payer count
  const { data: membersData } = await supabase
    .from("space_members")
    .select("user_id")
    .eq("space_id", spaceId);
  const memberCount = (membersData?.length ?? entries.length) || 1;

  const totalSpent = entries.reduce((sum, e) => sum + e.totalPaid, 0);
  const fairShare = totalSpent / memberCount;

  // Calculate debt deltas — who owes whom
  const ahead: LedgerEntry[] = [];
  const behind: LedgerEntry[] = [];

  for (const entry of entries) {
    if (entry.totalPaid > fairShare) {
      ahead.push(entry);
    } else if (entry.totalPaid < fairShare) {
      behind.push(entry);
    }
  }

  // Simple settlement: each behind-person pays each ahead-person proportionally
  const deltas: DebtDelta[] = [];

  for (const debtor of behind) {
    let remaining = fairShare - debtor.totalPaid;

    for (const creditor of ahead) {
      if (remaining <= 0) break;
      const owed = Math.min(remaining, creditor.totalPaid - fairShare);
      if (owed > 0) {
        deltas.push({
          fromUser: debtor.userId,
          fromName: debtor.displayName,
          toUser: creditor.userId,
          toName: creditor.displayName,
          amount: Math.round(owed * 100) / 100,
        });
        remaining -= owed;
      }
    }
  }

  return { entries, deltas, totalSpent, fairShare, memberCount };
}

// ── Payment Deep Links ──
// venmo:// for US users, upi:// for India users.

export function generateVenmoLink(
  recipientName: string,
  amount: number,
  note: string
): string {
  const encodedNote = encodeURIComponent(note);
  return `venmo://paycharge?txn=pay&recipients=${encodeURIComponent(recipientName)}&amount=${amount}&note=${encodedNote}`;
}

export function generateUPILink(
  upiId: string,
  recipientName: string,
  amount: number,
  note: string
): string {
  const encodedName = encodeURIComponent(recipientName);
  const encodedNote = encodeURIComponent(note);
  return `upi://pay?pa=${encodeURIComponent(upiId)}&pn=${encodedName}&am=${amount}&tn=${encodedNote}&cu=INR`;
}
