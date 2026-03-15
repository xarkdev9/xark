"use client";

// XARK OS v2.0 — GALAXY LAYOUT REGISTRY
// Layout registry. Components know nothing about layout — parent arranges them.
// Two layouts: stream (vertical stack), split (side-by-side).

import { ReactNode } from "react";

export type LayoutName = "stream" | "split";

interface GalaxyLayoutProps {
  layout: LayoutName;
  awarenessStream: ReactNode;
  peopleDock: ReactNode;
}

// StreamLayout: (default) full-width vertical: people on top, awareness below
function StreamLayout({ awarenessStream, peopleDock }: Omit<GalaxyLayoutProps, "layout">) {
  return (
    <div style={{ display: "flex", flexDirection: "column", minHeight: "100dvh" }}>
      <div style={{ flex: 1, overflowY: "auto", paddingBottom: "160px" }}>
        {peopleDock}
        <div style={{ marginTop: "24px" }}>
          {awarenessStream}
        </div>
      </div>
    </div>
  );
}

// SplitLayout: side-by-side: people (private chats) on LEFT, awareness on RIGHT
// NOTE: Gradient separator line — NOT a border (Zero Box doctrine).
function SplitLayout({ awarenessStream, peopleDock }: Omit<GalaxyLayoutProps, "layout">) {
  return (
    <div style={{ display: "flex", minHeight: "100dvh" }}>
      <div style={{ flex: 1, overflowY: "auto", paddingBottom: "160px" }}>
        {peopleDock}
      </div>
      <div
        style={{
          width: "1px",
          background: `linear-gradient(180deg, transparent, rgba(var(--xark-white-rgb), 0.06), transparent)`,
        }}
      />
      <div style={{ flex: 1, overflowY: "auto", paddingBottom: "160px" }}>
        {awarenessStream}
      </div>
    </div>
  );
}

const LAYOUTS: Record<LayoutName, typeof StreamLayout> = {
  stream: StreamLayout,
  split: SplitLayout,
};

export function GalaxyLayout({ layout, ...props }: GalaxyLayoutProps) {
  const Layout = LAYOUTS[layout];
  return <Layout {...props} />;
}
