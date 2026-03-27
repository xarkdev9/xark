import { describe, it, expect } from "vitest";
import { TEMPLATES, getTemplate, templateLifetimeMs } from "./space-templates";

describe("space-templates", () => {
  it("has 6 templates", () => {
    expect(Object.keys(TEMPLATES)).toHaveLength(6);
  });

  it("getTemplate returns correct template", () => {
    const dinner = getTemplate("dinner_tonight");
    expect(dinner?.label).toBe("dinner tonight");
    expect(dinner?.categories).toContain("restaurant");
  });

  it("getTemplate returns undefined for unknown", () => {
    expect(getTemplate("nonexistent")).toBeUndefined();
  });

  it("templateLifetimeMs returns milliseconds", () => {
    expect(templateLifetimeMs("dinner_tonight")).toBe(8 * 60 * 60 * 1000);
  });

  it("templateLifetimeMs returns null for open template", () => {
    expect(templateLifetimeMs("open")).toBeNull();
  });

  it("templateLifetimeMs returns null for unknown", () => {
    expect(templateLifetimeMs("nonexistent")).toBeNull();
  });
});
