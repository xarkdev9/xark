import { describe, it, expect, beforeEach } from "vitest";
import { DecisionService, AuthError, NotFoundError } from "../service/decision-service.js";
import { MemoryPersistenceAdapter } from "../adapters/memory-persistence.js";
import { MemoryEventBusAdapter } from "../adapters/memory-event-bus.js";
import { MemoryCacheAdapter } from "../adapters/memory-cache.js";
import { NoopAuthAdapter } from "../adapters/noop-auth.js";
import { ReactionType, BookableItemState, EventType } from "../models/types.js";
import type { EngineEvent, UserId, GroupId, GroupMember } from "../models/types.js";
import type { Identity } from "../ports/auth.js";

function makeIdentity(userId: string): Identity {
  return { userId: userId as UserId, displayName: userId };
}

function makeMembers(): GroupMember[] {
  return [
    { userId: "alice" as UserId, name: "Alice", avatarUrl: "", joinedAt: 100 },
    { userId: "bob" as UserId, name: "Bob", avatarUrl: "", joinedAt: 100 },
    { userId: "carol" as UserId, name: "Carol", avatarUrl: "", joinedAt: 100 },
  ];
}

describe("DecisionService", () => {
  let service: DecisionService;
  let persistence: MemoryPersistenceAdapter;
  let eventBus: MemoryEventBusAdapter;
  let cache: MemoryCacheAdapter;
  let alice: Identity;
  let bob: Identity;
  let carol: Identity;

  beforeEach(() => {
    persistence = new MemoryPersistenceAdapter();
    eventBus = new MemoryEventBusAdapter();
    cache = new MemoryCacheAdapter();

    service = new DecisionService({
      persistence,
      eventBus,
      auth: new NoopAuthAdapter(),
      cache,
    });

    alice = makeIdentity("alice");
    bob = makeIdentity("bob");
    carol = makeIdentity("carol");
  });

  describe("Space Management", () => {
    it("creates and retrieves a space", async () => {
      const space = await service.createSpace(alice, "Trip", makeMembers());
      expect(space.name).toBe("Trip");
      expect(space.members).toHaveLength(3);
      expect(space.id).toMatch(/^space_/);

      const retrieved = await service.getSpace(alice, space.id);
      expect(retrieved.name).toBe("Trip");
    });

    it("deletes a space", async () => {
      const space = await service.createSpace(alice, "Trip", makeMembers());
      await service.deleteSpace(alice, space.id);
      await expect(service.getSpace(alice, space.id)).rejects.toThrow(NotFoundError);
    });

    it("throws NotFoundError for non-existent space", async () => {
      await expect(
        service.getSpace(alice, "nope" as GroupId)
      ).rejects.toThrow(NotFoundError);
    });
  });

  describe("Full Lifecycle", () => {
    it("propose → react → rank → lock → transfer", async () => {
      const space = await service.createSpace(alice, "Dinner", makeMembers());
      const events: EngineEvent[] = [];
      await eventBus.subscribe(`space:${space.id}`, (e) => events.push(e));

      // Propose items
      const nobu = await service.addItem(alice, space.id, "Nobu", "Japanese", "restaurant");
      const olive = await service.addItem(bob, space.id, "Olive Garden", "Italian", "restaurant");

      expect(nobu.state).toBe(BookableItemState.Proposed);
      expect(nobu.version).toBe(1);

      // React
      const afterReact = await service.react(alice, nobu.id, ReactionType.LoveIt);
      expect(afterReact.weightedScore).toBe(5);
      expect(afterReact.version).toBe(2);
      expect(afterReact.state).toBe("ranked"); // state machine transitioned

      await service.react(bob, nobu.id, ReactionType.WorksForMe);
      await service.react(carol, nobu.id, ReactionType.LoveIt);
      await service.react(alice, olive.id, ReactionType.WorksForMe);

      // Rank — Nobu should be #1
      const ranked = await service.getRankedItems(alice, space.id);
      expect(ranked).toHaveLength(2);
      expect(ranked[0]!.title).toBe("Nobu");
      expect(ranked[0]!.weightedScore).toBe(11); // 5 + 1 + 5

      // Lock
      const locked = await service.lock(alice, nobu.id, {
        type: "confirmation_number",
        value: "NOBU-123",
        submittedBy: alice.userId,
        submittedAt: Date.now(),
      });
      expect(locked.state).toBe(BookableItemState.Locked);
      expect(locked.ownership!.ownerId).toBe("alice");

      // Transfer
      const transferred = await service.transfer(bob, nobu.id, "bob" as UserId);
      expect(transferred.ownership!.ownerId).toBe("bob");
      expect(transferred.ownershipHistory).toHaveLength(2);

      // Verify events
      expect(events.filter((e) => e.type === EventType.ItemProposed)).toHaveLength(2);
      expect(events.filter((e) => e.type === EventType.ReactionAdded)).toHaveLength(4);
      expect(events.filter((e) => e.type === EventType.ItemLocked)).toHaveLength(1);
      expect(events.filter((e) => e.type === EventType.OwnershipTransferred)).toHaveLength(1);
    });
  });

  describe("Persistence", () => {
    it("state survives across service instances", async () => {
      // Instance 1: create space and add item
      const space = await service.createSpace(alice, "Car", makeMembers());
      const item = await service.addItem(alice, space.id, "Tesla Model 3", "EV", "car");
      await service.react(alice, item.id, ReactionType.LoveIt);

      // Instance 2: new service, same persistence
      const service2 = new DecisionService({
        persistence, // same adapter
        eventBus: new MemoryEventBusAdapter(),
        auth: new NoopAuthAdapter(),
      });

      // Data is still there
      const retrieved = await service2.getItem(alice, item.id);
      expect(retrieved.title).toBe("Tesla Model 3");
      expect(retrieved.weightedScore).toBe(5);

      const ranked = await service2.getRankedItems(alice, space.id);
      expect(ranked).toHaveLength(1);
      expect(ranked[0]!.title).toBe("Tesla Model 3");
    });
  });

  describe("Cache", () => {
    it("caches ranked items and invalidates on reaction", async () => {
      const space = await service.createSpace(alice, "Trip", makeMembers());
      await service.addItem(alice, space.id, "Hotel A", "", "hotel");

      // First call populates cache
      const ranked1 = await service.getRankedItems(alice, space.id);
      expect(ranked1).toHaveLength(1);
      expect(cache.size).toBeGreaterThan(0);

      // Second call hits cache
      const ranked2 = await service.getRankedItems(alice, space.id);
      expect(ranked2).toHaveLength(1);

      // React invalidates cache
      const items = await persistence.getItemsBySpace(space.id);
      await service.react(alice, items[0]!.id, ReactionType.LoveIt);

      // Cache was invalidated — next call recomputes
      const ranked3 = await service.getRankedItems(alice, space.id);
      expect(ranked3[0]!.weightedScore).toBe(5);
    });
  });

  describe("Event Bus", () => {
    it("broadcasts events to subscribers", async () => {
      const space = await service.createSpace(alice, "Trip", makeMembers());
      const events: EngineEvent[] = [];

      await eventBus.subscribe(`space:${space.id}`, (e) => events.push(e));

      await service.addItem(alice, space.id, "Hotel", "", "hotel");
      expect(events).toHaveLength(1);
      expect(events[0]!.type).toBe(EventType.ItemProposed);
    });

    it("supports unsubscribing", async () => {
      const space = await service.createSpace(alice, "Trip", makeMembers());
      const events: EngineEvent[] = [];

      const unsub = await eventBus.subscribe(`space:${space.id}`, (e) =>
        events.push(e)
      );

      await service.addItem(alice, space.id, "A", "", "hotel");
      expect(events).toHaveLength(1);

      unsub();
      await service.addItem(alice, space.id, "B", "", "hotel");
      expect(events).toHaveLength(1); // no new events
    });
  });

  describe("Optimistic Concurrency", () => {
    it("version increments on each mutation", async () => {
      const space = await service.createSpace(alice, "Trip", makeMembers());
      const item = await service.addItem(alice, space.id, "Hotel", "", "hotel");
      expect(item.version).toBe(1);

      const reacted = await service.react(alice, item.id, ReactionType.LoveIt);
      expect(reacted.version).toBe(2);

      const reacted2 = await service.react(bob, item.id, ReactionType.WorksForMe);
      expect(reacted2.version).toBe(3);
    });
  });

  describe("Locked Item Rules", () => {
    it("prevents reactions on locked items", async () => {
      const space = await service.createSpace(alice, "Trip", makeMembers());
      const item = await service.addItem(alice, space.id, "Hotel", "", "hotel");
      await service.lock(alice, item.id, {
        type: "confirmation_number",
        value: "X",
        submittedBy: alice.userId,
        submittedAt: Date.now(),
      });

      await expect(
        service.react(bob, item.id, ReactionType.LoveIt)
      ).rejects.toThrow("locked");
    });

    it("separates locked and active items", async () => {
      const space = await service.createSpace(alice, "Trip", makeMembers());
      const a = await service.addItem(alice, space.id, "A", "", "hotel");
      await service.addItem(alice, space.id, "B", "", "hotel");

      await service.lock(alice, a.id, {
        type: "confirmation_number",
        value: "X",
        submittedBy: alice.userId,
        submittedAt: Date.now(),
      });

      const locked = await service.getLockedItems(alice, space.id);
      const active = await service.getActiveItems(alice, space.id);

      expect(locked).toHaveLength(1);
      expect(locked[0]!.title).toBe("A");
      expect(active).toHaveLength(1);
      expect(active[0]!.title).toBe("B");
    });
  });

  describe("Tasks", () => {
    it("creates, claims, and releases tasks", async () => {
      const space = await service.createSpace(alice, "Trip", makeMembers());

      const task = await service.addTask(alice, space.id, "Bring snacks", "Chips and salsa");
      expect(task.assignee).toBeNull();

      const claimed = await service.claimTask(bob, task.id);
      expect(claimed.assignee).toBe("bob");

      const released = await service.releaseTask(carol, task.id);
      expect(released.assignee).toBeNull();
    });
  });

  describe("AI Grounding", () => {
    it("returns grounding context with locked decisions", async () => {
      const space = await service.createSpace(alice, "Trip", makeMembers());
      const item = await service.addItem(alice, space.id, "Hilton", "", "hotel");
      await service.react(alice, item.id, ReactionType.LoveIt);
      await service.lock(alice, item.id, {
        type: "confirmation_number",
        value: "HILTON-99",
        submittedBy: alice.userId,
        submittedAt: Date.now(),
      });

      const ctx = await service.getGroundingContext(alice, space.id);
      expect(ctx.lockedDecisions).toHaveLength(1);
      expect(ctx.lockedDecisions[0]!.title).toBe("Hilton");

      const prompt = await service.getGroundingPrompt(alice, space.id);
      expect(prompt).toContain("GROUNDING CONSTRAINTS");
      expect(prompt).toContain("Hilton");
    });

    it("checks conflicts for duplicate categories", async () => {
      const space = await service.createSpace(alice, "Trip", makeMembers());
      const item = await service.addItem(alice, space.id, "Hilton", "", "hotel");
      await service.lock(alice, item.id, {
        type: "confirmation_number",
        value: "X",
        submittedBy: alice.userId,
        submittedAt: Date.now(),
      });

      const conflicts = await service.checkConflicts(alice, space.id, "hotel");
      expect(conflicts).toHaveLength(1);

      const noConflicts = await service.checkConflicts(alice, space.id, "restaurant");
      expect(noConflicts).toHaveLength(0);
    });
  });

  describe("Signal Breakdown", () => {
    it("returns correct breakdown", async () => {
      const space = await service.createSpace(alice, "Trip", makeMembers());
      const item = await service.addItem(alice, space.id, "Hotel", "", "hotel");

      await service.react(alice, item.id, ReactionType.LoveIt);
      await service.react(bob, item.id, ReactionType.WorksForMe);
      await service.react(carol, item.id, ReactionType.NotForMe);

      const breakdown = await service.getSignalBreakdown(alice, item.id);
      expect(breakdown.loveIt).toBe(1);
      expect(breakdown.worksForMe).toBe(1);
      expect(breakdown.notForMe).toBe(1);
      expect(breakdown.isUnanimousLoveIt).toBe(false);
    });

    it("detects unanimous love it", async () => {
      const space = await service.createSpace(alice, "Trip", makeMembers());
      const item = await service.addItem(alice, space.id, "Hotel", "", "hotel");

      await service.react(alice, item.id, ReactionType.LoveIt);
      await service.react(bob, item.id, ReactionType.LoveIt);
      await service.react(carol, item.id, ReactionType.LoveIt);

      const breakdown = await service.getSignalBreakdown(alice, item.id);
      expect(breakdown.isUnanimousLoveIt).toBe(true);
    });
  });

  describe("Unreact", () => {
    it("removes a reaction and recalculates score", async () => {
      const space = await service.createSpace(alice, "Trip", makeMembers());
      const item = await service.addItem(alice, space.id, "Hotel", "", "hotel");

      await service.react(alice, item.id, ReactionType.LoveIt);
      const after = await service.unreact(alice, item.id);
      expect(after.weightedScore).toBe(0);
      expect(after.reactions).toHaveLength(0);
    });
  });
});
