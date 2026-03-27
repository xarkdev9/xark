import { describe, it, expect, beforeEach } from "vitest";
import { ConsensusEngine } from "../engine/consensus-engine.js";
import {
  ReactionType,
  BookableItemState,
  TaskState,
  EventType,
} from "../models/types.js";
import type { Group, EngineEvent, BookingProof } from "../models/types.js";
import { resetTaskCounter } from "../engine/task-assignment.js";

function makeGroup(): Group {
  return {
    id: "trip_sd",
    name: "San Diego Trip",
    members: [
      { userId: "alice", name: "Alice", avatarUrl: "/alice.png", joinedAt: 100 },
      { userId: "bob", name: "Bob", avatarUrl: "/bob.png", joinedAt: 100 },
      { userId: "carol", name: "Carol", avatarUrl: "/carol.png", joinedAt: 100 },
      { userId: "dave", name: "Dave", avatarUrl: "/dave.png", joinedAt: 100 },
    ],
    createdAt: 100,
  };
}

describe("ConsensusEngine", () => {
  let engine: ConsensusEngine;
  let events: EngineEvent[];

  beforeEach(() => {
    engine = new ConsensusEngine();
    events = [];
    engine.on((e) => events.push(e));
    engine.registerGroup(makeGroup());
    resetTaskCounter();
  });

  describe("Full Green-Lock Flow", () => {
    it("completes the full lifecycle: propose → react → sort → lock → transfer", () => {
      // 1. Apify proposes hotel options
      const hilton = engine.proposeItem(
        "trip_sd", "Hilton San Diego", "Downtown, pool, $200/night",
        "hotel", "apify", 1000
      );
      const marriott = engine.proposeItem(
        "trip_sd", "Marriott San Diego", "Gaslamp, rooftop bar, $250/night",
        "hotel", "apify", 1001
      );
      const hyatt = engine.proposeItem(
        "trip_sd", "Hyatt San Diego", "Harbor view, $180/night",
        "hotel", "apify", 1002
      );

      // Verify all proposed
      expect(hilton.state).toBe(BookableItemState.Proposed);
      expect(marriott.state).toBe(BookableItemState.Proposed);

      // 2. Group reacts — Heart-Sort re-orders
      engine.react(hilton.id, "alice", ReactionType.LoveIt, 2000);    // +5
      engine.react(hilton.id, "bob", ReactionType.WorksForMe, 2001);   // +1
      engine.react(marriott.id, "alice", ReactionType.WorksForMe, 2002); // +1
      engine.react(marriott.id, "carol", ReactionType.LoveIt, 2003);   // +5
      engine.react(marriott.id, "dave", ReactionType.LoveIt, 2004);    // +5
      engine.react(hyatt.id, "bob", ReactionType.WorksForMe, 2005);     // +1

      // Check sort order: Marriott (11) > Hilton (6) > Hyatt (1)
      const sorted = engine.getGroupItems("trip_sd");
      expect(sorted[0]!.title).toBe("Marriott San Diego");
      expect(sorted[0]!.weightedScore).toBe(11);
      expect(sorted[1]!.title).toBe("Hilton San Diego");
      expect(sorted[1]!.weightedScore).toBe(6);
      expect(sorted[2]!.title).toBe("Hyatt San Diego");
      expect(sorted[2]!.weightedScore).toBe(1);

      // Verify items transition to ranked state
      expect(sorted[0]!.state).toBe("ranked");

      // 3. Carol books the Marriott (top choice) and provides confirmation
      const proof: BookingProof = {
        type: "confirmation_number",
        value: "MARRIOTT-SD-78432",
        submittedBy: "carol",
        submittedAt: 3000,
      };
      const locked = engine.lock(marriott.id, proof);

      expect(locked.state).toBe(BookableItemState.Locked);
      expect(locked.ownership!.ownerId).toBe("carol");
      expect(locked.ownership!.reason).toBe("booker");
      expect(locked.bookingProof!.value).toBe("MARRIOTT-SD-78432");

      // 4. Dave takes over responsibility: "I'll take care of this"
      const transferred = engine.transfer(marriott.id, "dave", 4000);

      expect(transferred.ownership!.ownerId).toBe("dave");
      expect(transferred.ownership!.reason).toBe("transfer");
      expect(transferred.ownershipHistory).toHaveLength(2);

      // 5. Verify locked items vs active items
      const lockedItems = engine.getLockedItems("trip_sd");
      expect(lockedItems).toHaveLength(1);
      expect(lockedItems[0]!.title).toBe("Marriott San Diego");

      const activeItems = engine.getActiveItems("trip_sd");
      expect(activeItems).toHaveLength(2);

      // 6. Verify events were emitted
      expect(events.filter((e) => e.type === EventType.ItemProposed)).toHaveLength(3);
      expect(events.filter((e) => e.type === EventType.ReactionAdded)).toHaveLength(6);
      expect(events.filter((e) => e.type === EventType.ItemLocked)).toHaveLength(1);
      expect(events.filter((e) => e.type === EventType.OwnershipTransferred)).toHaveLength(1);
    });
  });

  describe("AI Grounding", () => {
    it("grounds @hello to locked state — prevents contradicting bookings", () => {
      // Book a hotel
      const hotel = engine.proposeItem(
        "trip_sd", "Hilton San Diego", "Downtown", "hotel", "apify", 1000
      );
      engine.react(hotel.id, "alice", ReactionType.LoveIt, 1500);
      engine.lock(hotel.id, {
        type: "confirmation_number",
        value: "HILTON-99",
        submittedBy: "alice",
        submittedAt: 2000,
      });

      // Add some active restaurant options
      const nobu = engine.proposeItem(
        "trip_sd", "Nobu San Diego", "Japanese cuisine", "restaurant", "apify", 2500
      );
      engine.react(nobu.id, "bob", ReactionType.LoveIt, 2600);

      // Assign a task
      const task = engine.addTask("trip_sd", "Bring sunscreen", "SPF 50", "bob", 2700);
      engine.claimTask(task.id, "carol", 2800);

      // Get grounding context
      const context = engine.getGroundingContext("trip_sd");

      expect(context.lockedDecisions).toHaveLength(2); // hotel + task
      expect(context.lockedDecisions.find((d) => d.type === "locked_decision")!.title)
        .toBe("Hilton San Diego");
      expect(context.lockedDecisions.find((d) => d.type === "assigned_task")!.title)
        .toBe("Bring sunscreen");
      expect(context.activeItems).toHaveLength(1);
      expect(context.activeItems[0]!.title).toBe("Nobu San Diego");

      // Generate prompt — should constrain AI
      const prompt = engine.getGroundingPrompt("trip_sd");
      expect(prompt).toContain("GROUNDING CONSTRAINTS");
      expect(prompt).toContain("Hilton San Diego");
      expect(prompt).toContain("Do NOT suggest alternatives");
    });

    it("returns permissive prompt when nothing is locked", () => {
      engine.proposeItem("trip_sd", "Option A", "", "hotel", "apify", 1000);
      const prompt = engine.getGroundingPrompt("trip_sd");
      expect(prompt).toContain("No locked decisions");
      expect(prompt).toContain("suggest any options freely");
    });
  });

  describe("Heart-Sort Queries", () => {
    it("returns ranked items with agreement scores", () => {
      const h = engine.proposeItem("trip_sd", "Hotel A", "", "hotel", "apify", 1000);
      engine.react(h.id, "alice", ReactionType.LoveIt, 1100);
      engine.react(h.id, "bob", ReactionType.LoveIt, 1200);
      engine.react(h.id, "carol", ReactionType.LoveIt, 1300);
      engine.react(h.id, "dave", ReactionType.WorksForMe, 1400);

      const ranked = engine.getRankedItems("trip_sd");
      expect(ranked).toHaveLength(1);
      expect(ranked[0]!.weightedScore).toBe(16); // 3×5 + 1×1
      expect(ranked[0]!.agreementScore).toBe(100); // 4/4 members
      expect(ranked[0]!.isGroupFavorite).toBe(true);
      expect(ranked[0]!.reactionBreakdown.hearts).toBe(3);
      expect(ranked[0]!.reactionBreakdown.thumbsUp).toBe(1);
    });

    it("excludes locked items from ranked view", () => {
      const a = engine.proposeItem("trip_sd", "A", "", "hotel", "apify", 1000);
      engine.proposeItem("trip_sd", "B", "", "hotel", "apify", 1001);

      engine.react(a.id, "alice", ReactionType.LoveIt, 1100);
      engine.lock(a.id, {
        type: "confirmation_number",
        value: "X",
        submittedBy: "alice",
        submittedAt: 2000,
      });

      const ranked = engine.getRankedItems("trip_sd");
      expect(ranked).toHaveLength(1);
      expect(ranked[0]!.title).toBe("B");
    });
  });

  describe("Reaction Rules", () => {
    it("prevents reactions on locked items", () => {
      const item = engine.proposeItem("trip_sd", "Hotel", "", "hotel", "apify", 1000);
      engine.lock(item.id, {
        type: "confirmation_number",
        value: "X",
        submittedBy: "alice",
        submittedAt: 2000,
      });

      expect(() =>
        engine.react(item.id, "bob", ReactionType.LoveIt, 3000)
      ).toThrow("locked");
    });

    it("prevents Not for me on locked items", () => {
      const item = engine.proposeItem("trip_sd", "Hotel", "", "hotel", "apify", 1000);
      engine.lock(item.id, {
        type: "confirmation_number",
        value: "X",
        submittedBy: "alice",
        submittedAt: 2000,
      });

      expect(() =>
        engine.react(item.id, "bob", ReactionType.NotForMe, 3000)
      ).toThrow("locked");
    });

    it("replaces reaction when same user reacts again", () => {
      const item = engine.proposeItem("trip_sd", "Hotel", "", "hotel", "apify", 1000);
      engine.react(item.id, "alice", ReactionType.WorksForMe, 1100);
      const updated = engine.react(item.id, "alice", ReactionType.LoveIt, 1200);

      expect(updated.weightedScore).toBe(5); // LoveIt replaces WorksForMe
      expect(updated.reactions).toHaveLength(1);
    });

    it("Not for me signal reduces score", () => {
      const item = engine.proposeItem("trip_sd", "Hotel", "", "hotel", "apify", 1000);
      engine.react(item.id, "alice", ReactionType.WorksForMe, 1100); // +1
      const updated = engine.react(item.id, "bob", ReactionType.NotForMe, 1200); // -3

      expect(updated.weightedScore).toBe(-2); // 1 + (-3) = -2
    });

    it("mixed signals: 2 Love it + 1 Not for me = 7", () => {
      const item = engine.proposeItem("trip_sd", "Hotel", "", "hotel", "apify", 1000);
      engine.react(item.id, "alice", ReactionType.LoveIt, 1100); // +5
      engine.react(item.id, "bob", ReactionType.LoveIt, 1200); // +5
      const updated = engine.react(item.id, "carol", ReactionType.NotForMe, 1300); // -3

      expect(updated.weightedScore).toBe(7); // 5 + 5 + (-3) = 7
    });
  });

  describe("Task Assignment", () => {
    it("creates and assigns tasks for non-bookable items", () => {
      const task = engine.addTask("trip_sd", "Pick meeting time", "Morning or evening?", "alice", 1000);
      expect(task.state).toBe(TaskState.Created);
      expect(task.assignee).toBeNull();

      const claimed = engine.claimTask(task.id, "bob", 2000);
      expect(claimed.state).toBe(TaskState.Assigned);
      expect(claimed.assignee).toBe("bob");

      // Carol takes over
      const reassigned = engine.claimTask(task.id, "carol", 3000);
      expect(reassigned.assignee).toBe("carol");

      // Release the task
      const released = engine.releaseTask(task.id);
      expect(released.state).toBe(TaskState.Created);
      expect(released.assignee).toBeNull();
    });

    it("emits events for task operations", () => {
      const task = engine.addTask("trip_sd", "Bring snacks", "", "alice", 1000);
      engine.claimTask(task.id, "bob", 2000);

      const taskEvents = events.filter(
        (e) => e.type === EventType.TaskCreated || e.type === EventType.TaskAssigned
      );
      expect(taskEvents).toHaveLength(2);
    });
  });

  describe("Event System", () => {
    it("supports unsubscribing", () => {
      const localEvents: EngineEvent[] = [];
      const unsub = engine.on((e) => localEvents.push(e));

      engine.proposeItem("trip_sd", "A", "", "hotel", "apify", 1000);
      expect(localEvents).toHaveLength(1);

      unsub();
      engine.proposeItem("trip_sd", "B", "", "hotel", "apify", 2000);
      expect(localEvents).toHaveLength(1); // No new events after unsubscribe
    });
  });

  describe("Edge Cases", () => {
    it("throws for non-existent item", () => {
      expect(() =>
        engine.react("nonexistent" as any, "alice", ReactionType.LoveIt, 1000)
      ).toThrow("not found");
    });

    it("handles group with no items", () => {
      expect(engine.getGroupItems("trip_sd")).toEqual([]);
      expect(engine.getLockedItems("trip_sd")).toEqual([]);
      expect(engine.getActiveItems("trip_sd")).toEqual([]);
    });

    it("handles agreement score for empty group", () => {
      const item = engine.proposeItem("trip_sd", "A", "", "hotel", "apify", 1000);
      engine.react(item.id, "alice", ReactionType.LoveIt, 1100);

      const score = engine.getAgreementScore(item.id);
      expect(score.percentage).toBe(25); // 1/4 members
      expect(score.isGroupFavorite).toBe(false);
    });
  });
});
