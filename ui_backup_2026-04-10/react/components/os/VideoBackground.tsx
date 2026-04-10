"use client";

import { useEffect, useState, useRef } from "react";
import { useDeviceTier } from "@/hooks/useDeviceTier";

interface VideoBackgroundProps {
  videoSrc: string;
  posterSrc: string;
  children?: React.ReactNode;
}

export function VideoBackground({ videoSrc, posterSrc, children }: VideoBackgroundProps) {
  const tier = useDeviceTier();
  const [canPlay, setCanPlay] = useState(false);
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    if (tier === "low") return;

    if ("getBattery" in navigator) {
      (navigator as unknown as { getBattery: () => Promise<{ level: number }> })
        .getBattery()
        .then((battery) => {
          if (battery.level > 0.2) setCanPlay(true);
        })
        .catch(() => setCanPlay(true));
    } else {
      setCanPlay(true);
    }
  }, [tier]);

  return (
    <div className="absolute inset-0" style={{ zIndex: 1 }}>
      {canPlay ? (
        <video
          ref={videoRef}
          autoPlay
          muted
          loop
          playsInline
          poster={posterSrc}
          className="absolute inset-0 h-full w-full object-cover"
        >
          <source src={videoSrc} type="video/mp4" />
        </video>
      ) : (
        <img
          src={posterSrc}
          alt=""
          className="absolute inset-0 h-full w-full object-cover"
        />
      )}
      {children}
    </div>
  );
}
