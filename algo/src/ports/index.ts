/**
 * Ports — the interfaces your adapters implement.
 *
 * Think of ports as the "shape of the socket".
 * Adapters are the "plugs" that fit into them.
 */

export type { PersistencePort } from "./persistence.js";
export { VersionConflictError } from "./persistence.js";

export type { EventBusPort, Unsubscribe } from "./event-bus.js";

export type { AuthPort, Identity, Action } from "./auth.js";

export type { CachePort } from "./cache.js";

export type {
  MessagingPort,
  OutgoingMessage,
  IncomingMessage,
  EngineCommand,
  EngineCommandType,
  RankedItemSummary,
} from "./messaging.js";
