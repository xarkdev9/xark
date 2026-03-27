// XARK OS v2.0 — Interactive System Pill for space_ledger events
// Structure: icon → actor → verb → [tappable payload] → undo

"use client";

import { colors, ink, text } from "@/lib/theme";

const ACTION_CONFIG: Record<string, { icon: string; verb: string }> = {
  update_dates: { icon: "\uD83D\uDCC5", verb: "updated dates to" },
  rename_space: { icon: "\u270F\uFE0F", verb: "renamed space to" },
  revert_update_dates: { icon: "\u21A9\uFE0F", verb: "reverted dates to" },
  revert_rename_space: { icon: "\u21A9\uFE0F", verb: "reverted name to" },
};

export interface LedgerEvent {
  id: string;
  actorName: string;
  action: string;
  payload: Record<string, unknown>;
  previous: Record<string, unknown>;
  revertTargetId?: string;
  timestamp: number;
}

interface LedgerPillProps {
  event: LedgerEvent;
  onUndo?: (ledgerId: string, action: string, previous: Record<string, unknown>) => void;
}

function formatPayload(action: string, payload: Record<string, unknown>): string {
  if (action === "update_dates" || action === "revert_update_dates") {
    return `${payload.start_date ?? ""} \u2013 ${payload.end_date ?? ""}`;
  }
  if (action === "rename_space" || action === "revert_rename_space") {
    return String(payload.new_title ?? payload.old_title ?? "");
  }
  return JSON.stringify(payload);
}

export function LedgerPill({ event, onUndo }: LedgerPillProps) {
  const config = ACTION_CONFIG[event.action] ?? { icon: "\u2699\uFE0F", verb: event.action };
  const payloadText = formatPayload(event.action, event.payload);
  const isRevert = event.action.startsWith("revert_");

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        gap: "6px",
        padding: "8px 0",
      }}
    >
      <span style={{ ...text.timestamp, color: ink.tertiary }}>
        {config.icon} {event.actorName} {config.verb}
      </span>
      <span
        style={{
          ...text.timestamp,
          color: colors.cyan,
          cursor: "pointer",
        }}
      >
        [{payloadText}]
      </span>
      {!isRevert && onUndo && (
        <>
          <span style={{ ...text.timestamp, color: ink.tertiary }}>&middot;</span>
          <span
            role="button"
            tabIndex={0}
            onClick={() => onUndo(event.id, event.action, event.previous)}
            onKeyDown={(e) => { if (e.key === "Enter") onUndo(event.id, event.action, event.previous); }}
            style={{
              ...text.timestamp,
              color: ink.tertiary,
              cursor: "pointer",
            }}
            className="outline-none"
          >
            undo
          </span>
        </>
      )}
    </div>
  );
}
