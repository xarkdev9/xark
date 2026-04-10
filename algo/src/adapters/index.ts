/**
 * Adapters — reference implementations of all ports.
 *
 * All adapters are zero-dependency and work out of the box.
 * Replace any adapter with a production implementation
 * without touching the service layer.
 */

export { MemoryPersistenceAdapter } from "./memory-persistence.js";
export { PostgresPersistenceAdapter } from "./postgres-persistence.js";
export { MemoryEventBusAdapter } from "./memory-event-bus.js";
export { MemoryCacheAdapter } from "./memory-cache.js";
export { NoopAuthAdapter } from "./noop-auth.js";
export { PlaintextMessagingAdapter } from "./plaintext-messaging.js";
