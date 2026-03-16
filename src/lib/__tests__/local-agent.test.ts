import { describe, it, expect } from "vitest";
import { tryLocalAgent } from "../local-agent";
import type { LocalContext } from "../local-agent";

const mockContext: LocalContext = {
  spaceId: "space_test",
  userId: "name_ram",
  userName: "ram",
  spaceItems: [],
  setView: () => {},
  supabaseToken: "mock-token",
};

describe("tryLocalAgent", () => {
  it("returns null for non-@xark messages", () => {
    const result = tryLocalAgent("hello everyone", mockContext);
    expect(result).toBeNull();
  });

  it("returns null for unrecognized @xark commands", () => {
    const result = tryLocalAgent("@xark find me flights to miami", mockContext);
    expect(result).toBeNull();
  });

  it("handles navigation: show decide", () => {
    let viewSet = "";
    const ctx = { ...mockContext, setView: (v: string) => { viewSet = v; } };
    const result = tryLocalAgent("@xark show decide", ctx as unknown as LocalContext);
    expect(result).not.toBeNull();
    expect(result!.handled).toBe(true);
    expect(result!.whisper).toContain("decide");
    result!.uiAction?.();
    expect(viewSet).toBe("decide");
  });

  it("handles navigation: go to itinerary", () => {
    let viewSet = "";
    const ctx = { ...mockContext, setView: (v: string) => { viewSet = v; } };
    const result = tryLocalAgent("@xark go to itinerary", ctx as unknown as LocalContext);
    expect(result).not.toBeNull();
    result!.uiAction?.();
    expect(viewSet).toBe("itinerary");
  });

  it("handles navigation: switch to memories", () => {
    let viewSet = "";
    const ctx = { ...mockContext, setView: (v: string) => { viewSet = v; } };
    const result = tryLocalAgent("@xark switch to memories", ctx as unknown as LocalContext);
    expect(result).not.toBeNull();
    result!.uiAction?.();
    expect(viewSet).toBe("memories");
  });
});

describe("date commands", () => {
  it("matches 'set dates to june 1-5'", () => {
    const result = tryLocalAgent("@xark set dates to june 1-5", mockContext);
    expect(result).not.toBeNull();
    expect(result!.handled).toBe(true);
    expect(result!.ledgerEntry).toBeDefined();
    expect(result!.ledgerEntry!.action).toBe("update_dates");
    expect(result!.ledgerEntry!.payload).toHaveProperty("start_date");
    expect(result!.ledgerEntry!.payload).toHaveProperty("end_date");
  });

  it("matches 'change dates to march 20-25'", () => {
    const result = tryLocalAgent("@xark change dates to march 20-25", mockContext);
    expect(result).not.toBeNull();
    expect(result!.ledgerEntry!.action).toBe("update_dates");
  });

  it("matches 'update trip dates to december 10-15'", () => {
    const result = tryLocalAgent("@xark update trip dates to december 10-15", mockContext);
    expect(result).not.toBeNull();
    expect(result!.ledgerEntry!.action).toBe("update_dates");
  });

  it("does NOT match vague date requests", () => {
    const result = tryLocalAgent("@xark push the dates back a few weeks because nina got delayed", mockContext);
    expect(result).toBeNull();
  });
});

describe("rename commands", () => {
  it("matches 'rename space to Miami 2026'", () => {
    const result = tryLocalAgent("@xark rename space to Miami 2026", mockContext);
    expect(result).not.toBeNull();
    expect(result!.ledgerEntry!.action).toBe("rename_space");
    expect(result!.ledgerEntry!.payload).toEqual({ new_title: "Miami 2026" });
  });

  it("matches 'rename this to Summer Trip'", () => {
    const result = tryLocalAgent("@xark rename this to Summer Trip", mockContext);
    expect(result).not.toBeNull();
    expect(result!.ledgerEntry!.payload).toEqual({ new_title: "Summer Trip" });
  });

  it("matches 'rename group to Beach Weekend'", () => {
    const result = tryLocalAgent("@xark rename group to Beach Weekend", mockContext);
    expect(result).not.toBeNull();
  });
});

describe("state query commands", () => {
  const ctxWithItems: LocalContext = {
    ...mockContext,
    spaceItems: [
      { state: "proposed", is_locked: false, category: "hotel", metadata: {} },
      { state: "ranked", is_locked: false, category: "restaurant", metadata: {} },
      { state: "locked", is_locked: true, category: "activity", metadata: {} },
    ],
  };

  it("matches 'what's the status'", () => {
    const result = tryLocalAgent("@xark what's the status", ctxWithItems);
    expect(result).not.toBeNull();
    expect(result!.handled).toBe(true);
    expect(result!.whisper).toContain("3 items");
  });

  it("matches 'status'", () => {
    const result = tryLocalAgent("@xark status", ctxWithItems);
    expect(result).not.toBeNull();
  });

  it("reports empty state", () => {
    const result = tryLocalAgent("@xark status", mockContext);
    expect(result!.whisper).toContain("wide open");
  });

  it("matches 'who hasn't voted'", () => {
    const result = tryLocalAgent("@xark who hasn't voted", ctxWithItems);
    expect(result).not.toBeNull();
    expect(result!.whisper).toContain("2 items");
  });
});
