import { describe, it, expect } from "vitest";
import {
  // Old type names should still work
  BookableItemState,
  ReactionType,
  TaskState,
  EventType,
  REACTION_WEIGHTS,

  // Old function names should still work
  lockItem,
  transferOwnership,
  isLocked,
  getOwner,
  canLock,
  canTransferOwnership,
  GreenLockError,

  calculateWeightedScore,
  addReaction,
  removeReaction,
  heartSort,
  getTopItems,
  calculateAgreementScore,
  getRankedSummary,

  createTask,
  assignTask,
  reassignTask,
  unassignTask,
  resetTaskCounter,
  TaskAssignmentError,

  buildGroundingContext,
  generateGroundingPrompt,
  checkSuggestionConflicts,

  ConsensusEngine,

  // New exports should also be available
  commitItem,
  StateMachine,
  BOOKING_FLOW,
  PURCHASE_FLOW,
  SIMPLE_VOTE_FLOW,
  SOLO_DECISION_FLOW,
  DEFAULT_SPACE_CONFIG,
  InMemoryAdapter,
} from "../index.js";
import type {
  // Old type names
  BookableItem,
  BookingProof,
  OwnershipRecord,
  Group,
  GroupMember,
  EngineEvent,
  UserId,
  GroupId,
  ItemId,
  TaskId,
  Reaction,
  Task,

  // New type names
  CommitmentProof,
  DecisionItem,
  DecisionItemState,
  DecisionSpace,
  SpaceId,
  SpaceConfig,
  GroundingConstraint,
  GroundingContext,
  StateFlowConfig,
  StateTransition,
  PersistenceAdapter,
  EngineOptions,
} from "../index.js";

describe("Backwards Compatibility", () => {
  describe("Type aliases", () => {
    it("BookingProof is CommitmentProof", () => {
      const proof: BookingProof = {
        type: "confirmation_number",
        value: "CONF-123",
        submittedBy: "user_1" as UserId,
        submittedAt: 1000,
      };
      // BookingProof and CommitmentProof are the same type
      const commitmentProof: CommitmentProof = proof;
      expect(commitmentProof.value).toBe("CONF-123");
    });

    it("BookableItem has version and metadata fields with defaults", () => {
      const item: BookableItem = {
        id: "item_1" as ItemId,
        spaceId: "g1" as SpaceId,
        groupId: "g1" as GroupId,
        title: "Test",
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
      };
      expect(item.version).toBe(1);
      expect(item.metadata).toEqual({});
    });

    it("BookableItem.category accepts any string", () => {
      const hotel: BookableItem = {
        id: "item_1" as ItemId,
        spaceId: "g1" as SpaceId,
        groupId: "g1" as GroupId,
        title: "Test",
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
      };
      expect(hotel.category).toBe("hotel");

      // New categories also work
      const sedan: BookableItem = { ...hotel, category: "sedan" };
      expect(sedan.category).toBe("sedan");
    });
  });

  describe("Old API surface via ConsensusEngine", () => {
    it("registerGroup still works", () => {
      const engine = new ConsensusEngine();
      const group: Group = {
        id: "g1" as GroupId,
        name: "Test Group",
        members: [
          { userId: "alice" as UserId, name: "Alice", avatarUrl: "", joinedAt: 100 },
        ],
        createdAt: 100,
      };

      engine.registerGroup(group);
      expect(engine.getGroup("g1")).toEqual(group);
    });

    it("proposeItem still works as alias for addItem", () => {
      const engine = new ConsensusEngine();
      engine.registerGroup({
        id: "g1" as GroupId,
        name: "Test",
        members: [],
        createdAt: 100,
      });

      const item = engine.proposeItem("g1", "Hotel", "Nice hotel", "hotel", "alice", 1000);
      expect(item.title).toBe("Hotel");
      expect(item.state).toBe("proposed"); // BOOKING_FLOW default
    });

    it("full old-style workflow still works", () => {
      const engine = new ConsensusEngine();
      const events: EngineEvent[] = [];
      engine.on((e) => events.push(e));

      engine.registerGroup({
        id: "trip" as GroupId,
        name: "Trip",
        members: [
          { userId: "alice" as UserId, name: "Alice", avatarUrl: "", joinedAt: 100 },
          { userId: "bob" as UserId, name: "Bob", avatarUrl: "", joinedAt: 100 },
        ],
        createdAt: 100,
      });

      // Propose
      const hotel = engine.proposeItem("trip", "Hilton", "Downtown", "hotel", "alice", 1000);

      // React
      engine.react(hotel.id, "alice", ReactionType.LoveIt, 2000);
      engine.react(hotel.id, "bob", ReactionType.WorksForMe, 2001);

      // Lock
      const locked = engine.lock(hotel.id, {
        type: "confirmation_number",
        value: "HILTON-123",
        submittedBy: "alice",
        submittedAt: 3000,
      });

      expect(locked.state).toBe(BookableItemState.Locked);
      expect(locked.ownership!.ownerId).toBe("alice");
      expect(locked.bookingProof!.value).toBe("HILTON-123");

      // Transfer
      const transferred = engine.transfer(hotel.id, "bob", 4000);
      expect(transferred.ownership!.ownerId).toBe("bob");

      // Events emitted
      expect(events.filter((e) => e.type === EventType.ItemProposed)).toHaveLength(1);
      expect(events.filter((e) => e.type === EventType.ReactionAdded)).toHaveLength(2);
      expect(events.filter((e) => e.type === EventType.ItemLocked)).toHaveLength(1);
      expect(events.filter((e) => e.type === EventType.OwnershipTransferred)).toHaveLength(1);
    });
  });

  describe("Old standalone functions", () => {
    it("lockItem still works with BookableItemState enum", () => {
      const item: BookableItem = {
        id: "item_1" as ItemId,
        spaceId: "g1" as SpaceId,
        groupId: "g1" as GroupId,
        title: "Hotel",
        description: "",
        category: "hotel",
        state: BookableItemState.HeartSorted,
        proposedBy: "u1" as UserId,
        proposedAt: 1000,
        reactions: [],
        weightedScore: 5,
        commitmentProof: null,
        bookingProof: null,
        ownership: null,
        ownershipHistory: [],
        lockedAt: null,
        version: 1,
        metadata: {},
      };

      const locked = lockItem(item, {
        type: "confirmation_number",
        value: "CONF-123",
        submittedBy: "u2" as UserId,
        submittedAt: 2000,
      });

      expect(locked.state).toBe(BookableItemState.Locked);
      expect(isLocked(locked)).toBe(true);
    });

    it("heartSort still works", () => {
      const makeItem = (id: string, score: number): BookableItem => ({
        id: id as ItemId,
        spaceId: "g1" as SpaceId,
        groupId: "g1" as GroupId,
        title: id,
        description: "",
        category: "hotel",
        state: BookableItemState.Proposed,
        proposedBy: "u1" as UserId,
        proposedAt: 1000,
        reactions: [],
        weightedScore: score,
        commitmentProof: null,
        bookingProof: null,
        ownership: null,
        ownershipHistory: [],
        lockedAt: null,
        version: 1,
        metadata: {},
      });

      const sorted = heartSort([makeItem("a", 3), makeItem("b", 10), makeItem("c", 7)]);
      expect(sorted.map((i) => i.id)).toEqual(["b", "c", "a"]);
    });

    it("resetTaskCounter is a no-op", () => {
      // Should not throw
      expect(() => resetTaskCounter()).not.toThrow();
    });
  });

  describe("Enums still have correct values", () => {
    it("BookableItemState values unchanged", () => {
      expect(BookableItemState.Proposed).toBe("proposed");
      expect(BookableItemState.HeartSorted).toBe("heart_sorted");
      expect(BookableItemState.Locked).toBe("locked");
    });

    it("ReactionType aliases point to new values", () => {
      expect(ReactionType.Heart).toBe(ReactionType.LoveIt);
      expect(ReactionType.ThumbsUp).toBe(ReactionType.WorksForMe);
      expect(ReactionType.LoveIt).toBe("love_it");
      expect(ReactionType.WorksForMe).toBe("works_for_me");
      expect(ReactionType.NotForMe).toBe("not_for_me");
    });

    it("REACTION_WEIGHTS accessible via old and new keys", () => {
      expect(REACTION_WEIGHTS[ReactionType.Heart]).toBe(5);
      expect(REACTION_WEIGHTS[ReactionType.LoveIt]).toBe(5);
      expect(REACTION_WEIGHTS[ReactionType.ThumbsUp]).toBe(1);
      expect(REACTION_WEIGHTS[ReactionType.WorksForMe]).toBe(1);
      expect(REACTION_WEIGHTS[ReactionType.NotForMe]).toBe(-3);
    });

    it("EventType values unchanged", () => {
      expect(EventType.ItemProposed).toBe("item_proposed");
      expect(EventType.ReactionAdded).toBe("reaction_added");
      expect(EventType.ItemLocked).toBe("item_locked");
      expect(EventType.OwnershipTransferred).toBe("ownership_transferred");
      expect(EventType.TaskCreated).toBe("task_created");
      expect(EventType.TaskAssigned).toBe("task_assigned");
    });
  });

  describe("New exports are accessible", () => {
    it("StateMachine class works", () => {
      const sm = new StateMachine(BOOKING_FLOW);
      expect(sm.getInitialState()).toBe("proposed");
      expect(sm.getLockedState()).toBe("locked");
    });

    it("all preset flows are exported", () => {
      expect(BOOKING_FLOW.name).toBe("booking");
      expect(PURCHASE_FLOW.name).toBe("purchase");
      expect(SIMPLE_VOTE_FLOW.name).toBe("simple_vote");
      expect(SOLO_DECISION_FLOW.name).toBe("solo_decision");
    });

    it("DEFAULT_SPACE_CONFIG has expected defaults", () => {
      expect(DEFAULT_SPACE_CONFIG.groupFavoriteThreshold).toBe(80);
      expect(DEFAULT_SPACE_CONFIG.allowSelfReaction).toBe(true);
      expect(DEFAULT_SPACE_CONFIG.requireProofForLock).toBe(true);
    });

    it("InMemoryAdapter implements PersistenceAdapter", async () => {
      const adapter = new InMemoryAdapter();
      const item: BookableItem = {
        id: "item_1" as ItemId,
        spaceId: "g1" as SpaceId,
        groupId: "g1" as GroupId,
        title: "Test",
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
      };

      await adapter.saveItem(item);
      const retrieved = await adapter.getItem("item_1" as ItemId);
      expect(retrieved).toEqual(item);

      const spaceItems = await adapter.getItemsBySpace("g1");
      expect(spaceItems).toHaveLength(1);

      await adapter.deleteItem("item_1" as ItemId);
      const deleted = await adapter.getItem("item_1" as ItemId);
      expect(deleted).toBeUndefined();
    });

    it("commitItem function works with state machine", () => {
      const sm = new StateMachine(BOOKING_FLOW);
      const item: BookableItem = {
        id: "item_1" as ItemId,
        spaceId: "g1" as SpaceId,
        groupId: "g1" as GroupId,
        title: "Hotel",
        description: "",
        category: "hotel",
        state: "ranked",
        proposedBy: "u1" as UserId,
        proposedAt: 1000,
        reactions: [],
        weightedScore: 5,
        commitmentProof: null,
        bookingProof: null,
        ownership: null,
        ownershipHistory: [],
        lockedAt: null,
        version: 1,
        metadata: {},
      };

      const committed = commitItem(item, {
        type: "confirmation_number",
        value: "CONF-123",
        submittedBy: "u2" as UserId,
        submittedAt: 2000,
      }, sm);

      expect(committed.state).toBe("locked");
      expect(committed.ownership!.ownerId).toBe("u2");
    });
  });
});
