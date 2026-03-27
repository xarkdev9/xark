import { describe, it, expect } from "vitest";
import { redactPII, sanitizeForIntelligence } from "./sanitize";

describe("redactPII", () => {
  it("redacts credit card numbers (spaces)", () => {
    expect(redactPII("my card is 4111 1111 1111 1111")).toBe("my card is [redacted]");
  });

  it("redacts credit card numbers (dashes)", () => {
    expect(redactPII("card: 4111-1111-1111-1111")).toBe("card: [redacted]");
  });

  it("redacts credit card numbers (no separator)", () => {
    expect(redactPII("pay with 4111111111111111")).toBe("pay with [redacted]");
  });

  it("does NOT redact non-Luhn numbers", () => {
    expect(redactPII("order 1234567890123456")).toBe("order 1234567890123456");
  });

  it("redacts SSN patterns", () => {
    expect(redactPII("ssn: 123-45-6789")).toBe("ssn: [redacted]");
  });

  it("redacts CVV after keyword", () => {
    expect(redactPII("cvv is 123")).toBe("cvv is [redacted]");
    expect(redactPII("security code 4567")).toBe("security code [redacted]");
  });

  it("redacts bank account after keyword", () => {
    expect(redactPII("account number 12345678901")).toBe("account number [redacted]");
    expect(redactPII("routing 123456789")).toBe("routing [redacted]");
  });

  it("preserves phone numbers", () => {
    expect(redactPII("call 619-555-1234")).toBe("call 619-555-1234");
    expect(redactPII("phone: (858) 555-0199")).toBe("phone: (858) 555-0199");
  });

  it("preserves addresses and names", () => {
    expect(redactPII("meet at 123 Main St")).toBe("meet at 123 Main St");
    expect(redactPII("nina proposed sushi")).toBe("nina proposed sushi");
  });

  it("handles empty string", () => {
    expect(redactPII("")).toBe("");
  });
});

describe("sanitizeForIntelligence", () => {
  it("sanitizes message content, preserves other fields", () => {
    const msgs = [
      { id: "1", space_id: "s1", role: "user" as const, content: "my card 4111111111111111", user_id: "u1", sender_name: "nina", created_at: "2026-01-01" },
    ];
    const result = sanitizeForIntelligence(msgs);
    expect(result[0].content).toBe("my card [redacted]");
    expect(result[0].id).toBe("1");
    expect(result[0].sender_name).toBe("nina");
  });
});
