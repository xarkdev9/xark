"use client";

// hello OS v2.0 — Spatial Category Navigator
// Unified spatial system: categories float in space.
// < 5 categories: Vision Pro style — static float with ambient drift.
// 5+ categories: rotatable sphere — drag to explore.
// One node per unique category. Photo from top-rated item.

import React, { useState, useEffect, useRef, useCallback, useMemo } from "react";
import { ink, surface } from "@/lib/theme";

interface CategoryNode {
  category: string;
  itemCount: number;
  votedCount: number;
  lockedCount: number;
  topImageUrl?: string;
  topTitle?: string;
  agreementScore: number;
}

interface CategorySphereProps {
  categories: CategoryNode[];
  onCategoryTap: (category: string) => void;
  containerSize?: number;
}

const DEG_TO_RAD = Math.PI / 180;
const normalize = (a: number) => { while (a > 180) a -= 360; while (a < -180) a += 360; return a; };

function rotatePoint(px: number, py: number, pz: number, rX: number, rY: number) {
  const cosY = Math.cos(rY); const sinY = Math.sin(rY);
  let x = px * cosY + pz * sinY;
  let z = -px * sinY + pz * cosY;
  const cosX = Math.cos(rX); const sinX = Math.sin(rX);
  const y = py * cosX - z * sinX;
  z = py * sinX + z * cosX;
  return { x, y, z };
}

// ── Vision Pro Layout: static positions for 1-4 items ──
function getVisionProPositions(count: number, w: number, h: number): { x: number; y: number }[] {
  const cx = w / 2;
  const cy = h / 2;
  if (count === 1) return [{ x: cx, y: cy }];
  if (count === 2) return [
    { x: cx - w * 0.18, y: cy },
    { x: cx + w * 0.18, y: cy },
  ];
  if (count === 3) return [
    { x: cx, y: cy - h * 0.16 },
    { x: cx - w * 0.2, y: cy + h * 0.14 },
    { x: cx + w * 0.2, y: cy + h * 0.14 },
  ];
  // 4
  return [
    { x: cx - w * 0.18, y: cy - h * 0.15 },
    { x: cx + w * 0.18, y: cy - h * 0.15 },
    { x: cx - w * 0.18, y: cy + h * 0.15 },
    { x: cx + w * 0.18, y: cy + h * 0.15 },
  ];
}

// ── Shared Node Renderer ──
function CategoryNodeView({
  cat, size, opacity, onClick, style, showBadge = true,
}: {
  cat: CategoryNode; size: number; opacity: number;
  onClick: () => void; style: React.CSSProperties; showBadge?: boolean;
}) {
  const pending = cat.itemCount - cat.votedCount;
  const allLocked = cat.lockedCount === cat.itemCount && cat.itemCount > 0;

  return (
    <div onClick={onClick} style={{ ...style, cursor: "pointer" }}>
      {/* Photo circle */}
      <div style={{
        width: size, height: size, borderRadius: "50%", overflow: "hidden",
        border: allLocked ? "2.5px solid var(--hello-green)"
          : pending > 0 ? "2px solid #FF6B35"
          : "2px solid rgba(255,255,255,0.5)",
        boxShadow: opacity > 0.5
          ? "0 4px 16px rgba(0,0,0,0.12), 0 2px 4px rgba(0,0,0,0.06)"
          : "0 1px 4px rgba(0,0,0,0.06)",
        background: surface.recessed,
      }}>
        {cat.topImageUrl ? (
          <img src={cat.topImageUrl} alt={cat.category}
            style={{ width: "100%", height: "100%", objectFit: "cover" }}
            draggable={false} />
        ) : (
          <div style={{
            width: "100%", height: "100%",
            display: "flex", alignItems: "center", justifyContent: "center",
            fontSize: Math.max(14, size * 0.28), color: ink.tertiary, fontWeight: 300,
          }}>
            {cat.itemCount}
          </div>
        )}
      </div>

      {/* Label */}
      <div style={{
        textAlign: "center", marginTop: 4,
        fontSize: "0.6875rem", fontWeight: 300,
        color: ink.primary, lineHeight: 1.2, letterSpacing: "0.02em",
        opacity: 0.8,
      }}>
        {cat.category}
      </div>

      {/* Count badge */}
      {showBadge && pending > 0 && (
        <div style={{
          position: "absolute", top: -2, right: -2,
          minWidth: 16, height: 16, borderRadius: "8px",
          backgroundColor: "#FF6B35", color: "#fff",
          fontSize: "9px", fontWeight: 400, padding: "0 4px",
          display: "flex", alignItems: "center", justifyContent: "center",
          boxShadow: "0 1px 3px rgba(212,83,107,0.4)",
        }}>
          {cat.itemCount}
        </div>
      )}

      {allLocked && (
        <div style={{
          position: "absolute", top: -2, right: -2,
          width: 16, height: 16, borderRadius: "50%",
          backgroundColor: "var(--hello-green)", color: "#fff",
          fontSize: "8px", display: "flex", alignItems: "center", justifyContent: "center",
        }}>
          ✓
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════
// VISION PRO MODE (< 5 categories)
// ═══════════════════════════════════════════

function VisionProFloat({ categories, onCategoryTap, containerSize }: CategorySphereProps & { containerSize: number }) {
  const [mounted, setMounted] = useState(false);
  const [time, setTime] = useState(0);
  const frameRef = useRef<number | null>(null);

  useEffect(() => {
    setMounted(true);
    const animate = () => {
      setTime(t => t + 0.008);
      frameRef.current = requestAnimationFrame(animate);
    };
    frameRef.current = requestAnimationFrame(animate);
    return () => { if (frameRef.current) cancelAnimationFrame(frameRef.current); };
  }, []);

  const height = containerSize * 0.7;
  const nodeSize = Math.min(containerSize * 0.22, 80);
  const positions = getVisionProPositions(categories.length, containerSize, height);

  if (!mounted) return <div style={{ width: containerSize, height }} />;

  return (
    <div style={{
      width: containerSize, height, position: "relative",
      margin: "0 auto",
    }}>
      {categories.map((cat, i) => {
        const base = positions[i];
        if (!base) return null;
        // Ambient drift — each node has unique phase
        const driftX = Math.sin(time + i * 1.8) * 3;
        const driftY = Math.cos(time * 0.7 + i * 2.3) * 4;

        return (
          <CategoryNodeView
            key={cat.category}
            cat={cat}
            size={nodeSize}
            opacity={1}
            onClick={() => onCategoryTap(cat.category)}
            style={{
              position: "absolute",
              left: base.x + driftX,
              top: base.y + driftY,
              width: nodeSize,
              transform: "translate(-50%, -50%)",
              transition: "left 0.3s, top 0.3s",
            }}
          />
        );
      })}
    </div>
  );
}

// ═══════════════════════════════════════════
// SPHERE MODE (5+ categories)
// ═══════════════════════════════════════════

function SphereRotate({ categories, onCategoryTap, containerSize }: CategorySphereProps & { containerSize: number }) {
  const [mounted, setMounted] = useState(false);
  const [rotation, setRotation] = useState({ x: 20, y: -30 });
  const [velocity, setVelocity] = useState({ x: 0, y: 0 });
  const [isDragging, setIsDragging] = useState(false);
  const lastPos = useRef({ x: 0, y: 0 });
  const frameRef = useRef<number | null>(null);
  const dragDistance = useRef(0);

  const sphereRadius = containerSize * 0.36;
  const cx = containerSize / 2;
  const cy = containerSize * 0.46;
  const nodeSize = containerSize * 0.15;

  const positions = useMemo(() => {
    const golden = (1 + Math.sqrt(5)) / 2;
    const angleInc = 2 * Math.PI / golden;
    return categories.map((_, i) => {
      const t = (i + 0.5) / Math.max(categories.length, 1);
      const phi = Math.acos(1 - 2 * t) * (180 / Math.PI);
      const theta = ((angleInc * i) * (180 / Math.PI)) % 360;
      return { theta, phi: 15 + (phi / 180) * 150 };
    });
  }, [categories.length]);

  const worldPositions = useMemo(() => {
    const rX = rotation.x * DEG_TO_RAD;
    const rY = rotation.y * DEG_TO_RAD;
    return positions.map((pos, index) => {
      const tR = pos.theta * DEG_TO_RAD;
      const pR = pos.phi * DEG_TO_RAD;
      const px = sphereRadius * Math.sin(pR) * Math.cos(tR);
      const py = sphereRadius * Math.cos(pR);
      const pz = sphereRadius * Math.sin(pR) * Math.sin(tR);
      const { x, y, z } = rotatePoint(px, py, pz, rX, rY);
      const depth = (z + sphereRadius) / (2 * sphereRadius);
      const scale = 0.4 + depth * 0.6;
      const fadeStart = -sphereRadius * 0.2;
      const fadeEnd = -sphereRadius * 0.7;
      let opacity = 1;
      if (z <= fadeStart) opacity = Math.max(0, (z - fadeEnd) / (fadeStart - fadeEnd));
      return { x, y, z, scale, opacity, zIndex: Math.round(1000 + z), index, depth };
    });
  }, [positions, rotation, sphereRadius]);

  useEffect(() => { setMounted(true); return () => { if (frameRef.current) cancelAnimationFrame(frameRef.current); }; }, []);

  useEffect(() => {
    if (!mounted) return;
    const animate = () => {
      if (!isDragging) {
        setVelocity(prev => {
          const nx = prev.x * 0.93;
          const ny = prev.y * 0.93;
          const idle = Math.abs(nx) < 0.04 && Math.abs(ny) < 0.04;
          const autoY = idle ? 0.15 : 0;
          setRotation(r => ({ x: normalize(r.x + nx), y: normalize(r.y + ny + autoY) }));
          return idle ? { x: 0, y: autoY } : { x: nx, y: ny };
        });
      }
      frameRef.current = requestAnimationFrame(animate);
    };
    frameRef.current = requestAnimationFrame(animate);
    return () => { if (frameRef.current) cancelAnimationFrame(frameRef.current); };
  }, [mounted, isDragging]);

  const onPointerDown = useCallback((e: React.PointerEvent) => {
    setIsDragging(true); setVelocity({ x: 0, y: 0 }); dragDistance.current = 0;
    lastPos.current = { x: e.clientX, y: e.clientY };
    (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
  }, []);
  const onPointerMove = useCallback((e: React.PointerEvent) => {
    if (!isDragging) return;
    const dx = e.clientX - lastPos.current.x;
    const dy = e.clientY - lastPos.current.y;
    dragDistance.current += Math.abs(dx) + Math.abs(dy);
    setRotation(r => ({ x: normalize(r.x - dy * 0.35), y: normalize(r.y + dx * 0.35) }));
    setVelocity({ x: -dy * 0.35, y: dx * 0.35 });
    lastPos.current = { x: e.clientX, y: e.clientY };
  }, [isDragging]);
  const onPointerUp = useCallback(() => setIsDragging(false), []);

  if (!mounted) return <div style={{ width: containerSize, height: containerSize * 0.88 }} />;

  return (
    <div
      style={{
        width: containerSize, height: containerSize * 0.88,
        position: "relative", margin: "0 auto",
        touchAction: "none", cursor: isDragging ? "grabbing" : "grab", userSelect: "none",
      }}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
    >
      {[...worldPositions].sort((a, b) => a.zIndex - b.zIndex).map((wp) => {
        const cat = categories[wp.index];
        if (!cat || wp.opacity < 0.05) return null;
        const ns = nodeSize * wp.scale;
        return (
          <CategoryNodeView
            key={cat.category}
            cat={cat}
            size={ns}
            opacity={wp.opacity}
            showBadge={wp.depth > 0.3}
            onClick={() => { if (dragDistance.current < 8) onCategoryTap(cat.category); }}
            style={{
              position: "absolute",
              left: cx + wp.x, top: cy + wp.y,
              width: ns,
              transform: "translate(-50%, -50%)",
              opacity: wp.opacity,
              zIndex: wp.zIndex,
              transition: isDragging ? "none" : "opacity 0.2s",
            }}
          />
        );
      })}
      <div style={{
        position: "absolute", bottom: 0, left: 0, right: 0,
        textAlign: "center", fontSize: "0.6875rem", fontWeight: 300,
        color: ink.tertiary, opacity: 0.4, letterSpacing: "0.06em",
      }}>
        drag to explore · tap to open
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════
// MAIN EXPORT — adaptive spatial system
// ═══════════════════════════════════════════

export function CategorySphere({ categories, onCategoryTap, containerSize: propSize }: CategorySphereProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [containerSize, setContainerSize] = useState(propSize ?? 340);

  useEffect(() => {
    if (propSize) { setContainerSize(propSize); return; }
    const measure = () => {
      const w = containerRef.current?.clientWidth || containerRef.current?.parentElement?.clientWidth || 340;
      setContainerSize(Math.min(w, 400));
    };
    // Delay measurement to ensure DOM is painted
    const t = setTimeout(measure, 50);
    window.addEventListener("resize", measure);
    return () => { clearTimeout(t); window.removeEventListener("resize", measure); };
  }, [propSize]);

  if (categories.length === 0) return null;

  const isVisionPro = categories.length < 5;
  const height = isVisionPro ? containerSize * 0.6 : containerSize * 0.88;

  return (
    <div ref={containerRef} style={{ width: "100%", minHeight: height }}>
      {isVisionPro ? (
        <VisionProFloat
          categories={categories}
          onCategoryTap={onCategoryTap}
          containerSize={containerSize}
        />
      ) : (
        <SphereRotate
          categories={categories}
          onCategoryTap={onCategoryTap}
          containerSize={containerSize}
        />
      )}
    </div>
  );
}
