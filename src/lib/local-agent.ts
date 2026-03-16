// XARK OS v2.0 — Tier 1: Fast-Path Local Router
// Deterministic regex matching for admin commands + state queries.
// <1ms, zero AI, zero network. First gate in sendMessage().

import type { SpaceStateItem } from "./space-state";

type ViewMode = "discuss" | "decide" | "itinerary" | "memories";

export interface LocalContext {
  spaceId: string;
  userId: string;
  userName: string;
  spaceItems: SpaceStateItem[];
  setView: (view: ViewMode) => void;
  supabaseToken: string | null;
}

export interface LedgerEntry {
  space_id: string;
  actor_id: string;
  actor_name: string;
  action: string;
  payload: Record<string, unknown>;
  previous: Record<string, unknown>;
  revert_target_id?: string;
}

export interface LocalResult {
  handled: true;
  ledgerEntry?: LedgerEntry;
  uiAction?: () => void;
  whisper?: string;
}

interface LocalCommand {
  pattern: RegExp;
  execute: (match: RegExpMatchArray, context: LocalContext) => LocalResult | null;
}

// ── Simple date parsing — handles "june 1-5", "march 20 to march 25", "dec 12-15" ──
const MONTH_MAP: Record<string, number> = {
  jan: 0, january: 0, feb: 1, february: 1, mar: 2, march: 2,
  apr: 3, april: 3, may: 4, jun: 5, june: 5,
  jul: 6, july: 6, aug: 7, august: 7, sep: 8, september: 8,
  oct: 9, october: 9, nov: 10, november: 10, dec: 11, december: 11,
};

function parseSimpleDateRange(text: string): { start_date: string; end_date: string } | null {
  // Pattern: "month day-day" (e.g., "june 1-5")
  const singleMonth = text.match(/(\w+)\s+(\d{1,2})\s*[-–to]+\s*(\d{1,2})/i);
  if (singleMonth) {
    const month = MONTH_MAP[singleMonth[1].toLowerCase()];
    if (month !== undefined) {
      const year = new Date().getFullYear();
      const start = new Date(year, month, parseInt(singleMonth[2]));
      const end = new Date(year, month, parseInt(singleMonth[3]));
      if (end < new Date()) {
        start.setFullYear(year + 1);
        end.setFullYear(year + 1);
      }
      return {
        start_date: start.toISOString().split("T")[0],
        end_date: end.toISOString().split("T")[0],
      };
    }
  }

  // Pattern: "month day to month day" (e.g., "march 20 to march 25")
  const twoMonth = text.match(/(\w+)\s+(\d{1,2})\s+to\s+(\w+)\s+(\d{1,2})/i);
  if (twoMonth) {
    const m1 = MONTH_MAP[twoMonth[1].toLowerCase()];
    const m2 = MONTH_MAP[twoMonth[3].toLowerCase()];
    if (m1 !== undefined && m2 !== undefined) {
      const year = new Date().getFullYear();
      const start = new Date(year, m1, parseInt(twoMonth[2]));
      const end = new Date(year, m2, parseInt(twoMonth[4]));
      if (end < new Date()) {
        start.setFullYear(year + 1);
        end.setFullYear(year + 1);
      }
      return {
        start_date: start.toISOString().split("T")[0],
        end_date: end.toISOString().split("T")[0],
      };
    }
  }

  return null;
}

// ── Navigation commands — pure UI, no DB ──
const NAVIGATION_COMMANDS: LocalCommand[] = [
  {
    pattern: /@xark\s+(?:show|go\s+to|switch\s+to|open)\s+(discuss|decide|itinerary|memories)/i,
    execute: (match, ctx) => {
      const target = match[1].toLowerCase() as ViewMode;
      return {
        handled: true,
        uiAction: () => ctx.setView(target),
        whisper: `switched to ${target}`,
      };
    },
  },
];

// ── Date commands — mutate via /api/local-action ──
const DATE_COMMANDS: LocalCommand[] = [
  {
    pattern: /@xark\s+(?:set|change|update|modify)\s+(?:trip\s+)?dates?\s+to\s+(.+)/i,
    execute: (match, ctx) => {
      const dateText = match[1].trim();
      const parsed = parseSimpleDateRange(dateText);
      if (!parsed) return null; // Can't parse — fall through to Tier 3

      return {
        handled: true,
        ledgerEntry: {
          space_id: ctx.spaceId,
          actor_id: ctx.userId,
          actor_name: ctx.userName,
          action: "update_dates",
          payload: { start_date: parsed.start_date, end_date: parsed.end_date },
          previous: {},
        },
        whisper: `dates set to ${dateText}`,
      };
    },
  },
];

// ── Rename commands ──
const RENAME_COMMANDS: LocalCommand[] = [
  {
    pattern: /@xark\s+rename\s+(?:space|this|it|group)\s+to\s+(.+)/i,
    execute: (match, ctx) => {
      const newTitle = match[1].trim();
      if (!newTitle || newTitle.length > 100) return null;

      return {
        handled: true,
        ledgerEntry: {
          space_id: ctx.spaceId,
          actor_id: ctx.userId,
          actor_name: ctx.userName,
          action: "rename_space",
          payload: { new_title: newTitle },
          previous: {},
        },
        whisper: `renamed to "${newTitle}"`,
      };
    },
  },
];

// ── State query commands ──
const STATE_QUERY_COMMANDS: LocalCommand[] = [
  {
    pattern: /@xark\s+(?:what(?:'s| is) the )?status/i,
    execute: (_match, ctx) => {
      const total = ctx.spaceItems.length;
      const locked = ctx.spaceItems.filter((i) => i.is_locked).length;
      const proposed = total - locked;

      let summary: string;
      if (total === 0) {
        summary = "nothing here yet. wide open.";
      } else if (locked === total) {
        summary = `all ${total} items locked. ready to go.`;
      } else {
        summary = `${total} items total. ${locked} locked, ${proposed} still open.`;
      }

      return { handled: true, whisper: summary };
    },
  },
  {
    pattern: /@xark\s+who\s+hasn(?:'t|t)\s+voted/i,
    execute: (_match, ctx) => {
      const openItems = ctx.spaceItems.filter((i) => !i.is_locked).length;
      return {
        handled: true,
        whisper: openItems > 0
          ? `${openItems} items still need votes.`
          : "everything has been voted on.",
      };
    },
  },
];

// ── All command registries (order matters — first match wins) ──
const ALL_COMMANDS: LocalCommand[] = [
  ...NAVIGATION_COMMANDS,
  ...DATE_COMMANDS,
  ...RENAME_COMMANDS,
  ...STATE_QUERY_COMMANDS,
];

/**
 * Try to handle an @xark message locally.
 * Returns LocalResult if handled, null if not (falls through to Tier 2/3).
 */
export function tryLocalAgent(
  text: string,
  context: LocalContext
): LocalResult | null {
  if (!text.toLowerCase().includes("@xark")) return null;

  for (const cmd of ALL_COMMANDS) {
    const match = text.match(cmd.pattern);
    if (match) {
      return cmd.execute(match, context);
    }
  }

  return null;
}
