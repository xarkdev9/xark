"use client";

import { usePathname, useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { useAuth } from "@/hooks/useAuth";
import { UserMenu } from "./UserMenu";

function GlobalUserMenuInner() {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const { user } = useAuth();

  if (pathname !== "/galaxy") return null;

  const userName = user?.displayName ?? searchParams.get("name") ?? "";
  const userId = user?.uid ?? "";

  if (!userName) return null;

  return <UserMenu userName={userName} userId={userId} />;
}

export function GlobalUserMenu() {
  return (
    <Suspense>
      <GlobalUserMenuInner />
    </Suspense>
  );
}
