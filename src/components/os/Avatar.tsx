"use client";

// XARK OS v2.0 — Shared Avatar Component
// First-letter fallback when no photo. No border (Zero-Box).

import { colors } from "@/lib/theme";

interface AvatarProps {
  name: string;
  photoUrl?: string;
  size?: number;
}

export function Avatar({ name, photoUrl, size = 28 }: AvatarProps) {
  if (photoUrl) {
    return (
      <img
        src={photoUrl}
        alt=""
        style={{
          width: size,
          height: size,
          borderRadius: "50%",
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
        borderRadius: "50%",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: "rgba(var(--xark-white-rgb), 0.08)",
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
