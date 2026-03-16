import { describe, it, expect } from "vitest";
import { isRecallQuestion, getRecallWhisper } from "../local-recall";

describe("isRecallQuestion", () => {
  it("detects 'what was that sushi place'", () => {
    expect(isRecallQuestion("@xark what was that sushi place")).toBe(true);
  });

  it("detects 'who said we should go hiking'", () => {
    expect(isRecallQuestion("@xark who said we should go hiking")).toBe(true);
  });

  it("detects 'what did nina link'", () => {
    expect(isRecallQuestion("@xark what did nina link")).toBe(true);
  });

  it("detects 'find the message about hotels'", () => {
    expect(isRecallQuestion("@xark find the message about hotels")).toBe(true);
  });

  it("detects 'who mentioned the rooftop bar'", () => {
    expect(isRecallQuestion("@xark who mentioned the rooftop bar")).toBe(true);
  });

  it("rejects 'find me flights to miami' (Tier 3 search)", () => {
    expect(isRecallQuestion("@xark find me flights to miami")).toBe(false);
  });

  it("rejects 'search for hotels in Miami' (Tier 3 search)", () => {
    expect(isRecallQuestion("@xark search for hotels in Miami")).toBe(false);
  });

  it("rejects 'look up flight prices' (Tier 3 search)", () => {
    expect(isRecallQuestion("@xark look up flight prices")).toBe(false);
  });

  it("rejects 'set dates to june 1-5' (Tier 1 command)", () => {
    expect(isRecallQuestion("@xark set dates to june 1-5")).toBe(false);
  });

  it("rejects plain chat messages", () => {
    expect(isRecallQuestion("hey everyone what time is dinner")).toBe(false);
  });
});

describe("getRecallWhisper", () => {
  it("returns keyword hint for low-tier devices", () => {
    expect(getRecallWhisper("low")).toContain("keyword-only");
  });

  it("returns generic message for high-tier devices", () => {
    expect(getRecallWhisper("high")).toContain("recent chat history");
  });
});
