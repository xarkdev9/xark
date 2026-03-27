/**
 * In-Memory Event Bus Adapter
 *
 * In-process pub/sub. Good for:
 * - Development and testing
 * - Single-process deployments
 * - Embedded use
 *
 * For multi-process/multi-server, replace with:
 * - RedisEventBusAdapter (Redis pub/sub)
 * - NatsEventBusAdapter (NATS)
 * - KafkaEventBusAdapter (Kafka)
 * - SseEventBusAdapter (Server-Sent Events to browser clients)
 * - WsEventBusAdapter (WebSocket broadcast)
 */

import type { EventBusPort, Unsubscribe } from "../ports/event-bus.js";
import type { EngineEvent } from "../models/types.js";

type Handler = (event: EngineEvent) => void;

export class MemoryEventBusAdapter implements EventBusPort {
  private channels = new Map<string, Set<Handler>>();

  async publish(channel: string, event: EngineEvent): Promise<void> {
    const handlers = this.channels.get(channel);
    if (!handlers) return;
    for (const handler of handlers) {
      try {
        handler(event);
      } catch {
        // Isolate subscriber failures — one bad handler must not block others
      }
    }
  }

  async subscribe(
    channel: string,
    handler: Handler
  ): Promise<Unsubscribe> {
    if (!this.channels.has(channel)) {
      this.channels.set(channel, new Set());
    }
    this.channels.get(channel)!.add(handler);

    return () => {
      this.channels.get(channel)?.delete(handler);
      if (this.channels.get(channel)?.size === 0) {
        this.channels.delete(channel);
      }
    };
  }

  async publishMany(channels: string[], event: EngineEvent): Promise<void> {
    for (const channel of channels) {
      await this.publish(channel, event);
    }
  }

  /** Returns the number of active subscriptions across all channels. */
  get subscriberCount(): number {
    let count = 0;
    for (const handlers of this.channels.values()) {
      count += handlers.size;
    }
    return count;
  }

  /** Removes all subscriptions. Useful for test teardown. */
  clear(): void {
    this.channels.clear();
  }
}
