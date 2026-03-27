"use client";

// XARK OS v2.0 — Shared Avatar Component
// First-letter fallback when no photo. No border (Zero-Box).
// shape="circle" (default, people) or "square" (plans, spaces in vibe mode).

import { colors, surface } from "@/lib/theme";

interface AvatarProps {
  name: string;
  photoUrl?: string;
  size?: number;
  shape?: "circle" | "square";
}

export function Avatar({ name, photoUrl, size = 28, shape = "circle" }: AvatarProps) {
  const radius = shape === "square" ? `${Math.round(size * 0.28)}px` : "50%";

  if (photoUrl) {
    return (
      <img
        src={photoUrl}
        alt=""
        style={{
          width: size,
          height: size,
          borderRadius: radius,
          objectFit: "cover",
          flexShrink: 0,
        }}
      />
    );
  }

  const letter = (name[0] ?? "?").toUpperCase();
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: radius,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: surface.recessed,
        flexShrink: 0,
      }}
    >
      <span
        style={{
          fontSize: size * 0.42,
          fontWeight: 400,
          color: colors.white,
          opacity: 0.4,
          letterSpacing: 0,
          lineHeight: 1,
        }}
      >
        {letter}
      </span>
    </div>
  );
}
