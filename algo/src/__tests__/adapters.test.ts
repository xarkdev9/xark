import { describe, it, expect, beforeEach } from "vitest";
import { MemoryPersistenceAdapter } from "../adapters/memory-persistence.js";
import { MemoryEventBusAdapter } from "../adapters/memory-event-bus.js";
import { MemoryCacheAdapter } from "../adapters/memory-cache.js";
import { NoopAuthAdapter } from "../adapters/noop-auth.js";
import { PlaintextMessagingAdapter } from "../adapters/plaintext-messaging.js";
import { VersionConflictError } from "../ports/persistence.js";
import { BookableItemState } from "../models/types.js";
import type {
  BookableItem,
  DecisionSpace,
  EngineEvent,
  ItemId,
  SpaceId,
  UserId,
  GroupId,
  Task,
  TaskId,
} from "../models/types.js";

function makeItem(overrides: Partial<BookableItem> = {}): BookableItem {
  return {
    id: "item_1" as ItemId,
    spaceId: "space_1" as SpaceId,
    groupId: "space_1" as GroupId,
    title: "Test Item",
    description: "",
    category: "hotel",
    state: BookableItemState.Proposed,
    proposedBy: "u1" as UserId,
    proposedAt: 1000,
    reactions: [],
    weightedScore: 0,
    commitmentProof: null,
    bookingProof: null,
    ownership: null,
    ownershipHistory: [],
    lockedAt: null,
    version: 1,
    metadata: {},
    ...overrides,
  };
}

describe("MemoryPersistenceAdapter", () => {
  let adapter: MemoryPersistenceAdapter;

  beforeEach(() => {
    adapter = new MemoryPersistenceAdapter();
  });

  it("saves and retrieves items", async () => {
    const item = makeItem();
    await adapter.saveItem(item);
    const retrieved = await adapter.getItem("item_1" as ItemId);
    expect(retrieved).toBeDefined();
    expect(retrieved!.title).toBe("Test Item");
  });

  it("returns undefined for non-existent items", async () => {
    const result = await adapter.getItem("nonexistent" as ItemId);
    expect(result).toBeUndefined();
  });

  it("returns items by space", async () => {
    await adapter.saveItem(makeItem({ id: "a" as ItemId }));
    await adapter.saveItem(
      makeItem({ id: "b" as ItemId, spaceId: "space_2" as SpaceId })
    );

    const items = await adapter.getItemsBySpace("space_1" as SpaceId);
    expect(items).toHaveLength(1);
    expect(items[0]!.id).toBe("a");
  });

  it("deletes items", async () => {
    await adapter.saveItem(makeItem());
    await adapter.deleteItem("item_1" as ItemId);
    const result = await adapter.getItem("item_1" as ItemId);
    expect(result).toBeUndefined();
  });

  it("throws VersionConflictError on stale version", async () => {
    await adapter.saveItem(makeItem({ version: 2 }));

    await expect(
      adapter.saveItem(makeItem({ version: 1 }))
    ).rejects.toThrow(VersionConflictError);
  });

  it("allows saving with higher version", async () => {
    await adapter.saveItem(makeItem({ version: 1 }));
    await adapter.saveItem(makeItem({ version: 2 }));
    const item = await adapter.getItem("item_1" as ItemId);
    expect(item!.version).toBe(2);
  });

  it("returns copies, not references", async () => {
    const item = makeItem();
    await adapter.saveItem(item);
    const retrieved = await adapter.getItem("item_1" as ItemId);
    retrieved!.title = "Modified";

    const again = await adapter.getItem("item_1" as ItemId);
    expect(again!.title).toBe("Test Item");
  });

  it("manages spaces", async () => {
    const space: DecisionSpace = {
      id: "s1" as SpaceId,
      name: "Trip",
      members: [],
      config: {} as any,
      createdAt: 1000,
    };

    await adapter.saveSpace(space);
    const retrieved = await adapter.getSpace("s1" as SpaceId);
    expect(retrieved!.name).toBe("Trip");

    const all = await adapter.getAllSpaces();
    expect(all).toHaveLength(1);

    await adapter.deleteSpace("s1" as SpaceId);
    const deleted = await adapter.getSpace("s1" as SpaceId);
    expect(deleted).toBeUndefined();
  });

  it("manages tasks", async () => {
    const task: Task = {
      id: "task_1" as TaskId,
      groupId: "space_1" as GroupId,
      title: "Bring snacks",
      description: "",
      state: "created" as any,
      createdBy: "u1" as UserId,
      createdAt: 1000,
      assignee: null,
      assignedAt: null,
    };

    await adapter.saveTask(task);
    const retrieved = await adapter.getTask("task_1" as TaskId);
    expect(retrieved!.title).toBe("Bring snacks");

    const bySpace = await adapter.getTasksBySpace("space_1" as SpaceId);
    expect(bySpace).toHaveLength(1);

    await adapter.deleteTask("task_1" as TaskId);
    const deleted = await adapter.getTask("task_1" as TaskId);
    expect(deleted).toBeUndefined();
  });

  it("clear() removes everything", async () => {
    await adapter.saveItem(makeItem());
    adapter.clear();
    const items = await adapter.getItemsBySpace("space_1" as SpaceId);
    expect(items).toHaveLength(0);
  });

  it("deleteSpace cascades to items and tasks", async () => {
    const space: DecisionSpace = {
      id: "space_1" as SpaceId,
      name: "Trip",
      members: [],
      config: {} as any,
      createdAt: 1000,
    };
    await adapter.saveSpace(space);
    await adapter.saveItem(makeItem());

    await adapter.deleteSpace("space_1" as SpaceId);

    const items = await adapter.getItemsBySpace("space_1" as SpaceId);
    expect(items).toHaveLength(0);
  });
});

describe("MemoryEventBusAdapter", () => {
  let bus: MemoryEventBusAdapter;

  beforeEach(() => {
    bus = new MemoryEventBusAdapter();
  });

  it("delivers events to subscribers", async () => {
    const events: EngineEvent[] = [];
    await bus.subscribe("ch1", (e) => events.push(e));

    await bus.publish("ch1", {
      type: "item_proposed" as any,
      timestamp: 1000,
      groupId: "g1" as GroupId,
      actorId: "u1" as UserId,
      payload: {},
    });

    expect(events).toHaveLength(1);
  });

  it("does not deliver to unsubscribed handlers", async () => {
    const events: EngineEvent[] = [];
    const unsub = await bus.subscribe("ch1", (e) => events.push(e));

    unsub();

    await bus.publish("ch1", {
      type: "item_proposed" as any,
      timestamp: 1000,
      groupId: "g1" as GroupId,
      actorId: "u1" as UserId,
      payload: {},
    });

    expect(events).toHaveLength(0);
  });

  it("isolates channels", async () => {
    const events1: EngineEvent[] = [];
    const events2: EngineEvent[] = [];

    await bus.subscribe("ch1", (e) => events1.push(e));
    await bus.subscribe("ch2", (e) => events2.push(e));

    await bus.publish("ch1", {
      type: "item_proposed" as any,
      timestamp: 1000,
      groupId: "g1" as GroupId,
      actorId: "u1" as UserId,
      payload: {},
    });

    expect(events1).toHaveLength(1);
    expect(events2).toHaveLength(0);
  });

  it("publishMany sends to multiple channels", async () => {
    const events1: EngineEvent[] = [];
    const events2: EngineEvent[] = [];

    await bus.subscribe("ch1", (e) => events1.push(e));
    await bus.subscribe("ch2", (e) => events2.push(e));

    await bus.publishMany(["ch1", "ch2"], {
      type: "item_proposed" as any,
      timestamp: 1000,
      groupId: "g1" as GroupId,
      actorId: "u1" as UserId,
      payload: {},
    });

    expect(events1).toHaveLength(1);
    expect(events2).toHaveLength(1);
  });

  it("tracks subscriber count", async () => {
    expect(bus.subscriberCount).toBe(0);
    const unsub = await bus.subscribe("ch1", () => {});
    expect(bus.subscriberCount).toBe(1);
    unsub();
    expect(bus.subscriberCount).toBe(0);
  });
});

describe("MemoryCacheAdapter", () => {
  let cache: MemoryCacheAdapter;

  beforeEach(() => {
    cache = new MemoryCacheAdapter();
  });

  it("stores and retrieves values", async () => {
    await cache.set("key", { data: 42 });
    const value = await cache.get<{ data: number }>("key");
    expect(value!.data).toBe(42);
  });

  it("returns null for missing keys", async () => {
    const value = await cache.get("missing");
    expect(value).toBeNull();
  });

  it("deletes keys", async () => {
    await cache.set("key", "value");
    await cache.delete("key");
    expect(await cache.get("key")).toBeNull();
  });

  it("deletes by prefix", async () => {
    await cache.set("ranked:s1", [1]);
    await cache.set("ranked:s2", [2]);
    await cache.set("other:s1", [3]);

    await cache.deleteByPrefix("ranked:");

    expect(await cache.get("ranked:s1")).toBeNull();
    expect(await cache.get("ranked:s2")).toBeNull();
    expect(await cache.get("other:s1")).not.toBeNull();
  });

  it("respects TTL", async () => {
    await cache.set("key", "value", 1); // 1ms TTL
    // Wait for expiry
    await new Promise((r) => setTimeout(r, 10));
    expect(await cache.get("key")).toBeNull();
  });
});

describe("NoopAuthAdapter", () => {
  it("authenticates any non-empty token", async () => {
    const auth = new NoopAuthAdapter();
    const identity = await auth.authenticate("alice");
    expect(identity).not.toBeNull();
    expect(identity!.userId).toBe("alice");
  });

  it("rejects empty token", async () => {
    const auth = new NoopAuthAdapter();
    const identity = await auth.authenticate("");
    expect(identity).toBeNull();
  });

  it("authorizes everything", async () => {
    const auth = new NoopAuthAdapter();
    const identity = { userId: "alice" as UserId };
    const allowed = await auth.authorize(identity, "item:lock", "s1" as SpaceId);
    expect(allowed).toBe(true);
  });
});

describe("PlaintextMessagingAdapter", () => {
  let msg: PlaintextMessagingAdapter;

  beforeEach(() => {
    msg = new PlaintextMessagingAdapter();
  });

  it("formats an item", () => {
    const item = makeItem({ title: "Hilton SD", weightedScore: 8 });
    const out = msg.formatItem(item);
    expect(out.text).toContain("Hilton SD");
    expect(out.text).toContain("score: 8");
  });

  it("formats a ranked list", () => {
    const out = msg.formatRankedList([
      { rank: 1, title: "Nobu", weightedScore: 11, agreementScore: 100, isGroupFavorite: true },
      { rank: 2, title: "Olive", weightedScore: 3, agreementScore: 50, isGroupFavorite: false },
    ]);
    expect(out.text).toContain("#1 Nobu");
    expect(out.text).toContain("GROUP FAVORITE");
    expect(out.text).toContain("#2 Olive");
  });

  it("formats empty ranked list", () => {
    const out = msg.formatRankedList([]);
    expect(out.text).toContain("No items ranked yet");
  });

  it("formats lock notification", () => {
    const item = makeItem({
      title: "Hilton SD",
      ownership: { ownerId: "carol" as UserId, assignedAt: 2000, reason: "booker" },
      commitmentProof: {
        type: "confirmation_number",
        value: "HILTON-99",
        submittedBy: "carol" as UserId,
        submittedAt: 2000,
      },
    });
    const out = msg.formatLockNotification(item);
    expect(out.text).toContain("LOCKED");
    expect(out.text).toContain("Hilton SD");
    expect(out.text).toContain("carol");
    expect(out.text).toContain("HILTON-99");
  });

  it("parses /love command", () => {
    const cmd = msg.parseCommand({
      platform: "test",
      channelId: "ch1",
      userId: "alice",
      text: "/love Hilton",
    });
    expect(cmd).not.toBeNull();
    expect(cmd!.type).toBe("react");
    expect(cmd!.payload.reactionType).toBe("love_it");
    expect(cmd!.payload.title).toBe("Hilton");
  });

  it("parses /rank command", () => {
    const cmd = msg.parseCommand({
      platform: "test",
      channelId: "ch1",
      userId: "bob",
      text: "/rank",
    });
    expect(cmd!.type).toBe("rank");
  });

  it("parses /nope command", () => {
    const cmd = msg.parseCommand({
      platform: "test",
      channelId: "ch1",
      userId: "carol",
      text: "/nope Expensive Hotel",
    });
    expect(cmd!.type).toBe("react");
    expect(cmd!.payload.reactionType).toBe("not_for_me");
  });

  it("parses /task command", () => {
    const cmd = msg.parseCommand({
      platform: "test",
      channelId: "ch1",
      userId: "alice",
      text: "/task Bring sunscreen",
    });
    expect(cmd!.type).toBe("add_task");
    expect(cmd!.payload.title).toBe("Bring sunscreen");
  });

  it("returns null for non-commands", () => {
    const cmd = msg.parseCommand({
      platform: "test",
      channelId: "ch1",
      userId: "alice",
      text: "just a normal message",
    });
    expect(cmd).toBeNull();
  });

  it("parses space-scoped commands", () => {
    const cmd = msg.parseCommand({
      platform: "test",
      channelId: "ch1",
      userId: "alice",
      text: "/love [trip_sd] Hilton",
    });
    expect(cmd!.spaceId).toBe("trip_sd");
    expect(cmd!.payload.title).toBe("Hilton");
  });

  it("formats event notifications", () => {
    const out = msg.formatEventNotification({
      type: "item_proposed",
      payload: { title: "Hilton" },
    });
    expect(out.text).toContain("Hilton");

    const lockNotif = msg.formatEventNotification({
      type: "item_locked",
      payload: { title: "Hilton", ownerId: "alice" },
    });
    expect(lockNotif.text).toContain("locked");
  });
});
