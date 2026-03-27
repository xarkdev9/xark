/**
 * Event Bus Port
 *
 * Contract for publishing and subscribing to engine events.
 * Implement this for any pub/sub system: Redis, NATS, Kafka,
 * RabbitMQ, AWS SNS/SQS, Google Pub/Sub, WebSocket broadcast,
 * Server-Sent Events, or in-process.
 *
 * Channels are typically space-scoped: "space:{spaceId}"
 * Subscribers receive events in real-time for multi-user sync.
 */

import type { EngineEvent } from "../models/types.js";

export type Unsubscribe = () => void;

export interface EventBusPort {
  /**
   * Publishes an event to a channel.
   * All subscribers on that channel receive it.
   */
  publish(channel: string, event: EngineEvent): Promise<void>;

  /**
   * Subscribes to events on a channel.
   * Returns an unsubscribe function.
   */
  subscribe(
    channel: string,
    handler: (event: EngineEvent) => void
  ): Promise<Unsubscribe>;

  /**
   * Publishes to multiple channels at once (e.g., space + user channels).
   * Default implementation calls publish() for each.
   */
  publishMany?(channels: string[], event: EngineEvent): Promise<void>;
}
