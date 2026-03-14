"use client";

import { useState, useEffect } from "react";

export type DeviceTier = "high" | "low";

export function useDeviceTier(): DeviceTier {
  const [tier, setTier] = useState<DeviceTier>("high");

  useEffect(() => {
    const isLow =
      (navigator.deviceMemory !== undefined && navigator.deviceMemory <= 2) ||
      (navigator.hardwareConcurrency !== undefined && navigator.hardwareConcurrency <= 4) ||
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    if (isLow) setTier("low");
  }, []);

  return tier;
}
