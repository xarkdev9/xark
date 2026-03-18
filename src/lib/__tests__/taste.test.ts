import { describe, it, expect } from "vitest";
import { intersectTasteProfiles, buildTastePromptInjection } from "../taste";

describe("intersectTasteProfiles", () => {
  it("unions hard constraints across all members", () => {
    const profiles = [
      { user_id: "a", hard_constraints: ["vegan"], implicit_weights: {}, onboarded: true },
      { user_id: "b", hard_constraints: ["no_chains", "gluten_free"], implicit_weights: {}, onboarded: true },
    ];
    const ctx = intersectTasteProfiles(profiles);
    expect(ctx.hardConstraints).toContain("vegan");
    expect(ctx.hardConstraints).toContain("no_chains");
    expect(ctx.hardConstraints).toContain("gluten_free");
    expect(ctx.hardConstraints).toHaveLength(3);
  });

  it("sums implicit weights across members", () => {
    const profiles = [
      { user_id: "a", hard_constraints: [], implicit_weights: { japanese: 5, italian: -3 }, onboarded: true },
      { user_id: "b", hard_constraints: [], implicit_weights: { japanese: 5, mexican: 1 }, onboarded: true },
    ];
    const ctx = intersectTasteProfiles(profiles);
    expect(ctx.softPreferences).toContain("japanese");
  });

  it("handles empty profiles gracefully", () => {
    const ctx = intersectTasteProfiles([]);
    expect(ctx.hardConstraints).toEqual([]);
    expect(ctx.softPreferences).toBe("");
    expect(ctx.memberCount).toBe(0);
  });

  it("counts onboarded members", () => {
    const profiles = [
      { user_id: "a", hard_constraints: [], implicit_weights: {}, onboarded: true },
      { user_id: "b", hard_constraints: [], implicit_weights: {}, onboarded: false },
      { user_id: "c", hard_constraints: [], implicit_weights: {}, onboarded: true },
    ];
    const ctx = intersectTasteProfiles(profiles);
    expect(ctx.onboardedCount).toBe(2);
    expect(ctx.memberCount).toBe(3);
  });
});

describe("buildTastePromptInjection", () => {
  it("returns empty string when no taste data", () => {
    const result = buildTastePromptInjection({
      hardConstraints: [],
      softPreferences: "",
      onboardedCount: 0,
      memberCount: 0,
    });
    expect(result).toBe("");
  });

  it("includes hard constraints and soft preferences", () => {
    const result = buildTastePromptInjection({
      hardConstraints: ["vegan", "no_chains"],
      softPreferences: "group prefers: japanese. group avoids: steakhouse",
      onboardedCount: 2,
      memberCount: 3,
    });
    expect(result).toContain("HARD CONSTRAINTS");
    expect(result).toContain("vegan");
    expect(result).toContain("SOFT PREFERENCES");
    expect(result).toContain("japanese");
  });
});
