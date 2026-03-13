// src/lib/__tests__/calendar.test.ts
import { describe, it, expect } from "vitest";
import { generateICS, calendarDeepLink, formatICSDate } from "../calendar";

describe("formatICSDate", () => {
  it("formats YYYY-MM-DD to YYYYMMDD", () => {
    expect(formatICSDate("2026-03-10")).toBe("20260310");
  });

  it("handles date with time by taking date part", () => {
    expect(formatICSDate("2026-03-10T14:00:00Z")).toBe("20260310");
  });
});

describe("generateICS", () => {
  it("generates valid iCalendar with one event", () => {
    const items = [
      {
        id: "item_1",
        title: "Hotel Del Coronado",
        metadata: { check_in: "2026-03-10", check_out: "2026-03-15" },
      },
    ];
    const result = generateICS(items, "san diego trip");

    expect(result).toContain("BEGIN:VCALENDAR");
    expect(result).toContain("VERSION:2.0");
    expect(result).toContain("PRODID:-//xark//xark-os//EN");
    expect(result).toContain("BEGIN:VEVENT");
    expect(result).toContain("DTSTART;VALUE=DATE:20260310");
    expect(result).toContain("DTEND;VALUE=DATE:20260315");
    expect(result).toContain("SUMMARY:Hotel Del Coronado");
    expect(result).toContain("DESCRIPTION:san diego trip");
    expect(result).toContain("UID:item_1@xark.app");
    expect(result).toContain("END:VEVENT");
    expect(result).toContain("END:VCALENDAR");
  });

  it("falls back to tripDates when item has no dates", () => {
    const items = [{ id: "item_2", title: "Surf Lessons", metadata: {} }];
    const result = generateICS(items, "san diego", {
      start_date: "2026-03-10",
      end_date: "2026-03-15",
    });

    expect(result).toContain("DTSTART;VALUE=DATE:20260310");
    expect(result).toContain("DTEND;VALUE=DATE:20260315");
  });

  it("skips items with no dates and no tripDates fallback", () => {
    const items = [{ id: "item_3", title: "No dates", metadata: {} }];
    const result = generateICS(items, "test");

    expect(result).not.toContain("BEGIN:VEVENT");
  });

  it("uses \\r\\n line endings (RFC 5545)", () => {
    const items = [
      { id: "item_4", title: "Test", metadata: { date: "2026-03-10" } },
    ];
    const result = generateICS(items, "test");

    expect(result).toContain("\r\n");
  });
});

describe("calendarDeepLink", () => {
  it("generates Google Calendar link", () => {
    const { google } = calendarDeepLink(
      "Hotel Del",
      "2026-03-10",
      "2026-03-15",
      "san diego trip"
    );

    expect(google).toContain("calendar.google.com/calendar/render");
    expect(google).toContain("action=TEMPLATE");
    expect(google).toContain("Hotel%20Del");
    expect(google).toContain("20260310");
    expect(google).toContain("20260315");
  });

  it("generates Outlook link", () => {
    const { outlook } = calendarDeepLink(
      "Hotel Del",
      "2026-03-10",
      "2026-03-15",
      "san diego trip"
    );

    expect(outlook).toContain("outlook.live.com/calendar");
    expect(outlook).toContain("subject=Hotel%20Del");
    expect(outlook).toContain("startdt=2026-03-10");
  });
});
