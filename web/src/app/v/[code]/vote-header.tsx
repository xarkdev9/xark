"use client";

import { useState, useEffect } from "react";

interface VoteHeaderProps {
  tripName: string;
  memberCount: number;
}

export default function VoteHeader({ tripName, memberCount }: VoteHeaderProps) {
  const [name, setName] = useState("");

  useEffect(() => {
    const saved = localStorage.getItem("hello_voter_name");
    if (saved) setName(saved);
  }, []);

  function handleNameChange(e: React.ChangeEvent<HTMLInputElement>) {
    const val = e.target.value;
    setName(val);
    if (val.trim()) {
      localStorage.setItem("hello_voter_name", val.trim());
    }
  }

  return (
    <header
      style={{
        position: "sticky",
        top: 0,
        zIndex: 10,
        backdropFilter: "blur(14px)",
        WebkitBackdropFilter: "blur(14px)",
        backgroundColor: "rgba(255, 255, 255, 0.70)",
        borderBottom: "1px solid rgba(0, 0, 0, 0.06)",
        padding: "20px 24px",
      }}
    >
      <h1
        style={{
          fontFamily: "var(--font-inter), Inter, sans-serif",
          fontSize: "28px",
          fontWeight: 400,
          color: "var(--hello-white, #111111)",
          margin: 0,
          lineHeight: 1.2,
        }}
      >
        {tripName}
      </h1>
      <p
        style={{
          fontFamily: "var(--font-inter), Inter, sans-serif",
          fontSize: "14px",
          fontWeight: 400,
          color: "var(--hello-ink-secondary, #6B6B78)",
          margin: "4px 0 16px 0",
        }}
      >
        {memberCount} {memberCount === 1 ? "member" : "members"}
      </p>
      <input
        type="text"
        placeholder="What's your name?"
        value={name}
        onChange={handleNameChange}
        style={{
          width: "100%",
          boxSizing: "border-box",
          fontFamily: "var(--font-inter), Inter, sans-serif",
          fontSize: "16px",
          fontWeight: 400,
          color: "var(--hello-white, #111111)",
          backgroundColor: "rgba(0, 0, 0, 0.04)",
          border: "1px solid rgba(0, 0, 0, 0.08)",
          borderRadius: "12px",
          padding: "12px 16px",
          outline: "none",
        }}
      />
    </header>
  );
}
