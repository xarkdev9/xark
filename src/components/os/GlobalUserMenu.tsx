"use client";

import { usePathname } from "next/navigation";
import { Suspense } from "react";
import { UserMenu } from "./UserMenu";

export function GlobalUserMenu() {
  const pathname = usePathname();
  // Only show on galaxy (home screen) — not on login or inside spaces
  if (pathname !== "/galaxy") return null;
  return (
    <Suspense>
      <UserMenu />
    </Suspense>
  );
}
