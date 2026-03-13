"use client";

import { usePathname } from "next/navigation";
import { Suspense } from "react";
import { ControlCaret } from "./ControlCaret";

export function GlobalCaret() {
  const pathname = usePathname();
  // The dot doesn't exist during login — only after the user has entered
  if (pathname === "/login" || pathname === "/") return null;
  return (
    <Suspense>
      <ControlCaret />
    </Suspense>
  );
}
