"use client";

import { useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { colors, text, ink } from "@/lib/theme";
import { setSupabaseToken } from "@/lib/supabase";

export default function JoinPage() {
  const { token } = useParams<{ token: string }>();
  const router = useRouter();
  const [name, setName] = useState("");
  const [error, setError] = useState("");
  const [joining, setJoining] = useState(false);

  const handleJoin = async () => {
    if (!name.trim() || joining) return;
    setJoining(true);
    setError("");

    try {
      const res = await fetch("/api/join", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token, displayName: name.trim() }),
      });

      const data = await res.json();
      if (!res.ok) {
        setError(data.error || "could not join");
        setJoining(false);
        return;
      }

      setSupabaseToken(data.token);
      localStorage.setItem("xark-user", JSON.stringify(data.user));
      router.push(`/space/${data.spaceId}`);
    } catch {
      setError("something went wrong");
      setJoining(false);
    }
  };

  return (
    <div
      style={{
        minHeight: "100dvh",
        background: colors.void,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: "0 32px",
        gap: 24,
      }}
    >
      <p style={{ ...text.body, color: ink.secondary }}>
        join the conversation
      </p>

      <input
        type="text"
        placeholder="your name"
        value={name}
        onChange={(e) => setName(e.target.value)}
        onKeyDown={(e) => e.key === "Enter" && handleJoin()}
        autoFocus
        style={{
          ...text.body,
          color: ink.primary,
          backgroundColor: "transparent",
          border: "none",
          borderBottom: `1px solid ${ink.tertiary}`,
          padding: "8px 0",
          width: "100%",
          maxWidth: 280,
          textAlign: "center",
          outline: "none",
        }}
      />

      {error && (
        <p style={{ ...text.label, color: colors.orange }}>{error}</p>
      )}

      <p
        onClick={handleJoin}
        style={{
          ...text.body,
          color: joining ? ink.tertiary : ink.primary,
          cursor: joining ? "default" : "pointer",
        }}
      >
        {joining ? "joining..." : "enter"}
      </p>
    </div>
  );
}
