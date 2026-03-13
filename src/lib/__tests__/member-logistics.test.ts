// src/lib/__tests__/member-logistics.test.ts
import { describe, it, expect, vi, beforeEach } from "vitest";
import { resolveOrigin, buildLogisticsSkeletonRows } from "../member-logistics";

describe("resolveOrigin", () => {
  it("prefers trip override over all others", () => {
    const result = resolveOrigin("LAX", "JFK", "SFO");
    expect(result).toEqual({ origin: "LAX", source: "chat" });
  });

  it("prefers creator context over profile", () => {
    const result = resolveOrigin(null, "JFK", "SFO");
    expect(result).toEqual({ origin: "JFK", source: "creator" });
  });

  it("falls back to profile default", () => {
    const result = resolveOrigin(null, null, "SFO");
    expect(result).toEqual({ origin: "SFO", source: "profile" });
  });

  it("returns null when all sources empty", () => {
    const result = resolveOrigin(null, null, null);
    expect(result).toEqual({ origin: null, source: "missing" });
  });
});

describe("buildLogisticsSkeletonRows", () => {
  it("creates outbound and return rows", () => {
    const rows = buildLogisticsSkeletonRows("space_1", "user_1", "SFO", "SAN");
    expect(rows).toHaveLength(2);

    const outbound = rows.find((r) => r.category === "flight_outbound");
    expect(outbound?.origin).toBe("SFO");
    expect(outbound?.destination).toBe("SAN");
    expect(outbound?.state).toBe("missing");
    expect(outbound?.source).toBe("profile");
    expect(outbound?.confidence).toBe(1.0);

    const ret = rows.find((r) => r.category === "flight_return");
    expect(ret?.origin).toBe("SAN");
    expect(ret?.destination).toBe("SFO");
  });

  it("handles null home_city", () => {
    const rows = buildLogisticsSkeletonRows("space_1", "user_1", null, "SAN");
    const outbound = rows.find((r) => r.category === "flight_outbound");
    expect(outbound?.origin).toBeNull();
    expect(outbound?.source).toBeNull();
    expect(outbound?.confidence).toBeNull();
  });

  it("handles null destination", () => {
    const rows = buildLogisticsSkeletonRows("space_1", "user_1", "SFO", null);
    const outbound = rows.find((r) => r.category === "flight_outbound");
    expect(outbound?.origin).toBe("SFO");
    expect(outbound?.destination).toBeNull();
  });
});
