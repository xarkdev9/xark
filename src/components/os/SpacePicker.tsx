"use client";

import { useEffect, useState } from "react";
import { text, ink } from "@/lib/theme";
import { fetchSpaceList } from "@/lib/space-data";
import type { SpaceListItem } from "@/lib/space-data";
import { Avatar } from "@/components/os/Avatar";

interface SpacePickerProps {
  userId?: string;
  onSelect: (spaceId: string, spaceTitle: string) => void;
}

export function SpacePicker({ userId, onSelect }: SpacePickerProps) {
  const [spaces, setSpaces] = useState<SpaceListItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchSpaceList(userId)
      .then((result) => {
        setSpaces(result);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, [userId]);

  if (loading) {
    return (
      <div style={{ padding: "24px" }}>
        <p style={{ ...text.recency, color: ink.tertiary }}>loading spaces...</p>
      </div>
    );
  }

  if (spaces.length === 0) {
    return (
      <div style={{ padding: "24px" }}>
        <p style={{ ...text.body, color: ink.secondary }}>no spaces yet</p>
      </div>
    );
  }

  return (
    <div style={{ padding: "16px 0" }}>
      <p style={{ ...text.label, color: ink.tertiary, padding: "0 24px", marginBottom: 12 }}>
        pick a space
      </p>
      {spaces.map((space) => (
        <div
          key={space.id}
          role="button"
          tabIndex={0}
          onClick={() => onSelect(space.id, space.title)}
          onKeyDown={(e) => { if (e.key === "Enter") onSelect(space.id, space.title); }}
          className="cursor-pointer outline-none"
          style={{ padding: "12px 24px" }}
        >
          <div className="flex items-center gap-3">
            <Avatar name={space.title} size={32} />
            <div>
              <p style={{ ...text.body, color: ink.primary }}>{space.title}</p>
              <p style={{ ...text.recency, color: ink.tertiary }}>
                {space.members.map((m) => m.displayName).join(", ")}
              </p>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
