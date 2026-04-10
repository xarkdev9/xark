"use client";

import { usePathname } from "next/navigation";
import { Suspense } from "react";
import { ControlCaret } from "./ControlCaret";

export function GlobalCaret() {
  const pathname = usePathname();
  // ControlCaret hidden on login, home, landing, and ad pages
  if (pathname === "/login" || pathname === "/" || pathname === "/ad" || pathname === "/land") return null;
  return (
    <Suspense>
      <ControlCaret />
    </Suspense>
  );
}
