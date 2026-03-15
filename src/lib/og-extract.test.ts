import { describe, it, expect } from "vitest";
import { parseOGTags } from "./og-extract";

describe("parseOGTags", () => {
  it("extracts og:title", () => {
    const html = '<meta property="og:title" content="Cool Product">';
    expect(parseOGTags(html).title).toBe("Cool Product");
  });

  it("extracts og:image", () => {
    const html = '<meta property="og:image" content="https://example.com/img.jpg">';
    expect(parseOGTags(html).image).toBe("https://example.com/img.jpg");
  });

  it("extracts og:description", () => {
    const html = '<meta property="og:description" content="A great product">';
    expect(parseOGTags(html).description).toBe("A great product");
  });

  it("extracts og:site_name", () => {
    const html = '<meta property="og:site_name" content="Amazon">';
    expect(parseOGTags(html).siteName).toBe("Amazon");
  });

  it("falls back to <title> tag when og:title missing", () => {
    const html = "<title>Fallback Title</title>";
    expect(parseOGTags(html).title).toBe("Fallback Title");
  });

  it("returns empty fields for no OG tags", () => {
    const result = parseOGTags("<html><body>Hello</body></html>");
    expect(result.title).toBeUndefined();
    expect(result.image).toBeUndefined();
  });

  it("extracts price from product:price:amount", () => {
    const html = '<meta property="product:price:amount" content="29.99">';
    expect(parseOGTags(html).price).toBe("29.99");
  });
});
