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
    lifetimeHours: 720,
    example: "san diego spring break",
  },
  buy_together: {
    id: "buy_together",
    label: "buy together",
    categories: ["product", "store"],
    lifetimeHours: 168,
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
