// XARK OS v2.0 — Actionable Context Card for Tier 2 Recall
// Slides up above ChatInput. Jump to Message + Quote to Group.

"use client";

import { colors, ink, text } from "@/lib/theme";

interface ContextCardProps {
  content: string;
  senderName: string;
  timestamp: number;
  onJump: () => void;
  onQuote: (content: string, senderName: string) => void;
  onDismiss: () => void;
}

function formatRelativeTime(ts: number): string {
  const diff = Date.now() - ts;
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

export function ContextCard({
  content,
  senderName,
  timestamp,
  onJump,
  onQuote,
  onDismiss,
}: ContextCardProps) {
  const displayContent = content.length > 120 ? content.slice(0, 117) + "..." : content;

  return (
    <div
      style={{
        padding: "10px 14px",
        background: "rgba(var(--xark-accent-rgb), 0.06)",
        borderRadius: "8px",
        marginBottom: "8px",
      }}
    >
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "4px" }}>
        <span style={{ ...text.timestamp, color: ink.secondary }}>
          {senderName} &middot; {formatRelativeTime(timestamp)}
        </span>
        <span
          role="button"
          tabIndex={0}
          onClick={onDismiss}
          onKeyDown={(e) => { if (e.key === "Enter") onDismiss(); }}
          style={{ ...text.timestamp, color: ink.tertiary, cursor: "pointer" }}
          className="outline-none"
        >
          &times;
        </span>
      </div>

      <p style={{ ...text.hint, color: ink.primary, marginBottom: "8px" }}>
        {displayContent}
      </p>

      <div style={{ display: "flex", gap: "16px" }}>
        <span
          role="button"
          tabIndex={0}
          onClick={onJump}
          onKeyDown={(e) => { if (e.key === "Enter") onJump(); }}
          style={{ ...text.timestamp, color: colors.cyan, cursor: "pointer" }}
          className="outline-none"
        >
          jump to message
        </span>
        <span
          role="button"
          tabIndex={0}
          onClick={() => onQuote(content, senderName)}
          onKeyDown={(e) => { if (e.key === "Enter") onQuote(content, senderName); }}
          style={{ ...text.timestamp, color: colors.cyan, cursor: "pointer" }}
          className="outline-none"
        >
          quote to group
        </span>
      </div>
    </div>
  );
}
