"use client";

interface TravelBlockProps {
  durationMinutes: number;
  mode: "drive" | "walk" | "transit";
  fromLocation: string;
  toLocation: string;
  mapsUrl: string;
  note?: string;
}

const MODE_ICONS: Record<string, React.ReactNode> = {
  drive: (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <path d="M5 17h14M5 17a2 2 0 01-2-2V9a2 2 0 012-2h14a2 2 0 012 2v6a2 2 0 01-2 2M5 17l-1 2m16-2l1 2M7.5 14h.01M16.5 14h.01M8 7l1-4h6l1 4" />
    </svg>
  ),
  walk: (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <circle cx="12" cy="5" r="2" /><path d="M10 22l3-9m0 0l-2-4 4-3m-2 7l4 3" />
    </svg>
  ),
  transit: (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <rect x="4" y="3" width="16" height="14" rx="2" /><path d="M4 10h16M8 21l2-4m4 4l2-4M9 14h.01M15 14h.01" />
    </svg>
  ),
};

export function TravelBlock({ durationMinutes, mode, fromLocation, toLocation, mapsUrl, note }: TravelBlockProps) {
  const hrs = Math.floor(durationMinutes / 60);
  const mins = durationMinutes % 60;
  const durationText = hrs > 0 ? `${hrs}h ${mins}m` : `${mins}m`;

  return (
    <a
      href={mapsUrl}
      target="_blank"
      rel="noopener noreferrer"
      style={{
        display: "flex",
        alignItems: "center",
        gap: 8,
        padding: "8px 12px",
        margin: "4px 0 4px 24px",
        borderRadius: 8,
        background: "var(--hello-surface-recessed)",
        color: "var(--hello-ink-tertiary)",
        fontSize: 11,
        fontWeight: 300,
        textDecoration: "none",
        transition: "opacity 0.15s ease",
        cursor: "pointer",
        borderLeft: "2px dashed var(--hello-ink-tertiary)",
      }}
    >
      {/* Mode icon */}
      <span style={{ opacity: 0.6, flexShrink: 0 }}>
        {MODE_ICONS[mode] || MODE_ICONS.drive}
      </span>

      {/* Duration + note */}
      <span>
        {durationText} {mode}
        {note ? ` — ${note}` : ""}
      </span>

      {/* Maps arrow */}
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" style={{ marginLeft: "auto", opacity: 0.4 }}>
        <path d="M7 17L17 7M17 7H7M17 7v10" />
      </svg>
    </a>
  );
}
