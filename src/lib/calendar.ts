// XARK OS v2.0 — Calendar Integration (Layers 1 & 2)
// Spec: docs/superpowers/specs/2026-03-13-xark-capabilities-design.md (Section 2)
// Pure functions. No DB calls. No side effects.

export interface LockedItemWithDates {
  id: string;
  title: string;
  metadata?: {
    date?: string;
    check_in?: string;
    check_out?: string;
  };
}

// ── Date formatting ──

export function formatICSDate(dateStr: string): string {
  // Take YYYY-MM-DD part, strip hyphens → YYYYMMDD
  return dateStr.slice(0, 10).replace(/-/g, "");
}

function fmtGoogle(dateStr: string): string {
  return formatICSDate(dateStr);
}

function enc(s: string): string {
  return encodeURIComponent(s);
}

// ── Layer 1: .ics Export ──
// Uses VALUE=DATE (all-day events) — no VTIMEZONE needed (intentional)

export function generateICS(
  items: LockedItemWithDates[],
  spaceTitle: string,
  tripDates?: { start_date: string; end_date: string }
): string {
  const events = items
    .map((item) => {
      const start =
        item.metadata?.check_in || item.metadata?.date || tripDates?.start_date;
      const end =
        item.metadata?.check_out || item.metadata?.date || tripDates?.end_date;
      if (!start) return null;
      return [
        "BEGIN:VEVENT",
        `DTSTART;VALUE=DATE:${formatICSDate(start)}`,
        `DTEND;VALUE=DATE:${formatICSDate(end || start)}`,
        `SUMMARY:${item.title}`,
        `DESCRIPTION:${spaceTitle} — locked via xark`,
        `UID:${item.id}@xark.app`,
        "END:VEVENT",
      ].join("\r\n");
    })
    .filter(Boolean);

  return [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//xark//xark-os//EN",
    ...events,
    "END:VCALENDAR",
  ].join("\r\n");
}

// ── Layer 2: Deep Links ──

export function calendarDeepLink(
  title: string,
  startDate: string,
  endDate: string,
  description: string
): { google: string; outlook: string } {
  const googleUrl = `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${enc(title)}&dates=${fmtGoogle(startDate)}/${fmtGoogle(endDate)}&details=${enc(description)}`;
  const outlookUrl = `https://outlook.live.com/calendar/0/action/compose?subject=${enc(title)}&startdt=${startDate}&enddt=${endDate}&body=${enc(description)}`;
  return { google: googleUrl, outlook: outlookUrl };
}
