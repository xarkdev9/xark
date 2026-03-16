"use client";

// XARK OS v2.0 — PEOPLE DOCK
// Extracted from Galaxy page. Renders personal chats (sanctuary spaces).
// Independent data fetching + real-time subscription for new messages.
// Includes Contact Picker API for inviting people.

import { useState, useEffect, useCallback, useRef } from "react";
import { motion } from "framer-motion";
import {
  fetchPersonalChats,
  getDemoPersonalChats,
} from "@/lib/awareness";
import type { PersonalChat } from "@/lib/awareness";
import { recencyLabel } from "@/lib/space-data";
import { supabase } from "@/lib/supabase";
import { ink, timing, layout, text } from "@/lib/theme";
import { useThemeContext } from "@/components/os/ThemeProvider";
import { Avatar } from "@/components/os/Avatar";
import { Whisper, dismissOnboardingWhisper } from "@/components/os/OnboardingWhispers";
import { fetchUnreadCounts } from "@/lib/unread";

interface PeopleDockProps {
  userId: string;
  userName: string;
  onPersonTap: (spaceId: string) => void;
}

export function PeopleDock({ userId, userName, onPersonTap }: PeopleDockProps) {
  const { isVibe } = useThemeContext();
  const [personalChats, setPersonalChats] = useState<PersonalChat[]>([]);
  const [unreadCounts, setUnreadCounts] = useState<Record<string, number>>({});
  const [mounted, setMounted] = useState(false);

  // Stabilized subscription ref
  const sanctuaryIdsRef = useRef<string>("");

  useEffect(() => {
    setMounted(true);
  }, []);

  // Fetch personal chats + unread counts on mount
  useEffect(() => {
    if (!userId) return;
    fetchPersonalChats(userId)
      .then((result) => setPersonalChats(result))
      .catch(() => setPersonalChats([]));
    fetchUnreadCounts()
      .then(setUnreadCounts)
      .catch(() => {});
  }, [userId]);

  // Real-time: refetch when user is added to a new space (sanctuary might appear)
  useEffect(() => {
    if (!userId) return;
    const channel = supabase
      .channel(`people:${userId}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "space_members",
          filter: `user_id=eq.${userId}`,
        },
        () => {
          fetchPersonalChats(userId)
            .then((result) => setPersonalChats(result))
            .catch(() => {});
        }
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [userId]);

  // Real-time: personal chat message updates — stabilized subscription
  useEffect(() => {
    if (!userId || personalChats.length === 0) return;
    const sanctuaryIds = personalChats.map((c) => c.spaceId);
    const sanctuaryKey = sanctuaryIds.sort().join(",");

    // Only re-subscribe when the actual set of space IDs changes
    if (sanctuaryKey === sanctuaryIdsRef.current) return;
    sanctuaryIdsRef.current = sanctuaryKey;

    const channel = supabase
      .channel(`people-chats:${userId}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "messages",
          filter: `space_id=in.(${sanctuaryIds.join(",")})`,
        },
        (payload) => {
          const msg = payload.new as { space_id: string; content: string; created_at: string };
          setPersonalChats((prev) =>
            prev
              .map((chat) =>
                chat.spaceId === msg.space_id
                  ? { ...chat, lastMessage: msg.content, lastActivityAt: new Date(msg.created_at).getTime() }
                  : chat
              )
              .sort((a, b) => b.lastActivityAt - a.lastActivityAt)
          );
        }
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [userId, personalChats]);

  const handleChatTap = useCallback((spaceId: string) => {
    dismissOnboardingWhisper("galaxy_tap");
    onPersonTap(spaceId);
  }, [onPersonTap]);

  const hasPersonalChats = personalChats.length > 0;

  return (
    <div className="px-6">
      <div className="mx-auto" style={{ maxWidth: layout.maxWidth }}>
        {/* ── Chat list ── */}
        {hasPersonalChats && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.6 }}
          >
            {personalChats.map((chat, index) => (
              <motion.div
                key={chat.spaceId}
                role="button"
                tabIndex={0}
                onClick={() => handleChatTap(chat.spaceId)}
                onKeyDown={(e) => { if (e.key === "Enter") handleChatTap(chat.spaceId); }}
                className="cursor-pointer outline-none"
                style={{ paddingBottom: "14px" }}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{
                  delay: 0.1 + index * timing.staggerDelay,
                  duration: 0.5,
                  ease: [0.22, 1, 0.36, 1],
                }}
              >
                <div className="flex items-center gap-4">
                  <Avatar name={chat.contactName} size={48} />
                  <div className="min-w-0 flex-1">
                    <div className="flex items-baseline justify-between">
                      <p style={{ ...text.listTitle, color: ink.primary }}>
                        {chat.contactName}
                      </p>
                      <div className="flex items-center gap-2">
                        <p style={{ ...text.timestamp, color: ink.tertiary }}>
                          {recencyLabel(new Date(chat.lastActivityAt))}
                        </p>
                        {(unreadCounts[chat.spaceId] ?? 0) > 0 && (
                          <span style={{
                            display: "inline-flex",
                            alignItems: "center",
                            justifyContent: "center",
                            minWidth: "18px",
                            height: "18px",
                            borderRadius: "9px",
                            padding: "0 5px",
                            fontSize: "11px",
                            fontWeight: 400,
                            color: "#fff",
                            backgroundColor: "#FF6B35",
                          }}>
                            {unreadCounts[chat.spaceId] > 99 ? "99+" : unreadCounts[chat.spaceId]}
                          </span>
                        )}
                      </div>
                    </div>
                    <p
                      style={{
                        ...text.recency,
                        color: ink.secondary,
                        whiteSpace: "nowrap",
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                      }}
                    >
                      {chat.lastMessage || "start a conversation"}
                    </p>
                  </div>
                </div>
              </motion.div>
            ))}

            <Whisper whisperKey="galaxy_tap" delay={2.5}>
              tap any chat to jump in
            </Whisper>
          </motion.div>
        )}

        {/* ── Empty state — warm, not hollow ── */}
        {!hasPersonalChats && mounted && (
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3, duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
            className="py-8"
          >
            <p style={{ ...text.listTitle, color: ink.primary }}>
              your people
            </p>
            <p
              className="mt-3"
              style={{ ...text.subtitle, color: ink.secondary }}
            >
              share a space link to start planning with friends
            </p>
          </motion.div>
        )}
      </div>
    </div>
  );
}
