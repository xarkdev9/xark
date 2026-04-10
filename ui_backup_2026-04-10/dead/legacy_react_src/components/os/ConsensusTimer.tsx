"use client";

import { useState, useEffect, useRef } from "react";
import { colors, text as textTokens } from "@/lib/theme";

interface ConsensusTimerProps {
  deadline: string;
  onExpired?: () => void;
}

export function ConsensusTimer({ deadline, onExpired }: ConsensusTimerProps) {
  const [remaining, setRemaining] = useState("");
  const [expired, setExpired] = useState(false);

  // Store onExpired in a ref to avoid interval teardown on every render
  const onExpiredRef = useRef(onExpired);
  useEffect(() => {
    onExpiredRef.current = onExpired;
  }, [onExpired]);

  useEffect(() => {
    function tick() {
      const diff = new Date(deadline).getTime() - Date.now();
      if (diff <= 0) {
        setExpired(true);
        setRemaining("0:00");
        onExpiredRef.current?.();
        return false; // signal to stop
      }
      const totalSeconds = Math.ceil(diff / 1000);
      const minutes = Math.floor(totalSeconds / 60);
      const seconds = totalSeconds % 60;
      setRemaining(`${minutes}:${seconds.toString().padStart(2, "0")}`);
      return true; // signal to continue
    }

    // Run immediately
    const shouldContinue = tick();
    if (!shouldContinue) return;

    const interval = setInterval(() => {
      const cont = tick();
      if (!cont) clearInterval(interval);
    }, 1000);

    return () => clearInterval(interval);
  }, [deadline]);

  const color = expired ? colors.green : colors.gold;

  return (
    <span
      style={{
        ...textTokens.label,
        color,
        letterSpacing: "0.08em",
        animation: expired ? undefined : "consensusBreath 2s ease-in-out infinite",
      }}
    >
      <style>{`
        @keyframes consensusBreath {
          0%, 100% { opacity: 0.7; }
          50% { opacity: 1; }
        }
      `}</style>
      {expired ? "\u{1F512} ready to finalize" : `\u{1F512} locking in ${remaining}`}
    </span>
  );
}
