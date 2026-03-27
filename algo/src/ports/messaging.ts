/**
 * Messaging Port
 *
 * Contract for integrating with chat platforms.
 * Implement this for: Slack, Discord, WhatsApp, Telegram,
 * Microsoft Teams, iMessage (via shortcuts), LINE, WeChat, etc.
 *
 * Two responsibilities:
 * 1. Format engine data for display in the platform (outgoing)
 * 2. Parse user messages into engine commands (incoming)
 *
 * The service calls formatX() methods to build messages,
 * then sends them via the platform's own SDK. This port
 * only handles format/parse — not transport.
 */

import type { BookableItem, SpaceId, UserId } from "../models/types.js";

/**
 * An outgoing message to be sent to a chat platform.
 * `text` is always set (plain text fallback).
 * `richContent` is platform-specific (Slack blocks, Discord embeds, etc.).
 */
export interface OutgoingMessage {
  text: string;
  richContent?: unknown;
}

/**
 * An incoming message received from a chat platform.
 */
export interface IncomingMessage {
  platform: string;
  channelId: string;
  userId: string;
  text: string;
  metadata?: Record<string, unknown>;
}

/**
 * A parsed engine command extracted from a chat message.
 */
export type EngineCommandType =
  | "react"
  | "lock"
  | "transfer"
  | "add_item"
  | "list_items"
  | "rank"
  | "add_task"
  | "claim_task";

export interface EngineCommand {
  type: EngineCommandType;
  spaceId: SpaceId;
  userId: UserId;
  payload: Record<string, unknown>;
}

/**
 * Ranked item summary for display formatting.
 */
export interface RankedItemSummary {
  rank: number;
  title: string;
  weightedScore: number;
  agreementScore: number;
  isGroupFavorite: boolean;
}

export interface MessagingPort {
  /**
   * Formats a decision item for display in chat.
   */
  formatItem(item: BookableItem): OutgoingMessage;

  /**
   * Formats a ranked list of items for display.
   */
  formatRankedList(items: RankedItemSummary[]): OutgoingMessage;

  /**
   * Formats a lock/commitment notification.
   */
  formatLockNotification(item: BookableItem): OutgoingMessage;

  /**
   * Formats any engine event as a notification.
   */
  formatEventNotification(event: {
    type: string;
    [key: string]: unknown;
  }): OutgoingMessage;

  /**
   * Parses an incoming chat message into an engine command.
   * Returns null if the message is not a recognized command.
   */
  parseCommand(message: IncomingMessage): EngineCommand | null;
}
