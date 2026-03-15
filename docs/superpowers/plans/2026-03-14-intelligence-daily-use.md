# Intelligence + Daily Use Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evolve @xark from trip planner to daily-use human companion with two-tier intelligence, PII sanitization, micro-space templates, instant invite, people-first Galaxy, two themes, two layouts, share pipeline, and booking bridge.

**Architecture:** Loosely coupled components (Galaxy zones as independent slots in a layout registry), two-tier intelligence (Gemini Search for local + Apify for travel), PII scrubbing before any AI call, progressive auth (name-only → OTP). All pure functions are TDD with vitest.

**Tech Stack:** Next.js 15, React 19, Supabase Postgres, Firebase Auth/Storage/FCM, Gemini 2.5 Flash, Apify, Framer Motion, vitest

**Spec:** `docs/superpowers/specs/2026-03-14-xark-intelligence-daily-use-design.md`

---

## Chunk 1: Foundation — DB Migration + Pure Functions

### Task 1: Database Migration

**Files:**
- Create: `supabase/migrations/013_daily_use.sql`

- [ ] **Step 1: Write migration SQL**

```sql
-- 013_daily_use.sql — Daily Use Foundation
-- Prerequisites: 012_perf_optimizations.sql must be applied first

-- Space invites for instant join links
CREATE TABLE IF NOT EXISTS space_invites (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(6), 'hex'),
  space_id TEXT NOT NULL REFERENCES spaces(id),
  created_by TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + interval '7 days',
  max_uses INTEGER DEFAULT NULL,
  use_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_space_invites_token ON space_invites(token);

-- User preferences (theme + layout)
ALTER TABLE users ADD COLUMN IF NOT EXISTS preferences JSONB DEFAULT '{"theme":"hearth","layout":"stream"}'::jsonb;

-- Space expiration for micro-space templates
ALTER TABLE spaces ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ DEFAULT NULL;

-- RLS for space_invites (uses auth_user_space_ids() SECURITY DEFINER function to avoid infinite recursion)
ALTER TABLE space_invites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "space_invites_select" ON space_invites FOR SELECT
  USING (space_id IN (SELECT unnest(auth_user_space_ids())));
CREATE POLICY "space_invites_insert" ON space_invites FOR INSERT
  WITH CHECK (space_id IN (SELECT unnest(auth_user_space_ids())));
```

- [ ] **Step 2: Verify migration file exists**

Run: `ls -la supabase/migrations/013_daily_use.sql`

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/013_daily_use.sql
git commit -m "feat: add migration 013 — space_invites, user preferences, space expiration"
```

---

### Task 2: PII Sanitizer (TDD)

**Files:**
- Create: `src/lib/intelligence/sanitize.ts`
- Create: `src/lib/intelligence/sanitize.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// src/lib/intelligence/sanitize.test.ts
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx vitest run src/lib/intelligence/sanitize.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement sanitize.ts**

```typescript
// src/lib/intelligence/sanitize.ts
// PII redaction before Gemini calls. Pure function, <1ms.

interface Message {
  id: string;
  space_id: string;
  role: string;
  content: string;
  user_id: string;
  sender_name: string;
  created_at: string;
}

/** Luhn algorithm — validates credit card numbers */
function luhnCheck(digits: string): boolean {
  const nums = digits.split("").map(Number);
  let sum = 0;
  let alt = false;
  for (let i = nums.length - 1; i >= 0; i--) {
    let n = nums[i];
    if (alt) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alt = !alt;
  }
  return sum % 10 === 0;
}

/** Redact PII from a single string */
export function redactPII(text: string): string {
  if (!text) return text;

  let result = text;

  // Credit/debit cards: 13-19 digits with optional spaces/dashes, Luhn-validated
  result = result.replace(
    /\b(\d[ -]?){13,19}\b/g,
    (match) => {
      const digits = match.replace(/[ -]/g, "");
      if (digits.length >= 13 && digits.length <= 19 && luhnCheck(digits)) {
        return "[redacted]";
      }
      return match;
    }
  );

  // SSN: XXX-XX-XXXX
  result = result.replace(/\b\d{3}-\d{2}-\d{4}\b/g, "[redacted]");

  // CVV/CVC after keyword (3-4 digits)
  result = result.replace(
    /\b(cvv|cvc|security\s+code)\s+\d{3,4}\b/gi,
    (match) => {
      const keyword = match.replace(/\s+\d{3,4}$/, "");
      return `${keyword} [redacted]`;
    }
  );

  // Bank account/routing after keyword (8-17 digits)
  result = result.replace(
    /\b(account\s*(?:number)?|routing|iban)\s+\d{8,17}\b/gi,
    (match) => {
      const keyword = match.replace(/\s+\d{8,17}$/, "");
      return `${keyword} [redacted]`;
    }
  );

  return result;
}

/** Sanitize messages for intelligence — strips PII from content only */
export function sanitizeForIntelligence<T extends Message>(messages: T[]): T[] {
  return messages.map((m) => ({
    ...m,
    content: redactPII(m.content),
  }));
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx vitest run src/lib/intelligence/sanitize.test.ts`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/lib/intelligence/sanitize.ts src/lib/intelligence/sanitize.test.ts
git commit -m "feat: PII sanitizer with Luhn validation — redacts cards, SSN, CVV before Gemini calls"
```

---

### Task 3: Space Templates (TDD)

**Files:**
- Create: `src/lib/space-templates.ts`
- Create: `src/lib/space-templates.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// src/lib/space-templates.test.ts
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx vitest run src/lib/space-templates.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement space-templates.ts**

```typescript
// src/lib/space-templates.ts
// Micro-space templates. Pure data, no UI logic.

export interface SpaceTemplate {
  id: string;
  label: string;
  categories: string[];
  lifetimeHours: number | null; // null = no expiry
  example: string;
}

export const TEMPLATES: Record<string, SpaceTemplate> = {
  dinner_tonight: {
    id: "dinner_tonight",
    label: "dinner tonight",
    categories: ["restaurant", "time"],
    lifetimeHours: 8,
    example: "where should we eat?",
  },
  weekend_plan: {
    id: "weekend_plan",
    label: "weekend plan",
    categories: ["activity", "place"],
    lifetimeHours: 72,
    example: "what are we doing saturday?",
  },
  trip: {
    id: "trip",
    label: "trip",
    categories: ["hotel", "flight", "activity", "restaurant"],
    lifetimeHours: 720, // 30 days
    example: "san diego spring break",
  },
  buy_together: {
    id: "buy_together",
    label: "buy together",
    categories: ["product", "store"],
    lifetimeHours: 168, // 7 days
    example: "gift for mom's birthday",
  },
  watch_listen: {
    id: "watch_listen",
    label: "watch / listen",
    categories: ["movie", "show", "music"],
    lifetimeHours: 24,
    example: "movie night picks",
  },
  open: {
    id: "open",
    label: "open",
    categories: [],
    lifetimeHours: null,
    example: "freeform",
  },
};

export function getTemplate(id: string): SpaceTemplate | undefined {
  return TEMPLATES[id];
}

export function templateLifetimeMs(id: string): number | null {
  const t = TEMPLATES[id];
  if (!t || t.lifetimeHours === null) return null;
  return t.lifetimeHours * 60 * 60 * 1000;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx vitest run src/lib/space-templates.test.ts`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/lib/space-templates.ts src/lib/space-templates.test.ts
git commit -m "feat: micro-space templates — 6 templates with categories and lifetimes"
```

---

### Task 4: OG Extraction

**Files:**
- Create: `src/lib/og-extract.ts`
- Create: `src/lib/og-extract.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// src/lib/og-extract.test.ts
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx vitest run src/lib/og-extract.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement og-extract.ts**

```typescript
// src/lib/og-extract.ts
// Server-side OG metadata extraction. No browser APIs.

export interface OGMetadata {
  title?: string;
  image?: string;
  description?: string;
  price?: string;
  siteName?: string;
  url?: string;
}

/** Parse OG tags from raw HTML string */
export function parseOGTags(html: string): OGMetadata {
  const result: OGMetadata = {};

  // Extract og: meta tags
  const ogPattern = /<meta\s+(?:[^>]*?\s+)?property=["'](og:[^"']+)["']\s+(?:[^>]*?\s+)?content=["']([^"']*)["'][^>]*>/gi;
  let match;
  while ((match = ogPattern.exec(html)) !== null) {
    const prop = match[1].toLowerCase();
    const content = match[2];
    if (prop === "og:title") result.title = content;
    else if (prop === "og:image") result.image = content;
    else if (prop === "og:description") result.description = content;
    else if (prop === "og:site_name") result.siteName = content;
    else if (prop === "og:url") result.url = content;
  }

  // Also check content-first attribute ordering
  const ogPatternReverse = /<meta\s+(?:[^>]*?\s+)?content=["']([^"']*)["']\s+(?:[^>]*?\s+)?property=["'](og:[^"']+)["'][^>]*>/gi;
  while ((match = ogPatternReverse.exec(html)) !== null) {
    const content = match[1];
    const prop = match[2].toLowerCase();
    if (prop === "og:title" && !result.title) result.title = content;
    else if (prop === "og:image" && !result.image) result.image = content;
    else if (prop === "og:description" && !result.description) result.description = content;
    else if (prop === "og:site_name" && !result.siteName) result.siteName = content;
    else if (prop === "og:url" && !result.url) result.url = content;
  }

  // Extract product:price:amount
  const pricePattern = /<meta\s+(?:[^>]*?\s+)?property=["']product:price:amount["']\s+(?:[^>]*?\s+)?content=["']([^"']*)["'][^>]*>/i;
  const priceMatch = pricePattern.exec(html);
  if (priceMatch) result.price = priceMatch[1];

  // Fallback: <title> tag if no og:title
  if (!result.title) {
    const titleMatch = /<title>([^<]*)<\/title>/i.exec(html);
    if (titleMatch) result.title = titleMatch[1].trim();
  }

  return result;
}

/** Fetch URL and extract OG metadata (server-side only) */
export async function fetchOGMetadata(url: string): Promise<OGMetadata> {
  try {
    const response = await fetch(url, {
      headers: { "User-Agent": "XarkBot/1.0 (OG Preview)" },
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) return { url };
    const html = await response.text();
    return { ...parseOGTags(html), url };
  } catch {
    return { url };
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx vitest run src/lib/og-extract.test.ts`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/lib/og-extract.ts src/lib/og-extract.test.ts
git commit -m "feat: OG metadata extraction — parses og:title/image/description/price from HTML"
```

---

### Task 5: Add expiresAt to computeSpaceState

**Files:**
- Modify: `src/lib/space-state.ts`

- [ ] **Step 1: Add expiresAt parameter**

In `src/lib/space-state.ts`, add a third optional parameter to `computeSpaceState`:

```typescript
export function computeSpaceState(
  items: SpaceStateItem[],
  tripDates?: { start_date: string; end_date: string },
  expiresAt?: string // ISO timestamp from space template lifetime
): SpaceState {
```

- [ ] **Step 2: Add expiration check before the existing logic**

After the `if (items.length === 0)` check at the top of the function, add:

```typescript
  // Template lifetime expiration — empty expired spaces are settled
  if (items.length === 0 && expiresAt && new Date(expiresAt) < new Date()) {
    return "settled";
  }
```

And after the `if (allSettled)` block, add:

```typescript
  // Template lifetime expiration — if expired and no active items, settled
  if (expiresAt && new Date(expiresAt) < new Date() && !hasOpenItems) {
    return "settled";
  }
```

- [ ] **Step 3: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds (expiresAt is optional, no callers break)

- [ ] **Step 4: Commit**

```bash
git add src/lib/space-state.ts
git commit -m "feat: computeSpaceState accepts optional expiresAt for template lifetime auto-settle"
```

---

## Chunk 2: Theme System + Keyboard

### Task 6: Midnight Theme in theme.ts

**Files:**
- Modify: `src/lib/theme.ts`

- [ ] **Step 1: Expand ThemeName type and add midnight config**

In `src/lib/theme.ts`, change:

```typescript
export type ThemeName = "hearth";
```

to:

```typescript
export type ThemeName = "hearth" | "midnight";
```

Then add midnight to the `themes` Record after the hearth entry:

```typescript
  midnight: {
    label: "midnight",
    mode: "dark",
    accent: "#40E0FF",
    text: "#E8E6E1",
    bg: "#0A0A0F",
    amber: "#D4A017",
    gold: "#C9A81E",
    green: "#10B981",
    orange: "#E8590C",
    gray: "#8A8A94",
  },
```

- [ ] **Step 2: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add src/lib/theme.ts
git commit -m "feat: add midnight dark theme to theme.ts"
```

---

### Task 7: ThemeProvider Dynamic Updates

**Files:**
- Modify: `src/components/os/ThemeProvider.tsx`

- [ ] **Step 1: Read current ThemeProvider**

Read `src/components/os/ThemeProvider.tsx` to understand the current `applyTheme` function structure.

- [ ] **Step 2: Add dynamic meta theme-color update**

Inside the `applyTheme` function, after the existing CSS variable setting logic, add:

```typescript
// Dynamic meta theme-color (keyboard + browser chrome)
const existingMeta = document.querySelector('meta[name="theme-color"]');
if (existingMeta) {
  existingMeta.setAttribute("content", t.bg);
} else {
  const meta = document.createElement("meta");
  meta.name = "theme-color";
  meta.content = t.bg;
  document.head.appendChild(meta);
}

// Theme-aware color-scheme on inputs (iOS keyboard fix)
const colorScheme = t.mode === "dark" ? "dark" : "light";
root.style.colorScheme = colorScheme;
document.querySelectorAll("input, textarea, [contenteditable]").forEach((el) => {
  (el as HTMLElement).style.colorScheme = colorScheme;
});
```

- [ ] **Step 3: Remove static themeColor from layout.tsx**

In `src/app/layout.tsx`, remove `themeColor: "#F8F7F4"` from the viewport config. Keep `colorScheme: "light"` as the initial SSR value (ThemeProvider overrides on hydration).

- [ ] **Step 4: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add src/components/os/ThemeProvider.tsx src/app/layout.tsx
git commit -m "feat: ThemeProvider dynamic meta theme-color + iOS keyboard color-scheme fix"
```

---

### Task 8: UserMenu Theme + Layout Toggles

**Files:**
- Modify: `src/components/os/UserMenu.tsx`

- [ ] **Step 1: Read current UserMenu system view**

Read `src/components/os/UserMenu.tsx` to understand the current system settings section.

- [ ] **Step 2: Add layout preference type and state**

The System view currently shows a theme selector with only "hearth". Add:

1. A `layoutPreference` state: `"stream" | "split"` (read from user preferences or localStorage)
2. Theme toggle: two options "hearth" and "midnight" (replace current single-option display)
3. Layout toggle: two options "stream" and "split"

Both toggles are floating text (no buttons/boxes per Constitution). Active option at full opacity, inactive at 0.3.

- [ ] **Step 3: Persist preferences**

On theme change: call `setTheme(name)` (existing ThemeProvider context). On layout change: store in localStorage `xark-layout` and update Supabase `users.preferences` if authenticated.

- [ ] **Step 4: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add src/components/os/UserMenu.tsx
git commit -m "feat: UserMenu theme + layout toggles — hearth/midnight, stream/split"
```

---

### Task 9: useKeyboard Hook

**Files:**
- Create: `src/hooks/useKeyboard.ts`

- [ ] **Step 1: Implement useKeyboard**

```typescript
// src/hooks/useKeyboard.ts
// Tracks virtual keyboard height via visualViewport API.
// iOS 13+, all Android. Falls back to 0 height if unsupported.

import { useState, useEffect } from "react";

interface KeyboardState {
  keyboardHeight: number;
  isKeyboardOpen: boolean;
}

export function useKeyboard(): KeyboardState {
  const [state, setState] = useState<KeyboardState>({
    keyboardHeight: 0,
    isKeyboardOpen: false,
  });

  useEffect(() => {
    const vv = window.visualViewport;
    if (!vv) return;

    const update = () => {
      const keyboardHeight = Math.max(0, window.innerHeight - vv.height);
      setState({
        keyboardHeight,
        isKeyboardOpen: keyboardHeight > 50, // threshold to avoid false positives
      });
    };

    vv.addEventListener("resize", update);
    vv.addEventListener("scroll", update);

    return () => {
      vv.removeEventListener("resize", update);
      vv.removeEventListener("scroll", update);
    };
  }, []);

  return state;
}
```

- [ ] **Step 2: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add src/hooks/useKeyboard.ts
git commit -m "feat: useKeyboard hook — visualViewport keyboard height detection"
```

---

### Task 10: ChatInput Keyboard + Theme Fixes

**Files:**
- Modify: `src/components/os/ChatInput.tsx`

- [ ] **Step 1: Read current ChatInput**

Read `src/components/os/ChatInput.tsx` to understand the textarea styling and positioning.

- [ ] **Step 2: Import useKeyboard and apply**

Add import: `import { useKeyboard } from "@/hooks/useKeyboard";`

Inside the component, add: `const { keyboardHeight, isKeyboardOpen } = useKeyboard();`

Update the container's `bottom` style to use `keyboardHeight` when keyboard is open:

```typescript
bottom: isKeyboardOpen ? keyboardHeight : layout.chatInputBottom ?? 56,
```

- [ ] **Step 3: Add theme-aware textarea background**

On the `<textarea>` element, add explicit styling for iOS keyboard color matching:

```typescript
style={{
  ...existingStyles,
  backgroundColor: "var(--xark-void)",
  color: "var(--xark-white)",
}}
```

- [ ] **Step 4: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add src/components/os/ChatInput.tsx
git commit -m "feat: ChatInput keyboard-aware positioning + theme-aware textarea for iOS keyboard color"
```

---

## Chunk 3: Intelligence Tier

### Task 11: Tool Registry Tier Field

**Files:**
- Modify: `src/lib/intelligence/tool-registry.ts`

- [ ] **Step 1: Read current tool-registry.ts**

Read `src/lib/intelligence/tool-registry.ts` to see the current ToolDefinition interface.

- [ ] **Step 2: Add tier field to ToolDefinition interface**

In the `ToolDefinition` interface, add the tier field:

```typescript
export interface ToolDefinition {
  tier: "gemini-search" | "apify";
  actorId: string;
  description: string;
  paramMap: (userParams: Record<string, string>) => Record<string, unknown>;
}
```

Then add `tier: "apify"` to ALL existing tool registrations. For each existing `registerTool` call (hotel, flight, activity, restaurant, general), add `tier: "apify"` as the first property in the definition object.

Add new local search tools:

```typescript
registerTool("local_restaurant", {
  tier: "gemini-search",
  actorId: "",  // not used for gemini-search tier
  description: "Local restaurant search via Gemini Search grounding",
  paramMap: (params) => params,
});

registerTool("local_activity", {
  tier: "gemini-search",
  actorId: "",
  description: "Local activity/place search via Gemini Search grounding",
  paramMap: (params) => params,
});

registerTool("local_general", {
  tier: "gemini-search",
  actorId: "",
  description: "General local search via Gemini Search grounding",
  paramMap: (params) => params,
});
```

- [ ] **Step 3: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add src/lib/intelligence/tool-registry.ts
git commit -m "feat: tool-registry tier field — gemini-search vs apify routing"
```

---

### Task 12: Orchestrator Gemini Search Integration

**Files:**
- Modify: `src/lib/intelligence/orchestrator.ts`

- [ ] **Step 1: Read current orchestrator.ts**

Read `src/lib/intelligence/orchestrator.ts` to understand the search routing flow.

- [ ] **Step 2: Add Gemini Search grounding path**

In the orchestrator, where it currently routes search results through Apify, add a tier check before the Apify tool execution. Add a new async function for Gemini Search:

```typescript
import { getTool } from "./tool-registry";

/** Call Gemini with Google Search grounding for local queries */
async function geminiSearchGrounded(
  query: string,
  spaceTitle: string
): Promise<Array<{ title: string; description: string; url?: string; phone?: string; address?: string }>> {
  const contextualQuery = spaceTitle
    ? `${query} near ${spaceTitle}`
    : query;

  const result = await model.generateContent({
    contents: [{ role: "user", parts: [{ text: `Find real places for: ${contextualQuery}. Return a JSON array of objects with fields: title, description, url, phone, address. Return ONLY the JSON array, no other text.` }] }],
    tools: [{ googleSearch: {} }],
  });

  const responseText = result.response.text();

  // Parse JSON from response (Gemini may wrap in markdown code blocks)
  const jsonMatch = responseText.match(/\[[\s\S]*\]/);
  if (!jsonMatch) return [];

  try {
    const parsed = JSON.parse(jsonMatch[0]);
    if (!Array.isArray(parsed)) return [];
    return parsed.map((item: Record<string, unknown>) => ({
      title: String(item.title || ""),
      description: String(item.description || ""),
      url: item.url ? String(item.url) : undefined,
      phone: item.phone ? String(item.phone) : undefined,
      address: item.address ? String(item.address) : undefined,
    }));
  } catch {
    return [];
  }
}
```

Then in the search routing logic, add the tier check:

```typescript
const tool = getTool(toolName);
if (!tool) { /* existing error handling */ }

let searchResults;
if (tool.tier === "gemini-search") {
  const localResults = await geminiSearchGrounded(searchQuery, input.spaceTitle || "");
  searchResults = localResults.map((r) => ({
    title: r.title,
    description: r.description,
    category: toolName.replace("local_", ""),
    metadata: {
      url: r.url,
      phone: r.phone,
      address: r.address,
      search_tier: "gemini-search" as const,
    },
  }));
} else {
  // Existing Apify actor path (unchanged)
  searchResults = await runApifyActor(tool, params);
}
```

- [ ] **Step 3: Add search_tier to decision_item metadata**

When upserting search results as decision_items (in the existing insert loop), include `metadata.search_tier: tool.tier`. For Gemini Search results, `metadata.phone` is already populated from the grounding response above. For Apify results, add `metadata.search_tier: "apify"`.

- [ ] **Step 4: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add src/lib/intelligence/orchestrator.ts
git commit -m "feat: orchestrator routes local queries to Gemini Search grounding, travel to Apify"
```

---

### Task 13: Wire Sanitizer into /api/xark

**Files:**
- Modify: `src/app/api/xark/route.ts`

- [ ] **Step 1: Read current /api/xark route**

Read `src/app/api/xark/route.ts` to find where messages are passed to the orchestrator.

- [ ] **Step 2: Add sanitize import and apply**

Add import:
```typescript
import { sanitizeForIntelligence } from "@/lib/intelligence/sanitize";
```

Before the `orchestrate()` call, sanitize the recent messages:

```typescript
const sanitizedMessages = sanitizeForIntelligence(recentMsgs);
```

Pass `sanitizedMessages` instead of `recentMsgs` to the orchestrator call.

- [ ] **Step 3: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add src/app/api/xark/route.ts
git commit -m "feat: PII sanitization before Gemini calls in /api/xark"
```

---

## Chunk 4: Galaxy Refactor

### Task 14: AwarenessStream Component

**Files:**
- Create: `src/components/os/AwarenessStream.tsx`

- [ ] **Step 1: Read current Galaxy page**

Read `src/app/galaxy/page.tsx` to identify the awareness stream rendering code (the "plans" tab content that shows space summaries).

- [ ] **Step 2: Extract AwarenessStream component**

Create `src/components/os/AwarenessStream.tsx` as an independent component:

```typescript
// Props: userId, onSpaceTap(spaceId: string)
// Data: fetches SpaceAwareness[] from fetchAwareness(userId)
// Renders: scrollable list of space summaries with consensus state
// Each item: space title + summaryText(awareness) + recency
// Tap → calls onSpaceTap(spaceId)
```

Extract the relevant JSX and state from the Galaxy page's "plans" tab rendering. The component:
- Calls `fetchAwareness(userId)` on mount
- Subscribes to `space_members` INSERT for refetch
- Renders the space list with opacity based on `awarenessOpacity(priority)`
- Includes the space creation flow (dream input + template picker)

- [ ] **Step 3: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add src/components/os/AwarenessStream.tsx
git commit -m "feat: AwarenessStream component — extracted from Galaxy page, independent data fetching"
```

---

### Task 15: PeopleDock Component

**Files:**
- Create: `src/components/os/PeopleDock.tsx`

- [ ] **Step 1: Create PeopleDock component**

```typescript
// src/components/os/PeopleDock.tsx
// People dock — fixed at bottom, thumb zone.
// Faces of everyone you share spaces with.
// Tap face → opens 1:1 sanctuary.

// Props: userId, onPersonTap(spaceId: string)
// Data: fetches PersonalChat[] from fetchPersonalChats(userId)
// Renders: horizontal scroll of avatars sorted by last activity
// Last item: [+] for inviting new person
```

Key implementation details:
- Horizontal scroll container with `overflow-x: auto`, `-webkit-overflow-scrolling: touch`
- Each avatar: 44px circle, user photo or initial
- Subtle activity preview on avatar (tiny badge if recent activity)
- Most active contacts sort left (closest to thumb)
- `[+]` at end: triggers invite flow (phone number or link share)
- Fixed at bottom of its layout slot (parent controls position)

- [ ] **Step 2: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add src/components/os/PeopleDock.tsx
git commit -m "feat: PeopleDock component — thumb-zone horizontal avatar dock with [+] invite"
```

---

### Task 16: GalaxyLayout Registry

**Files:**
- Create: `src/components/os/GalaxyLayout.tsx`

- [ ] **Step 1: Create GalaxyLayout with stream + split layouts**

```typescript
// src/components/os/GalaxyLayout.tsx
// Layout registry for Galaxy page.
// Components know nothing about layout — parent arranges them.

"use client";
import { ReactNode } from "react";

export type LayoutName = "stream" | "split";

interface GalaxyLayoutProps {
  layout: LayoutName;
  awarenessStream: ReactNode;
  peopleDock: ReactNode;
  controlCaret: ReactNode;
}

function StreamLayout({ awarenessStream, peopleDock, controlCaret }: Omit<GalaxyLayoutProps, "layout">) {
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100dvh" }}>
      <div style={{ flex: 1, overflowY: "auto" }}>
        {awarenessStream}
      </div>
      <div style={{ flexShrink: 0 }}>
        {peopleDock}
      </div>
      {controlCaret}
    </div>
  );
}

function SplitLayout({ awarenessStream, peopleDock, controlCaret }: Omit<GalaxyLayoutProps, "layout">) {
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100dvh" }}>
      <div style={{ flex: 1, display: "flex" }}>
        <div style={{ flex: 1, overflowY: "auto", borderRight: "none" }}>
          {peopleDock}
        </div>
        <div style={{ flex: 1, overflowY: "auto" }}>
          {awarenessStream}
        </div>
      </div>
      {controlCaret}
    </div>
  );
}

const LAYOUTS: Record<LayoutName, typeof StreamLayout> = {
  stream: StreamLayout,
  split: SplitLayout,
};

export function GalaxyLayout({ layout, ...props }: GalaxyLayoutProps) {
  const Layout = LAYOUTS[layout];
  return <Layout {...props} />;
}
```

- [ ] **Step 2: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add src/components/os/GalaxyLayout.tsx
git commit -m "feat: GalaxyLayout registry — stream (default) + split layouts"
```

---

### Task 17: Galaxy Page Refactor

**Files:**
- Modify: `src/app/galaxy/page.tsx`

- [ ] **Step 1: Read current Galaxy page fully**

Read `src/app/galaxy/page.tsx` to understand all state, subscriptions, and rendering.

- [ ] **Step 2: Refactor to thin layout shell**

Replace the Galaxy page's inline rendering with composed components:

```typescript
import { GalaxyLayout, LayoutName } from "@/components/os/GalaxyLayout";
import { AwarenessStream } from "@/components/os/AwarenessStream";
import { PeopleDock } from "@/components/os/PeopleDock";
```

State that stays in Galaxy: `userId`, `layoutPreference` (from localStorage/preferences).
State that moves to AwarenessStream: awareness data, space creation.
State that moves to PeopleDock: personal chats, contacts.

The render becomes:

```typescript
<GalaxyLayout
  layout={layoutPreference}
  awarenessStream={
    <AwarenessStream
      userId={userId}
      onSpaceTap={(id) => router.push(`/space/${id}`)}
    />
  }
  peopleDock={
    <PeopleDock
      userId={userId}
      onPersonTap={(sanctuaryId) => router.push(`/space/${sanctuaryId}`)}
    />
  }
  controlCaret={<ControlCaret ... />}
/>
```

- [ ] **Step 3: Migrate tab system to layout system**

The current Galaxy has `activeTab: "people" | "plans"` with tab switching. This is replaced by the layout system:
- **"plans" tab content** (space awareness, space creation, onboarding whispers) → moves to `AwarenessStream.tsx`
- **"people" tab content** (personal chats, sanctuary spaces, contact names) → moves to `PeopleDock.tsx`
- **Tab underline animation, swipe gesture, activeTab state** → removed entirely. Layout toggle lives in UserMenu instead.
- **Space creation** (dream input, send icon, template picker) → stays in `AwarenessStream.tsx` (it's part of the awareness/planning flow)
- **Real-time subscriptions** → each child component manages its own subscriptions
- **Onboarding whispers** → move to `AwarenessStream.tsx`
- **UserMenu visibility** → stays in Galaxy page (shared across layouts)

- [ ] **Step 4: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Manual test**

Run: `npx next dev` → open localhost:3000 → verify Galaxy loads with spaces and chats.

- [ ] **Step 6: Commit**

```bash
git add src/app/galaxy/page.tsx
git commit -m "refactor: Galaxy page → thin layout shell with AwarenessStream + PeopleDock slots"
```

---

## Chunk 5: Invite System

### Task 18: /api/join Route

**Files:**
- Create: `src/app/api/join/route.ts`

- [ ] **Step 1: Create join API route**

```typescript
// src/app/api/join/route.ts
// Name-only invite join. Validates token, creates user, signs JWT.
// Bypasses RLS via supabaseAdmin. Same JWT pattern as dev-auto-login.

import { NextRequest, NextResponse } from "next/server";
import { SignJWT } from "jose";

export async function POST(req: NextRequest) {
  try {
    const { token, displayName } = await req.json();
    if (!token || !displayName) {
      return NextResponse.json({ error: "token and displayName required" }, { status: 400 });
    }

    const { supabaseAdmin } = await import("@/lib/supabase-admin");
    if (!supabaseAdmin) {
      return NextResponse.json({ error: "server not configured" }, { status: 500 });
    }

    // Validate invite token
    const { data: invite } = await supabaseAdmin
      .from("space_invites")
      .select("*")
      .eq("token", token)
      .single();

    if (!invite) {
      return NextResponse.json({ error: "invalid invite" }, { status: 404 });
    }

    // Check expiry
    if (new Date(invite.expires_at) < new Date()) {
      return NextResponse.json({ error: "invite expired" }, { status: 410 });
    }

    // Check max uses
    if (invite.max_uses !== null && invite.use_count >= invite.max_uses) {
      return NextResponse.json({ error: "invite limit reached" }, { status: 410 });
    }

    // Sanitize display name
    const safeName = displayName.trim().toLowerCase().replace(/[^a-z0-9_]/g, "").slice(0, 20);
    if (!safeName) {
      return NextResponse.json({ error: "invalid name" }, { status: 400 });
    }

    const userId = `name_${safeName}`;

    // Upsert user
    await supabaseAdmin.from("users").upsert(
      { id: userId, display_name: safeName },
      { onConflict: "id" }
    );

    // Add as space member (ignore if already exists)
    await supabaseAdmin.from("space_members").upsert(
      { space_id: invite.space_id, user_id: userId },
      { onConflict: "space_id,user_id" }
    );

    // Increment use count
    await supabaseAdmin
      .from("space_invites")
      .update({ use_count: invite.use_count + 1 })
      .eq("id", invite.id);

    // Sign JWT (same pattern as dev-auto-login)
    const jwtSecret = process.env.SUPABASE_JWT_SECRET;
    if (!jwtSecret) {
      return NextResponse.json({ error: "jwt not configured" }, { status: 500 });
    }

    const secret = new TextEncoder().encode(jwtSecret);
    const jwt = await new SignJWT({
      sub: userId,
      role: "authenticated",
      aud: "authenticated",
      iss: "supabase",
    })
      .setProtectedHeader({ alg: "HS256", typ: "JWT" })
      .setIssuedAt()
      .setExpirationTime("24h")
      .sign(secret);

    return NextResponse.json({
      token: jwt,
      user: { id: userId, displayName: safeName },
      spaceId: invite.space_id,
    });
  } catch (err) {
    console.error("[xark] join error:", err);
    return NextResponse.json({ error: "join failed" }, { status: 500 });
  }
}
```

- [ ] **Step 2: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add src/app/api/join/route.ts
git commit -m "feat: /api/join — name-only invite join with JWT signing, bypasses RLS"
```

---

### Task 19: Join Page

**Files:**
- Create: `src/app/j/[token]/page.tsx`

- [ ] **Step 1: Create invite join page**

```typescript
// src/app/j/[token]/page.tsx
// Instant invite join page. Name prompt → POST /api/join → redirect to space.
"use client";

import { useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { colors, text, textColor } from "@/lib/theme";
import { setSupabaseToken } from "@/lib/supabase";

export default function JoinPage() {
  const { token } = useParams<{ token: string }>();
  const router = useRouter();
  const [name, setName] = useState("");
  const [error, setError] = useState("");
  const [joining, setJoining] = useState(false);

  const handleJoin = async () => {
    if (!name.trim() || joining) return;
    setJoining(true);
    setError("");

    try {
      const res = await fetch("/api/join", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token, displayName: name.trim() }),
      });

      const data = await res.json();
      if (!res.ok) {
        setError(data.error || "could not join");
        setJoining(false);
        return;
      }

      // Set auth token for RLS
      setSupabaseToken(data.token);
      // Store user info
      localStorage.setItem("xark-user", JSON.stringify(data.user));
      // Navigate to space
      router.push(`/space/${data.spaceId}`);
    } catch {
      setError("something went wrong");
      setJoining(false);
    }
  };

  return (
    <div
      style={{
        minHeight: "100dvh",
        background: colors.void,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: "0 32px",
        gap: 24,
      }}
    >
      <p style={{ ...text.body, color: textColor(0.6) }}>
        join the conversation
      </p>

      <input
        type="text"
        placeholder="your name"
        value={name}
        onChange={(e) => setName(e.target.value)}
        onKeyDown={(e) => e.key === "Enter" && handleJoin()}
        autoFocus
        style={{
          ...text.body,
          color: textColor(0.9),
          backgroundColor: "transparent",
          border: "none",
          borderBottom: "none",
          backgroundImage: `linear-gradient(to right, transparent, ${textColor(0.15)}, transparent)`,
          backgroundSize: "100% 1px",
          backgroundPosition: "bottom",
          backgroundRepeat: "no-repeat",
          padding: "8px 0",
          width: "100%",
          maxWidth: 280,
          textAlign: "center",
          outline: "none",
        }}
      />

      {error && (
        <p style={{ ...text.label, color: colors.orange }}>{error}</p>
      )}

      <p
        onClick={handleJoin}
        style={{
          ...text.body,
          color: joining ? textColor(0.3) : textColor(0.7),
          cursor: joining ? "default" : "pointer",
        }}
      >
        {joining ? "joining..." : "enter"}
      </p>
    </div>
  );
}
```

- [ ] **Step 2: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add src/app/j/[token]/page.tsx
git commit -m "feat: invite join page — name prompt, JWT auth, redirect to space"
```

---

### Task 20: Invite Link Generation in Space Creation

**Files:**
- Modify: `src/lib/spaces.ts`

- [ ] **Step 1: Read current createSpace**

Read `src/lib/spaces.ts` to understand the space creation flow.

- [ ] **Step 2: Add invite link generation after space creation**

Add a new exported function:

```typescript
export async function createInviteLink(spaceId: string, userId: string): Promise<string | null> {
  try {
    const { supabase } = await import("./supabase");
    const { data } = await supabase
      .from("space_invites")
      .insert({ space_id: spaceId, created_by: userId })
      .select("token")
      .single();

    if (!data) return null;
    // Use window.location.origin for the base URL
    const base = typeof window !== "undefined" ? window.location.origin : "";
    return `${base}/j/${data.token}`;
  } catch {
    return null;
  }
}
```

- [ ] **Step 3: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add src/lib/spaces.ts
git commit -m "feat: createInviteLink — generates shareable join URL for any space"
```

---

## Chunk 6: Share Pipeline

### Task 21: OG Extraction API Route

**Files:**
- Create: `src/app/api/og/route.ts`

- [ ] **Step 1: Create OG extraction endpoint**

```typescript
// src/app/api/og/route.ts
// Server-side OG metadata extraction. Avoids CORS issues.

import { NextRequest, NextResponse } from "next/server";
import { fetchOGMetadata } from "@/lib/og-extract";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { url, insertAsItem, spaceId, title, text } = body;

    // OG extraction (if URL provided)
    let metadata = {};
    if (url && typeof url === "string") {
      try { new URL(url); } catch {
        return NextResponse.json({ error: "invalid url" }, { status: 400 });
      }
      metadata = await fetchOGMetadata(url);
    }

    // Optionally insert as decision_item (share flow, uses supabaseAdmin for RLS bypass)
    if (insertAsItem && spaceId) {
      const { supabaseAdmin } = await import("@/lib/supabase-admin");
      if (supabaseAdmin) {
        const ogMeta = metadata as Record<string, string>;
        await supabaseAdmin.from("decision_items").insert({
          space_id: spaceId,
          title: ogMeta.title || title || "shared item",
          category: "shared",
          description: ogMeta.description || text || url || "",
          state: "proposed",
          metadata: {
            ...ogMeta,
            source: "share_target",
            shared_url: url || undefined,
          },
        });
      }
    }

    return NextResponse.json(metadata);
  } catch {
    return NextResponse.json({ error: "extraction failed" }, { status: 500 });
  }
}
```

- [ ] **Step 2: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add src/app/api/og/route.ts
git commit -m "feat: /api/og — server-side OG metadata extraction endpoint"
```

---

### Task 22: Share Target API Route + Manifest Update

**Files:**
- Create: `src/app/api/share/route.ts`
- Modify: `public/manifest.json`

- [ ] **Step 1: Create share target handler**

```typescript
// src/app/api/share/route.ts
// Receives Android PWA share target POST, redirects to space picker.

import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  try {
    const formData = await req.formData();
    const title = formData.get("title") as string || "";
    const text = formData.get("text") as string || "";
    const url = formData.get("url") as string || "";

    // Redirect to space picker with shared data as query params
    const params = new URLSearchParams();
    if (title) params.set("title", title);
    if (text) params.set("text", text);
    if (url) params.set("url", url);

    return NextResponse.redirect(
      new URL(`/share?${params.toString()}`, req.url)
    );
  } catch {
    return NextResponse.redirect(new URL("/galaxy", req.url));
  }
}
```

- [ ] **Step 2: Update manifest.json with share_target**

Add to `public/manifest.json`:

```json
"share_target": {
  "action": "/api/share",
  "method": "POST",
  "enctype": "multipart/form-data",
  "params": {
    "title": "title",
    "text": "text",
    "url": "url"
  }
}
```

- [ ] **Step 3: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add src/app/api/share/route.ts public/manifest.json
git commit -m "feat: share target — Android PWA share sheet handler + manifest config"
```

---

### Task 23: SpacePicker + Share Page

**Files:**
- Create: `src/components/os/SpacePicker.tsx`
- Create: `src/app/share/page.tsx`

- [ ] **Step 1: Create SpacePicker component**

```typescript
// src/components/os/SpacePicker.tsx
// Space selection for share sheet flow.
// Shows recent spaces sorted by last activity. Tap to select.
"use client";

import { useEffect, useState } from "react";
import { colors, text, textColor } from "@/lib/theme";
import { fetchSpaceList, SpaceListItem } from "@/lib/space-data";

interface SpacePickerProps {
  userId?: string;
  onSelect: (spaceId: string, spaceTitle: string) => void;
}

export function SpacePicker({ userId, onSelect }: SpacePickerProps) {
  const [spaces, setSpaces] = useState<SpaceListItem[]>([]);

  useEffect(() => {
    fetchSpaceList(userId).then(setSpaces);
  }, [userId]);

  return (
    <div style={{ padding: "16px 0" }}>
      <p style={{ ...text.label, color: textColor(0.4), padding: "0 24px", marginBottom: 12 }}>
        pick a space
      </p>
      {spaces.map((space) => (
        <div
          key={space.id}
          onClick={() => onSelect(space.id, space.title)}
          style={{
            padding: "12px 24px",
            cursor: "pointer",
          }}
        >
          <p style={{ ...text.body, color: textColor(0.8) }}>{space.title}</p>
          <p style={{ ...text.label, color: textColor(0.35) }}>
            {space.members.map((m) => m.displayName).join(", ")}
          </p>
        </div>
      ))}
    </div>
  );
}
```

- [ ] **Step 2: Create share page**

```typescript
// src/app/share/page.tsx
// Receives shared content from share target, shows space picker.
"use client";

import { useSearchParams, useRouter } from "next/navigation";
import { Suspense, useState } from "react";
import { SpacePicker } from "@/components/os/SpacePicker";
import { colors, text, textColor } from "@/lib/theme";

function ShareContent() {
  const params = useSearchParams();
  const router = useRouter();
  const [saving, setSaving] = useState(false);

  const title = params.get("title") || "";
  const sharedText = params.get("text") || "";
  const url = params.get("url") || "";

  const handleSelect = async (spaceId: string) => {
    setSaving(true);

    // Server-side insert via /api/share (avoids RLS issues for unauthenticated users)
    try {
      await fetch("/api/og", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          url,
          title: title || sharedText.slice(0, 100),
          text: sharedText,
          spaceId,
          insertAsItem: true, // tells /api/og to also insert as decision_item via supabaseAdmin
        }),
      });
    } catch { /* proceed to space regardless */ }

    router.push(`/space/${spaceId}`);
  };

  return (
    <div style={{ minHeight: "100dvh", background: colors.void }}>
      <div style={{ padding: "48px 24px 16px" }}>
        <p style={{ ...text.body, color: textColor(0.7) }}>
          {url ? `sharing: ${title || url}` : `sharing: ${title || sharedText.slice(0, 50)}`}
        </p>
      </div>
      <SpacePicker onSelect={handleSelect} />
    </div>
  );
}

export default function SharePage() {
  return (
    <Suspense>
      <ShareContent />
    </Suspense>
  );
}
```

- [ ] **Step 3: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add src/components/os/SpacePicker.tsx src/app/share/page.tsx
git commit -m "feat: SpacePicker + share page — receive shared content, pick space, create decision item"
```

---

### Task 24: ChatInput URL Detection

**Files:**
- Modify: `src/components/os/ChatInput.tsx`

- [ ] **Step 1: Read current ChatInput send logic**

Read `src/components/os/ChatInput.tsx` to understand how messages are submitted (the `onSend` callback).

- [ ] **Step 2: Add URL detection before send**

Add a URL detection pattern and subtle "add to decisions?" prompt:

```typescript
const URL_PATTERN = /https?:\/\/[^\s]+/i;

// In the send handler, after getting the input text:
const urlMatch = input.match(URL_PATTERN);
if (urlMatch && !urlPromptDismissed) {
  setDetectedUrl(urlMatch[0]);
  setShowUrlPrompt(true);
  return; // Wait for user decision
}
```

The prompt is floating text below the input (not a modal):
- "add to decisions?" at `textColor(0.5)`, two options: "yes" (taps → OG extract + create item) and "no" (taps → sends as regular message)

- [ ] **Step 3: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add src/components/os/ChatInput.tsx
git commit -m "feat: ChatInput URL detection — 'add to decisions?' prompt on URL paste"
```

---

## Chunk 7: Booking Bridge + Confirmation

### Task 25: DecisionCard Tappable Booking URL

**Files:**
- Modify: `src/components/os/DecisionCard.tsx`

- [ ] **Step 1: Read current DecisionCard**

Read `src/components/os/DecisionCard.tsx` to understand the current tap/click handling.

- [ ] **Step 2: Add booking URL tap behavior for locked/claimed items**

When item has metadata.url or metadata.phone AND item is locked/claimed:

```typescript
const handleCardTap = () => {
  if (!item.is_locked) {
    onTap?.(item.id); // existing behavior
    return;
  }

  // Booking bridge — open external URL or phone dialer
  const url = item.metadata?.url || item.metadata?.shared_url;
  const phone = item.metadata?.phone;

  if (url) {
    window.open(url, "_blank", "noopener,noreferrer");
  } else if (phone) {
    window.open(`tel:${phone}`);
  } else {
    onTap?.(item.id); // fallback to existing behavior
  }
};
```

- [ ] **Step 3: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add src/components/os/DecisionCard.tsx
git commit -m "feat: DecisionCard tappable booking URL — locked items open external booking page"
```

---

### Task 26: ClaimSheet Booking Link

**Files:**
- Modify: `src/components/os/ClaimSheet.tsx`

- [ ] **Step 1: Read current ClaimSheet**

Read `src/components/os/ClaimSheet.tsx` to understand the current layout.

- [ ] **Step 2: Surface booking URL in claim flow**

After the item title, show the booking URL/phone if available:

```typescript
{item.metadata?.url && (
  <p
    onClick={() => window.open(item.metadata.url, "_blank", "noopener,noreferrer")}
    style={{ ...text.label, color: colors.cyan, cursor: "pointer", opacity: 0.7 }}
  >
    {item.metadata.siteName || "open booking page"}
  </p>
)}
{item.metadata?.phone && (
  <p
    onClick={() => window.open(`tel:${item.metadata.phone}`)}
    style={{ ...text.label, color: colors.cyan, cursor: "pointer", opacity: 0.7 }}
  >
    call {item.metadata.phone}
  </p>
)}
```

- [ ] **Step 3: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add src/components/os/ClaimSheet.tsx
git commit -m "feat: ClaimSheet surfaces booking URL/phone for locked items"
```

---

### Task 27: Wire pendingConfirmation in Space Page

**Files:**
- Modify: `src/app/space/[id]/page.tsx`

- [ ] **Step 1: Read current xark response handling**

Read `src/app/space/[id]/page.tsx` to find where `/api/xark` responses are processed.

- [ ] **Step 2: Add pendingConfirmation state and handler**

Add state:
```typescript
const [pendingConfirmation, setPendingConfirmation] = useState<{
  response: string;
  action: string;
  payload: Record<string, unknown>;
} | null>(null);
```

In the `/api/xark` response handler, check for `pendingConfirmation`:

```typescript
if (data.pendingConfirmation) {
  setPendingConfirmation({
    response: data.response,
    action: data.action,
    payload: data.payload,
  });
  // Show as @xark message
  addXarkMessage(data.response);
  return;
}
```

- [ ] **Step 3: Add confirmation whisper in chat stream**

When `pendingConfirmation` is set, render a confirmation whisper (same style as handshake whisper — floating text):

```typescript
{pendingConfirmation && (
  <div style={{ textAlign: "center", padding: "12px 0" }}>
    <span
      onClick={async () => {
        await fetch("/api/xark", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            message: `confirm_action`,
            spaceId,
            payload: pendingConfirmation.payload,
          }),
        });
        setPendingConfirmation(null);
      }}
      style={{ ...text.body, color: colors.gold, cursor: "pointer", opacity: 0.8 }}
    >
      confirm
    </span>
    <span style={{ ...text.body, color: textColor(0.3), margin: "0 16px" }}>·</span>
    <span
      onClick={() => setPendingConfirmation(null)}
      style={{ ...text.body, color: textColor(0.4), cursor: "pointer" }}
    >
      wait
    </span>
  </div>
)}
```

- [ ] **Step 4: Verify build passes**

Run: `npx next build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add src/app/space/[id]/page.tsx
git commit -m "feat: wire pendingConfirmation — @xark shows confirm/wait whisper for actions"
```

---

## Chunk 8: Guardrail Sync + Final Verification

### Task 28: Update Guardrail Files

**Files:**
- Modify: `CLAUDE.md`
- Modify: `CONSTITUTION.md`
- Modify: `.xark-state.json`

- [ ] **Step 1: Read current guardrail files**

Read CLAUDE.md, CONSTITUTION.md, and .xark-state.json.

- [ ] **Step 2: Update CLAUDE.md**

Constitutional amendments:
- Theme system: "1 Theme" → "2 Themes (hearth default, midnight dark)"
- Add `midnight` to theme description with color values from theme.ts
- Update text color hex references: `#141414` → `#111111`, `#F0EEE9` → `#F8F7F4` (match theme.ts SSOT)
- Add to module map:
  - `src/lib/intelligence/sanitize.ts` — PII redaction before Gemini calls
  - `src/lib/og-extract.ts` — OG metadata extraction
  - `src/lib/space-templates.ts` — micro-space templates
  - `src/hooks/useKeyboard.ts` — keyboard height detection
  - `src/components/os/GalaxyLayout.tsx` — layout registry (stream + split)
  - `src/components/os/AwarenessStream.tsx` — awareness stream component
  - `src/components/os/PeopleDock.tsx` — people dock component
  - `src/components/os/SpacePicker.tsx` — space selection for share flow
  - `/api/join` — name-only invite join with JWT
  - `/api/og` — OG extraction endpoint
  - `/api/share` — PWA share target handler
- Update Galaxy page description: thin layout shell with GalaxyLayout registry
- Update ChatInput description: URL detection + keyboard-aware positioning

- [ ] **Step 3: Update CONSTITUTION.md**

- Theme section: add midnight dark theme alongside hearth
- Add Galaxy layout system section: stream (default) + split, GalaxyLayout registry
- Update keyboard handling section
- Add share pipeline section

- [ ] **Step 4: Update .xark-state.json**

- `foveal_focus`: update to reflect daily use intelligence phase
- `themes`: `["hearth (light, default)", "midnight (dark)"]`
- Add new modules to component registry

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md CONSTITUTION.md .xark-state.json
git commit -m "docs: guardrail sync — midnight theme, GalaxyLayout, intelligence tier, share pipeline"
```

---

### Task 29: Update Memory

**Files:**
- Modify: `/Users/ramchitturi/.claude/projects/-Users-ramchitturi-xark9/memory/MEMORY.md`

- [ ] **Step 1: Update MEMORY.md**

Add to completed phases:
- Mar 14 Intelligence + Daily Use (PII sanitizer, two-tier intelligence, micro-space templates, instant invite, people-first Galaxy, GalaxyLayout registry, midnight theme, share pipeline, booking bridge, keyboard fix)

Update component map with new components and modified files.

- [ ] **Step 2: Commit memory update is not needed** (memory files are outside repo)

---

### Task 30: Final Build Verification

- [ ] **Step 1: Clean build**

Run: `npx next build`
Expected: Build succeeds with no errors

- [ ] **Step 2: Run all tests**

Run: `npx vitest run`
Expected: All tests pass (sanitize, space-templates, og-extract)

- [ ] **Step 3: Local smoke test**

Run: `npx next dev` → open localhost:3000

Verify:
1. Galaxy loads with awareness stream + people dock
2. Theme toggle in UserMenu switches between hearth/midnight
3. Layout toggle switches between stream/split
4. Keyboard color matches app theme (test on mobile or device emulator)
5. Navigate to a space → discuss/decide still works
6. Type a URL in chat → "add to decisions?" prompt appears

---

## Dependency Graph

```
Task 1 (migration) ─────────────────────────────────────────────────┐
Task 2 (sanitize) ──────────────────┐                               │
Task 3 (templates) ─────────────────┤                               │
Task 4 (og-extract) ────────────────┤                               │
Task 5 (space-state) ───────────────┤                               │
                                    ├─── All independent             │
Task 6 (theme.ts) ──────────────────┤                               │
Task 9 (useKeyboard) ───────────────┤                               │
                                    │                               │
Task 7 (ThemeProvider) ─── depends on ─── Task 6                    │
Task 8 (UserMenu) ──── depends on ─── Task 7                       │
Task 10 (ChatInput kb) ─ depends on ─── Task 9                     │
                                                                    │
Task 11 (tool-registry) ────────────────────────────────────────────┤
Task 12 (orchestrator) ─── depends on ─── Task 11                  │
Task 13 (/api/xark) ──── depends on ─── Tasks 2, 12                │
                                                                    │
Task 14 (AwarenessStream) ──────────────────────────────────────────┤
Task 15 (PeopleDock) ───────────────────────────────────────────────┤
Task 16 (GalaxyLayout) ─── depends on ─── Tasks 14, 15             │
Task 17 (Galaxy refactor) ─ depends on ─── Task 16                 │
                                                                    │
Task 18 (/api/join) ──── depends on ─── Task 1 (migration)         │
Task 19 (join page) ──── depends on ─── Task 18                    │
Task 20 (invite link) ── depends on ─── Task 1                     │
                                                                    │
Task 21 (/api/og) ──── depends on ─── Task 4                       │
Task 22 (share target) ─ depends on ─── Task 21                    │
Task 23 (SpacePicker) ── depends on ─── Task 22                    │
Task 24 (ChatInput URL) ─ depends on ─── Task 21                   │
                                                                    │
Task 25 (DecisionCard) ─────────────────────────────────────────────┤
Task 26 (ClaimSheet) ───────────────────────────────────────────────┤
Task 27 (pendingConfirmation) ──────────────────────────────────────┘

Task 28 (guardrails) ──── depends on ─── ALL above
Task 29 (memory) ──────── depends on ─── Task 28
Task 30 (verification) ── depends on ─── ALL above
```

## Parallelization Groups

These task groups can run as independent subagents:

| Group | Tasks | Dependencies |
|---|---|---|
| A: Foundation | 1, 2, 3, 4, 5 | None (all independent) |
| B: Theme | 6, 7, 8, 9, 10 | 6→7→8, 9→10 |
| C: Intelligence | 11, 12, 13 | 11→12→13, also needs Task 2 done |
| D: Galaxy | 14, 15, 16, 17 | 14+15→16→17 |
| E: Invite | 18, 19, 20 | Needs Task 1 done; 18→19 |
| F: Share | 21, 22, 23, 24 | Needs Task 4 done; 21→22→23, 21→24 |
| G: Booking | 25, 26, 27 | All independent within group |
| H: Finalize | 28, 29, 30 | Needs ALL above done |

**Optimal execution**: Groups A, B (6+9 parallel, then 7→8, 10), D (14+15 parallel), G can all start simultaneously. C starts after A completes (needs Task 2). E starts after Task 1. F starts after Task 4.
