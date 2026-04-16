"use client";

import { useEffect, useState, useMemo } from "react";
import { supabase } from "@/lib/supabase";
import { text, colors } from "@/lib/theme";
import { useReactions } from "@/hooks/useReactions";
import { motion } from "framer-motion";

interface PollItem {
  id: string;
  title: string;
  agreement_score: number;
  weighted_score: number;
}

interface InlinePollProps {
  groupId: string;
  pollId: string;
  title: string;
}

export function InlinePoll({ groupId, pollId, title }: InlinePollProps) {
  const [items, setItems] = useState<PollItem[]>([]);
  const { react, isReacting } = useReactions();

  // Load items on mount
  useEffect(() => {
    supabase
      .from("decision_items")
      .select("id, title, agreement_score, weighted_score, metadata")
      .eq("group_id", groupId)
      // JSON filter: metadata->>search_batch = pollId
      .filter("metadata->>search_batch", "eq", pollId)
      .then(({ data }) => {
        if (data) setItems(data as PollItem[]);
      });
  }, [groupId, pollId]);

  // Real-time subscription to decision items
  useEffect(() => {
    const channel = supabase
      .channel(`poll:${pollId}`)
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "decision_items",
          filter: `group_id=eq.${groupId}`,
        },
        (payload) => {
          const newItem = payload.new as Record<string, any>;
          if (newItem && newItem.metadata?.search_batch === pollId) {
            setItems((prev) => {
              const exists = prev.find((i) => i.id === newItem.id);
              if (exists) {
                return prev.map((i) => (i.id === newItem.id ? (newItem as PollItem) : i));
              }
              return [...prev, newItem as PollItem];
            });
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [groupId, pollId]);

  // Calculate percentages based on weighted_score (+1 per vote)
  const totalVotes = useMemo(() => {
    return items.reduce((sum, item) => sum + Math.max(0, item.weighted_score), 0);
  }, [items]);

  const sortedItems = useMemo(() => {
    return [...items].sort((a, b) => b.weighted_score - a.weighted_score);
  }, [items]);

  const winningOption = sortedItems.length > 0 && totalVotes > 0 ? sortedItems[0] : null;

  if (items.length === 0) return null;

  return (
    <div
      style={{
        backgroundColor: "rgba(255, 255, 255, 0.9)",
        borderRadius: "20px",
        padding: "16px 20px",
        width: "100%",
        maxWidth: "340px",
        borderLeft: `3px solid ${colors.accent}`,
        boxShadow: "0 4px 12px rgba(0,0,0,0.03)",
        display: "flex",
        flexDirection: "column",
        gap: "16px",
      }}
    >
      {/* Header */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h4 style={{ ...text.body, fontWeight: 500, margin: 0, color: "#111" }}>{title}</h4>
        <div
          style={{
            ...text.hint,
            color: colors.accent,
            padding: "2px 8px",
            borderRadius: "12px",
            border: `1px solid ${colors.accent}40`,
            fontSize: "10px",
            fontWeight: 500,
            letterSpacing: "0.05em",
          }}
        >
          LIVE
        </div>
      </div>

      {/* Options */}
      <div style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
        {sortedItems.map((item) => {
          const votes = Math.max(0, item.weighted_score);
          const percent = totalVotes > 0 ? Math.round((votes / totalVotes) * 100) : 0;
          return (
            <motion.div
              key={item.id}
              onClick={() => react(item.id, "love_it")}
              whileTap={{ scale: 0.98 }}
              style={{
                cursor: "pointer",
                padding: "10px",
                borderRadius: "12px",
                position: "relative",
                overflow: "hidden",
                border: "1px solid rgba(0,0,0,0.04)",
                backgroundColor: "transparent",
              }}
            >
              {/* Progress Background */}
              <div
                style={{
                  position: "absolute",
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: "100%",
                  backgroundColor: "#F0F0F0",
                  zIndex: 0,
                }}
              />
              
              {/* Filled Bar */}
              <motion.div
                initial={{ width: 0 }}
                animate={{ width: `${percent}%` }}
                transition={{ duration: 0.5, ease: "easeOut" }}
                style={{
                  position: "absolute",
                  left: 0,
                  top: 0,
                  bottom: 0,
                  backgroundColor: colors.accent,
                  opacity: 0.8,
                  zIndex: 1,
                  borderRadius: "12px 0 0 12px",
                }}
              />

              {/* Text Layer (on top of bars) */}
              <div
                style={{
                  position: "relative",
                  zIndex: 2,
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                }}
              >
                <span
                  style={{
                    ...text.body,
                    fontSize: "15px",
                    fontWeight: 400,
                    margin: 0,
                    color: "#111",
                    textShadow: "0 0 10px rgba(255,255,255,0.7)",
                  }}
                >
                  {item.title}
                </span>
                <span style={{ ...text.body, fontSize: "14px", fontWeight: 500, color: "#111" }}>
                  {percent}%
                </span>
              </div>
            </motion.div>
          );
        })}
      </div>

      {/* Footer */}
      <div
        style={{
          borderTop: "1px solid rgba(0,0,0,0.06)",
          paddingTop: "12px",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          ...text.hint,
        }}
      >
        <span style={{ color: colors.accent, fontWeight: 500 }}>
          {winningOption ? `🏆 ${winningOption.title} is winning` : "Tap an option to vote"}
        </span>
        <span style={{ opacity: 0.5 }}>
          {totalVotes} vote{totalVotes === 1 ? "" : "s"} total
        </span>
      </div>
    </div>
  );
}
