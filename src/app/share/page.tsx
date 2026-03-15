"use client";

import { useSearchParams, useRouter } from "next/navigation";
import { Suspense, useState } from "react";
import { SpacePicker } from "@/components/os/SpacePicker";
import { colors, text, ink } from "@/lib/theme";
import { getSupabaseToken } from "@/lib/supabase";

function ShareContent() {
  const params = useSearchParams();
  const router = useRouter();
  const [saving, setSaving] = useState(false);

  const title = params.get("title") || "";
  const sharedText = params.get("text") || "";
  const url = params.get("url") || "";

  const handleSelect = async (spaceId: string) => {
    setSaving(true);
    try {
      const token = getSupabaseToken();
      await fetch("/api/og", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          url,
          title: title || sharedText.slice(0, 100),
          text: sharedText,
          spaceId,
          insertAsItem: true,
        }),
      });
    } catch { /* proceed to space regardless */ }
    router.push(`/space/${spaceId}`);
  };

  return (
    <div style={{ minHeight: "100dvh", background: colors.void }}>
      <div style={{ padding: "calc(env(safe-area-inset-top, 0px) + 48px) 24px 16px" }}>
        <p style={{ ...text.body, color: ink.primary }}>
          {url ? `sharing: ${title || url}` : `sharing: ${title || sharedText.slice(0, 50)}`}
        </p>
        {saving && (
          <p style={{ ...text.recency, color: ink.tertiary, marginTop: 8 }}>
            adding...
          </p>
        )}
      </div>
      {!saving && <SpacePicker onSelect={handleSelect} />}
    </div>
  );
}

export default function SharePage() {
  return (
    <Suspense>
      <ShareContent />
    </Suspense>
  );
}
