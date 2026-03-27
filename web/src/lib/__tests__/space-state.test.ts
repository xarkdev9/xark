// src/lib/__tests__/space-state.test.ts
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { computeGroupState } from "../space-state";
import type { GroupStateItem } from "../space-state";

describe("computeGroupState", () => {
  it("returns empty for no items", () => {
    expect(computeGroupState([])).toBe("empty");
  });

  it("returns exploring for proposed items", () => {
    const items: GroupStateItem[] = [
      { state: "proposed", is_locked: false },
    ];
    expect(computeGroupState(items)).toBe("exploring");
  });

  it("returns converging when some locked, some open", () => {
    const items: GroupStateItem[] = [
      { state: "locked", is_locked: true },
      { state: "proposed", is_locked: false },
    ];
    expect(computeGroupState(items)).toBe("converging");
  });

  it("returns ready when all locked", () => {
    const items: GroupStateItem[] = [
      { state: "locked", is_locked: true },
    ];
    expect(computeGroupState(items)).toBe("ready");
  });

  describe("with tripDates parameter", () => {
    let realDate: typeof Date;

    beforeEach(() => {
      realDate = globalThis.Date;
    });

    afterEach(() => {
      globalThis.Date = realDate;
    });

    it("returns settled when tripDates end_date is in the past", () => {
      const items: GroupStateItem[] = [
        { state: "purchased", is_locked: true },
      ];
      // No metadata dates on items — uses tripDates instead
      const result = computeGroupState(items, {
        start_date: "2020-01-01",
        end_date: "2020-01-05",
      });
      expect(result).toBe("settled");
    });

    it("returns active when tripDates span includes now", () => {
      const now = new Date();
      const yesterday = new Date(now.getTime() - 86_400_000).toISOString().slice(0, 10);
      const tomorrow = new Date(now.getTime() + 86_400_000).toISOString().slice(0, 10);

      const items: GroupStateItem[] = [
        { state: "locked", is_locked: true },
      ];
      const result = computeGroupState(items, {
        start_date: yesterday,
        end_date: tomorrow,
      });
      expect(result).toBe("active");
    });

    it("ignores tripDates when items have their own metadata dates", () => {
      const items: GroupStateItem[] = [
        {
          state: "purchased",
          is_locked: true,
          metadata: { check_out: "2099-12-31" }, // far future
        },
      ];
      // tripDates says past, but items have their own dates — item dates win
      const result = computeGroupState(items, {
        start_date: "2020-01-01",
        end_date: "2020-01-05",
      });
      // Item has check_out in 2099 (future), so not settled despite tripDates being past
      expect(result).toBe("ready");
    });
  });
});
