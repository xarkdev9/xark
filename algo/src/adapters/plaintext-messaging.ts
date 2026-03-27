/**
 * Plain Text Messaging Adapter
 *
 * Formats engine data as human-readable plain text.
 * Reference implementation — works for console, SMS, simple bots.
 *
 * For rich chat platforms, replace with:
 * - SlackMessagingAdapter (Block Kit)
 * - DiscordMessagingAdapter (Embeds)
 * - TelegramMessagingAdapter (HTML/Markdown)
 * - TeamsMessagingAdapter (Adaptive Cards)
 * - WhatsAppMessagingAdapter (Template messages)
 */

import type {
  MessagingPort,
  OutgoingMessage,
  IncomingMessage,
  EngineCommand,
  RankedItemSummary,
} from "../ports/messaging.js";
import type { BookableItem, GroupId, UserId } from "../models/types.js";

export class PlaintextMessagingAdapter implements MessagingPort {
  formatItem(item: BookableItem): OutgoingMessage {
    const state = String(item.state).toUpperCase();
    const owner = item.ownership
      ? ` | Owner: ${item.ownership.ownerId}`
      : "";
    return {
      text: `[${state}] ${item.title} (score: ${item.weightedScore})${owner}\n  ${item.description}`,
    };
  }

  formatRankedList(items: RankedItemSummary[]): OutgoingMessage {
    if (items.length === 0) {
      return { text: "No items ranked yet." };
    }

    const lines = items.map((item) => {
      const fav = item.isGroupFavorite ? " *GROUP FAVORITE*" : "";
      return `#${item.rank} ${item.title} — ${item.weightedScore} pts (${Math.round(item.agreementScore)}% agree)${fav}`;
    });

    return { text: `Ranked items:\n${lines.join("\n")}` };
  }

  formatLockNotification(item: BookableItem): OutgoingMessage {
    const owner = item.ownership?.ownerId ?? "unknown";
    const proof = item.commitmentProof?.value ?? item.bookingProof?.value ?? "";
    return {
      text: `LOCKED: "${item.title}" committed by ${owner}${proof ? ` (ref: ${proof})` : ""}`,
    };
  }

  formatEventNotification(event: {
    type: string;
    [key: string]: unknown;
  }): OutgoingMessage {
    const payload = event.payload as Record<string, unknown> | undefined;
    switch (event.type) {
      case "item_proposed":
        return { text: `New option proposed: "${payload?.title}"` };
      case "reaction_added":
        return {
          text: `${event.actorId} reacted (new score: ${payload?.newScore})`,
        };
      case "item_locked":
        return {
          text: `"${payload?.title}" has been locked by ${payload?.ownerId}`,
        };
      case "ownership_transferred":
        return {
          text: `"${payload?.title}" transferred: ${payload?.previousOwnerId} → ${payload?.newOwnerId}`,
        };
      case "task_created":
        return { text: `New task: "${payload?.title}"` };
      case "task_assigned":
        return {
          text: `Task "${payload?.title}" claimed by ${payload?.assigneeId}`,
        };
      default:
        return { text: `Event: ${event.type}` };
    }
  }

  /**
   * Parses simple text commands.
   * Format: "/command [args]"
   *
   * Supported:
   *   /love <itemTitle>     → react with LoveIt
   *   /works <itemTitle>    → react with WorksForMe
   *   /nope <itemTitle>     → react with NotForMe
   *   /lock <itemTitle>     → lock an item
   *   /rank                 → show ranked list
   *   /add <title>          → propose new item
   *   /task <title>         → create a task
   *   /claim <taskTitle>    → claim a task
   */
  parseCommand(message: IncomingMessage): EngineCommand | null {
    const text = message.text.trim();
    if (!text.startsWith("/")) return null;

    const spaceMatch = text.match(/\[(\S+)\]/);
    const groupId = (spaceMatch?.[1] ?? "default") as GroupId;
    const cleanText = text.replace(/\[\S+\]/, "").trim();

    const parts = cleanText.split(/\s+/);
    const command = parts[0]?.toLowerCase();
    const arg = parts.slice(1).join(" ");

    switch (command) {
      case "/love":
        return {
          type: "react",
          groupId,
          userId: message.userId as UserId,
          payload: { title: arg, reactionType: "love_it" },
        };
      case "/works":
        return {
          type: "react",
          groupId,
          userId: message.userId as UserId,
          payload: { title: arg, reactionType: "works_for_me" },
        };
      case "/nope":
        return {
          type: "react",
          groupId,
          userId: message.userId as UserId,
          payload: { title: arg, reactionType: "not_for_me" },
        };
      case "/lock":
        return {
          type: "lock",
          groupId,
          userId: message.userId as UserId,
          payload: { title: arg },
        };
      case "/rank":
        return {
          type: "rank",
          groupId,
          userId: message.userId as UserId,
          payload: {},
        };
      case "/add":
        return {
          type: "add_item",
          groupId,
          userId: message.userId as UserId,
          payload: { title: arg },
        };
      case "/task":
        return {
          type: "add_task",
          groupId,
          userId: message.userId as UserId,
          payload: { title: arg },
        };
      case "/claim":
        return {
          type: "claim_task",
          groupId,
          userId: message.userId as UserId,
          payload: { title: arg },
        };
      default:
        return null;
    }
  }
}
