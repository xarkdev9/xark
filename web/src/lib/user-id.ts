// XARK OS v2.0 — User ID Utilities
// Centralizes user ID format logic. Replaces 14 hardcoded prefix instances.

export type UserIdType = "name" | "phone";

const PREFIXES: Record<UserIdType, string> = {
  name: "name_",
  phone: "phone_",
};

export function makeUserId(type: UserIdType, value: string): string {
  return `${PREFIXES[type]}${value}`;
}

export function extractDisplayName(userId: string): string {
  for (const prefix of Object.values(PREFIXES)) {
    if (userId.startsWith(prefix)) return userId.slice(prefix.length);
  }
  // Legacy "user_" prefix from ai-grounding.ts
  if (userId.startsWith("user_")) return userId.slice(5);
  return userId;
}

export function getUserIdType(userId: string): UserIdType | "unknown" {
  for (const [type, prefix] of Object.entries(PREFIXES)) {
    if (userId.startsWith(prefix)) return type as UserIdType;
  }
  return "unknown";
}
