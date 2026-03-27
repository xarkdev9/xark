// XARK OS v2.0 — Reactions Hook
// Drives PossibilityHorizon voting surface.
// One reaction per user per item. Last wins.
// Uses auth.jwt()->>'sub' inside SECURITY DEFINER RPCs.

import { useState, useCallback } from "react";
import { supabase, getSupabaseToken } from "@/lib/supabase";

export type ReactionType = "love_it" | "works_for_me" | "not_for_me";

interface UseReactionsResult {
  react: (itemId: string, reaction: ReactionType) => Promise<boolean>;
  unreact: (itemId: string) => Promise<boolean>;
  getUserReaction: (
    itemId: string,
    userId: string
  ) => Promise<ReactionType | null>;
  batchGetUserReactions: (
    itemIds: string[],
    userId: string
  ) => Promise<Record<string, ReactionType>>;
  isReacting: boolean;
}

export function useReactions(): UseReactionsResult {
  const [isReacting, setIsReacting] = useState(false);

  const react = useCallback(async (itemId: string, reaction: ReactionType): Promise<boolean> => {
    // Guard: JWT must be set for RPC to work
    if (!getSupabaseToken()) {
      console.warn("[xark-vote] no JWT set — vote will not persist");
      return false;
    }

    setIsReacting(true);
    try {
      const { error } = await supabase.rpc("react_to_item", {
        p_item_id: itemId,
        p_signal: reaction,
      });
      if (error) {
        console.error("[xark-vote] react failed:", error.message);
        return false;
      }
      return true;
    } catch (err) {
      console.error("[xark-vote] react error:", err);
      return false;
    } finally {
      setIsReacting(false);
    }
  }, []);

  const unreact = useCallback(async (itemId: string): Promise<boolean> => {
    if (!getSupabaseToken()) {
      console.warn("[xark-vote] no JWT set — unreact will not persist");
      return false;
    }

    setIsReacting(true);
    try {
      const { error } = await supabase.rpc("unreact_to_item", {
        p_item_id: itemId,
      });
      if (error) {
        console.error("[xark-vote] unreact failed:", error.message);
        return false;
      }
      return true;
    } catch (err) {
      console.error("[xark-vote] unreact error:", err);
      return false;
    } finally {
      setIsReacting(false);
    }
  }, []);

  const getUserReaction = useCallback(
    async (itemId: string, userId: string): Promise<ReactionType | null> => {
      try {
        const { data } = await supabase
          .from("reactions")
          .select("signal")
          .eq("item_id", itemId)
          .eq("user_id", userId)
          .single();

        return (data?.signal as ReactionType) ?? null;
      } catch {
        return null;
      }
    },
    []
  );

  const batchGetUserReactions = useCallback(
    async (
      itemIds: string[],
      userId: string
    ): Promise<Record<string, ReactionType>> => {
      if (itemIds.length === 0) return {};
      try {
        const { data } = await supabase
          .from("reactions")
          .select("item_id, signal")
          .eq("user_id", userId)
          .in("item_id", itemIds);

        const result: Record<string, ReactionType> = {};
        if (data) {
          for (const row of data) {
            result[row.item_id] = row.signal as ReactionType;
          }
        }
        return result;
      } catch {
        return {};
      }
    },
    []
  );

  return { react, unreact, getUserReaction, batchGetUserReactions, isReacting };
}
