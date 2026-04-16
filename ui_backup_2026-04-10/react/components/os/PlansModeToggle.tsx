"use client";

import { useState, useEffect } from "react";

interface PlansModeToggleProps {
  mode: "category" | "timeline";
  onModeChange: (mode: "category" | "timeline") => void;
  hasItineraryItems: boolean; // Show timeline option only when itinerary items exist
}

export function PlansModeToggle({ mode, onModeChange, hasItineraryItems }: PlansModeToggleProps) {
  // Auto-switch to timeline when itinerary items first appear
  useEffect(() => {
    if (hasItineraryItems && mode === "category") {
      const savedMode = typeof window !== "undefined" ? localStorage.getItem("plans-mode") : null;
      if (!savedMode) {
        onModeChange("timeline");
      }
    }
  }, [hasItineraryItems]);

  const handleToggle = (newMode: "category" | "timeline") => {
    onModeChange(newMode);
    if (typeof window !== "undefined") {
      localStorage.setItem("plans-mode", newMode);
    }
  };

  const options = [
    { value: "category" as const, label: "By Category" },
    { value: "timeline" as const, label: "By Day" },
  ];

  return (
    <div
      style={{
        display: "flex",
        gap: 2,
        padding: 2,
        borderRadius: 10,
        background: "var(--hello-surface-recessed)",
        width: "fit-content",
        marginBottom: 16,
      }}
    >
      {options.map((opt) => {
        const isActive = mode === opt.value;
        const isDisabled = opt.value === "timeline" && !hasItineraryItems;
        return (
          <button
            key={opt.value}
            onClick={() => !isDisabled && handleToggle(opt.value)}
            disabled={isDisabled}
            style={{
              padding: "6px 14px",
              borderRadius: 8,
              border: "none",
              background: isActive ? "var(--hello-surface-chrome)" : "transparent",
              color: isDisabled
                ? "var(--hello-ink-tertiary)"
                : isActive
                  ? "var(--hello-ink-primary)"
                  : "var(--hello-ink-secondary)",
              fontSize: 12,
              fontWeight: 400,
              cursor: isDisabled ? "default" : "pointer",
              transition: "all 0.15s ease",
              opacity: isDisabled ? 0.4 : 1,
              fontFamily: "inherit",
            }}
          >
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}
