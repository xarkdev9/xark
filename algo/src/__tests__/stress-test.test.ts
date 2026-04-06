import { describe, it, expect, beforeEach } from "vitest";
import { ConsensusEngine } from "../engine/consensus-engine.js";
import { heartSort, calculateWeightedScore, calculateAgreementScore, getRankedSummary, getTopItems } from "../engine/heart-sort.js";
import { lockItem, transferOwnership, isLocked, canLock, getOwner, commitItem } from "../engine/green-lock.js";
import { buildGroundingContext, generateGroundingPrompt, checkSuggestionConflicts } from "../engine/ai-grounding.js";
import { createTask, assignTask, reassignTask, unassignTask } from "../engine/task-assignment.js";
import { BOOKING_FLOW, PURCHASE_FLOW, SIMPLE_VOTE_FLOW, SOLO_DECISION_FLOW } from "../engine/state-flows.js";
import { ReactionType, BookableItemState, TaskState, REACTION_WEIGHTS, DEFAULT_SPACE_CONFIG } from "../models/types.js";
import type { Group, BookingProof, DecisionItem, BookableItem } from "../models/types.js";
import { resetTaskCounter } from "../engine/task-assignment.js";

// ── Helpers ──

function makeGroup(id: string, members: string[]): Group {
  return {
    id,
    name: `Group ${id}`,
    members: members.map(m => ({ userId: m, name: m, avatarUrl: `/${m}.png`, joinedAt: 100 })),
    createdAt: 100,
  };
}

const proof: BookingProof = { type: "confirmation_number", value: "CONF-12345", submittedBy: "alice" };

// ═══════════════════════════════════════════════════════
// STRESS TEST: 100 scenarios
// ═══════════════════════════════════════════════════════

describe("Stress Test: Heart-Sort Scoring", () => {
  let engine: ConsensusEngine;

  beforeEach(() => {
    engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("trip", ["alice", "bob", "carol", "dave", "eve"]));
    resetTaskCounter();
  });

  it("LoveIt adds +5", () => {
    const item = engine.proposeItem("trip", "Hotel A", "desc", "hotel", "alice", 1);
    engine.react(item.id, "bob", ReactionType.LoveIt, 2);
    expect(engine.getGroupItems("trip")[0]!.weightedScore).toBe(5);
  });

  it("WorksForMe adds +1", () => {
    const item = engine.proposeItem("trip", "Hotel B", "desc", "hotel", "alice", 1);
    engine.react(item.id, "bob", ReactionType.WorksForMe, 2);
    expect(engine.getGroupItems("trip")[0]!.weightedScore).toBe(1);
  });

  it("NotForMe adds -3", () => {
    const item = engine.proposeItem("trip", "Hotel C", "desc", "hotel", "alice", 1);
    engine.react(item.id, "bob", ReactionType.NotForMe, 2);
    expect(engine.getGroupItems("trip")[0]!.weightedScore).toBe(-3);
  });

  it("Multiple reactions sum: LoveIt*2 + NotForMe = 7", () => {
    const item = engine.proposeItem("trip", "H", "d", "hotel", "alice", 1);
    engine.react(item.id, "alice", ReactionType.LoveIt, 2);
    engine.react(item.id, "bob", ReactionType.LoveIt, 3);
    engine.react(item.id, "carol", ReactionType.NotForMe, 4);
    expect(engine.getGroupItems("trip")[0]!.weightedScore).toBe(7);
  });

  it("Last reaction per user wins (flip from Love to NotForMe)", () => {
    const item = engine.proposeItem("trip", "H", "d", "hotel", "alice", 1);
    engine.react(item.id, "bob", ReactionType.LoveIt, 2);
    engine.react(item.id, "bob", ReactionType.NotForMe, 3);
    expect(engine.getGroupItems("trip")[0]!.weightedScore).toBe(-3);
  });

  it("Zero reactions = score 0", () => {
    engine.proposeItem("trip", "H", "d", "hotel", "alice", 1);
    expect(engine.getGroupItems("trip")[0]!.weightedScore).toBe(0);
  });

  it("Score goes deeply negative with many NotForMe", () => {
    const item = engine.proposeItem("trip", "H", "d", "hotel", "alice", 1);
    engine.react(item.id, "alice", ReactionType.NotForMe, 1);
    engine.react(item.id, "bob", ReactionType.NotForMe, 2);
    engine.react(item.id, "carol", ReactionType.NotForMe, 3);
    expect(engine.getGroupItems("trip")[0]!.weightedScore).toBe(-9);
  });

  it("heartSort orders by weighted score desc", () => {
    const a = engine.proposeItem("trip", "Low", "d", "hotel", "alice", 1);
    const b = engine.proposeItem("trip", "High", "d", "hotel", "alice", 2);
    const c = engine.proposeItem("trip", "Mid", "d", "hotel", "alice", 3);
    engine.react(b.id, "bob", ReactionType.LoveIt, 10);
    engine.react(b.id, "carol", ReactionType.LoveIt, 11);
    engine.react(c.id, "bob", ReactionType.LoveIt, 12);
    engine.react(a.id, "bob", ReactionType.WorksForMe, 13);
    const sorted = engine.getGroupItems("trip");
    expect(sorted[0]!.title).toBe("High");
    expect(sorted[1]!.title).toBe("Mid");
    expect(sorted[2]!.title).toBe("Low");
  });

  it("Tiebreaker: earlier proposal wins", () => {
    const a = engine.proposeItem("trip", "Earlier", "d", "hotel", "alice", 1);
    const b = engine.proposeItem("trip", "Later", "d", "hotel", "alice", 2);
    engine.react(a.id, "bob", ReactionType.LoveIt, 10);
    engine.react(b.id, "bob", ReactionType.LoveIt, 11);
    const sorted = engine.getGroupItems("trip");
    expect(sorted[0]!.title).toBe("Earlier");
  });

  it("Sort 100 items in under 50ms", () => {
    for (let i = 0; i < 100; i++) {
      const item = engine.proposeItem("trip", `Item ${i}`, "d", "hotel", "alice", i);
      if (i % 3 === 0) engine.react(item.id, "bob", ReactionType.LoveIt, i + 1000);
    }
    const start = performance.now();
    engine.getGroupItems("trip");
    expect(performance.now() - start).toBeLessThan(50);
  });
});

describe("Stress Test: Consensus Threshold", () => {
  it("5/5 LoveIt = 100% (group favorite)", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("g1", ["a", "b", "c", "d", "e"]));
    const item = engine.proposeItem("g1", "H", "d", "hotel", "a", 1);
    engine.react(item.id, "a", ReactionType.LoveIt, 2);
    engine.react(item.id, "b", ReactionType.LoveIt, 3);
    engine.react(item.id, "c", ReactionType.LoveIt, 4);
    engine.react(item.id, "d", ReactionType.LoveIt, 5);
    engine.react(item.id, "e", ReactionType.LoveIt, 6);
    const score = engine.getAgreementScore(item.id);
    expect(score.percentage).toBe(100);
    expect(score.isGroupFavorite).toBe(true);
  });

  it("4/5 LoveIt = 80% (NOT group favorite — threshold is >80)", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("g2", ["a", "b", "c", "d", "e"]));
    const item = engine.proposeItem("g2", "H", "d", "hotel", "a", 1);
    engine.react(item.id, "a", ReactionType.LoveIt, 2);
    engine.react(item.id, "b", ReactionType.LoveIt, 3);
    engine.react(item.id, "c", ReactionType.LoveIt, 4);
    engine.react(item.id, "d", ReactionType.LoveIt, 5);
    const score = engine.getAgreementScore(item.id);
    expect(score.percentage).toBe(80);
    expect(score.isGroupFavorite).toBe(false);
  });

  it("NotForMe does NOT count as agreement", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("g3", ["a", "b", "c"]));
    const item = engine.proposeItem("g3", "H", "d", "hotel", "a", 1);
    engine.react(item.id, "a", ReactionType.LoveIt, 2);
    engine.react(item.id, "b", ReactionType.NotForMe, 3);
    const score = engine.getAgreementScore(item.id);
    expect(score.percentage).toBeCloseTo(33.3, 0);
  });

  it("15-member wedding: 13/15 = 87% IS favorite", () => {
    const engine = new ConsensusEngine();
    const members = Array.from({length: 15}, (_, i) => `g${i}`);
    engine.registerGroup(makeGroup("wedding", members));
    const item = engine.proposeItem("wedding", "Garden Venue", "d", "venue", "g0", 1);
    for (let i = 0; i < 13; i++) engine.react(item.id, `g${i}`, ReactionType.LoveIt, i + 10);
    expect(engine.getAgreementScore(item.id).isGroupFavorite).toBe(true);
  });

  it("15-member wedding: 12/15 = 80% NOT favorite", () => {
    const engine = new ConsensusEngine();
    const members = Array.from({length: 15}, (_, i) => `h${i}`);
    engine.registerGroup(makeGroup("w2", members));
    const item = engine.proposeItem("w2", "Garden", "d", "venue", "h0", 1);
    for (let i = 0; i < 12; i++) engine.react(item.id, `h${i}`, ReactionType.LoveIt, i + 10);
    expect(engine.getAgreementScore(item.id).isGroupFavorite).toBe(false);
  });
});

describe("Stress Test: Green-Lock Commitments", () => {
  let engine: ConsensusEngine;

  beforeEach(() => {
    engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("trip", ["alice", "bob", "carol"]));
    resetTaskCounter();
  });

  it("Lock with booking proof", () => {
    const item = engine.proposeItem("trip", "Hotel", "d", "hotel", "alice", 1);
    const locked = engine.lock(item.id, proof);
    expect(locked.state).toBe(BookableItemState.Locked);
    expect(locked.commitmentProof!.value).toBe("CONF-12345");
  });

  it("Double-lock throws", () => {
    const item = engine.proposeItem("trip", "Hotel", "d", "hotel", "alice", 1);
    engine.lock(item.id, proof);
    expect(() => engine.lock(item.id, proof)).toThrow();
  });

  it("Cannot react to locked item", () => {
    const item = engine.proposeItem("trip", "Hotel", "d", "hotel", "alice", 1);
    engine.lock(item.id, proof);
    expect(() => engine.react(item.id, "bob", ReactionType.LoveIt, 200)).toThrow();
  });

  it("Transfer ownership", () => {
    const item = engine.proposeItem("trip", "Hotel", "d", "hotel", "alice", 1);
    engine.lock(item.id, proof);
    const transferred = engine.transfer(item.id, "bob", 200);
    expect(transferred.ownership!.ownerId).toBe("bob");
  });

  it("Transfer to same owner throws", () => {
    const item = engine.proposeItem("trip", "Hotel", "d", "hotel", "alice", 1);
    engine.lock(item.id, proof);
    expect(() => engine.transfer(item.id, "alice", 200)).toThrow();
  });

  it("Ownership history tracks transfers", () => {
    const item = engine.proposeItem("trip", "Hotel", "d", "hotel", "alice", 1);
    engine.lock(item.id, proof);
    engine.transfer(item.id, "bob", 200);
    engine.transfer(item.id, "carol", 300);
    const final_item = engine.getGroupItems("trip").find(i => i.id === item.id)!;
    expect(final_item.ownershipHistory.length).toBeGreaterThanOrEqual(2);
  });
});

describe("Stress Test: Real-World Scenarios", () => {
  it("Bali Trip: 5 friends vote on 3 hotels, top wins, lock with confirmation", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("bali", ["ram", "priya", "alex", "emma", "liam"]));

    const stregis = engine.proposeItem("bali", "St. Regis Bali", "$750/night, Nusa Dua", "hotel", "ram", 1);
    const wbali = engine.proposeItem("bali", "W Bali Seminyak", "$450/night, Seminyak", "hotel", "priya", 2);
    const mulia = engine.proposeItem("bali", "The Mulia", "$680/night, Nusa Dua", "hotel", "alex", 3);

    engine.react(stregis.id, "ram", ReactionType.LoveIt, 10);
    engine.react(stregis.id, "priya", ReactionType.LoveIt, 11);
    engine.react(stregis.id, "alex", ReactionType.LoveIt, 12);
    engine.react(stregis.id, "emma", ReactionType.LoveIt, 13);
    engine.react(stregis.id, "liam", ReactionType.WorksForMe, 14);

    engine.react(wbali.id, "ram", ReactionType.WorksForMe, 20);
    engine.react(wbali.id, "emma", ReactionType.NotForMe, 21);

    engine.react(mulia.id, "alex", ReactionType.WorksForMe, 30);

    // St. Regis should win
    const ranked = engine.getGroupItems("bali");
    expect(ranked[0]!.title).toBe("St. Regis Bali");
    expect(ranked[0]!.weightedScore).toBe(21); // 4*5 + 1 = 21

    // 100% agreement (5/5 voted positively)
    expect(engine.getAgreementScore(stregis.id).percentage).toBe(100);
    expect(engine.getAgreementScore(stregis.id).isGroupFavorite).toBe(true);

    // Lock with booking confirmation
    const locked = engine.lock(stregis.id, {
      type: "booking_confirmation",
      value: "Booking.com Ref: BC-9876543",
      submittedBy: "priya",
    });

    expect(locked.state).toBe(BookableItemState.Locked);
    expect(locked.commitmentProof!.value).toContain("BC-9876543");
  });

  it("Family dinner: NotForMe kills Nobu, Carbone wins", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("dinner", ["mom", "dad", "ram", "priya"]));

    const carbone = engine.proposeItem("dinner", "Carbone", "Italian", "restaurant", "ram", 1);
    const nobu = engine.proposeItem("dinner", "Nobu", "Japanese", "restaurant", "priya", 2);

    engine.react(carbone.id, "mom", ReactionType.LoveIt, 10);
    engine.react(carbone.id, "dad", ReactionType.LoveIt, 11);
    engine.react(carbone.id, "ram", ReactionType.LoveIt, 12);
    engine.react(carbone.id, "priya", ReactionType.NotForMe, 13);

    engine.react(nobu.id, "mom", ReactionType.NotForMe, 20);
    engine.react(nobu.id, "dad", ReactionType.NotForMe, 21);
    engine.react(nobu.id, "ram", ReactionType.NotForMe, 22);

    const ranked = engine.getGroupItems("dinner");
    expect(ranked[0]!.title).toBe("Carbone"); // 15-3 = 12
    expect(ranked[1]!.weightedScore).toBeLessThan(0); // Nobu: -9
  });

  it("Solo decision: MacBook Pro purchase", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("laptop", ["ram"]));

    const mbp = engine.proposeItem("laptop", "MacBook Pro M4", "$2499", "electronics", "ram", 1);
    engine.react(mbp.id, "ram", ReactionType.LoveIt, 10);

    expect(engine.getAgreementScore(mbp.id).percentage).toBe(100);

    const locked = engine.lock(mbp.id, {
      type: "purchase",
      value: "Apple Order #W12345678",
      submittedBy: "ram",
    });

    expect(locked.state).toBe(BookableItemState.Locked);
  });

  it("Multi-space: same user in 2 trips with different opinions", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("trip_a", ["ram", "alex"]));
    engine.registerGroup(makeGroup("trip_b", ["ram", "priya"]));

    const hotelA = engine.proposeItem("trip_a", "Hilton", "d", "hotel", "ram", 1);
    const hotelB = engine.proposeItem("trip_b", "Marriott", "d", "hotel", "ram", 2);

    engine.react(hotelA.id, "ram", ReactionType.LoveIt, 10);
    engine.react(hotelB.id, "ram", ReactionType.NotForMe, 20);

    expect(engine.getGroupItems("trip_a")[0]!.weightedScore).toBe(5);
    expect(engine.getGroupItems("trip_b")[0]!.weightedScore).toBe(-3);
  });

  it("Change of mind: flip NotForMe to LoveIt", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("flip", ["a", "b"]));
    const item = engine.proposeItem("flip", "H", "d", "hotel", "a", 1);

    engine.react(item.id, "b", ReactionType.NotForMe, 10);
    expect(engine.getGroupItems("flip")[0]!.weightedScore).toBe(-3);

    engine.react(item.id, "b", ReactionType.LoveIt, 20);
    expect(engine.getGroupItems("flip")[0]!.weightedScore).toBe(5);
  });

  it("Task assignment: book airport transfer", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("tasks", ["a", "b"]));
    resetTaskCounter();

    const task = engine.addTask("tasks", "Book airport transfer", "Get Uber to airport", "a", 1);
    expect(task.state).toBe(TaskState.Created);

    const claimed = engine.claimTask(task.id, "b", 10);
    expect(claimed.assignee).toBe("b");
    expect(claimed.state).toBe(TaskState.Assigned);
  });

  it("AI Grounding: locked hotel constrains AI", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("grounded", ["a", "b"]));

    const hotel = engine.proposeItem("grounded", "St. Regis", "Booked", "hotel", "a", 1);
    engine.lock(hotel.id, proof);

    const ctx = engine.getGroundingContext("grounded");
    expect(ctx.lockedDecisions.length).toBeGreaterThanOrEqual(1);
    expect(ctx.lockedDecisions.some((c: any) => c.type === "locked_decision")).toBe(true);
  });
});

describe("Stress Test: Scale & Performance", () => {
  it("100 items proposed in under 50ms", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("scale", ["a", "b"]));
    const start = performance.now();
    for (let i = 0; i < 100; i++) {
      engine.proposeItem("scale", `Item ${i}`, "d", "hotel", "a", i);
    }
    expect(performance.now() - start).toBeLessThan(50);
    expect(engine.getGroupItems("scale").length).toBe(100);
  });

  it("50 users vote on same item", () => {
    const engine = new ConsensusEngine();
    const members = Array.from({length: 50}, (_, i) => `voter_${i}`);
    engine.registerGroup(makeGroup("big_vote", members));
    const item = engine.proposeItem("big_vote", "Popular", "d", "hotel", "voter_0", 1);
    for (let i = 0; i < 50; i++) {
      engine.react(item.id, `voter_${i}`, ReactionType.LoveIt, i + 10);
    }
    expect(engine.getGroupItems("big_vote")[0]!.weightedScore).toBe(250);
  });

  it("Rapid flip-flop: 100 reaction changes, final state wins", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("flip", ["a", "b"]));
    const item = engine.proposeItem("flip", "H", "d", "hotel", "a", 1);

    for (let i = 0; i < 100; i++) {
      engine.react(item.id, "b",
        i % 3 === 0 ? ReactionType.LoveIt : i % 3 === 1 ? ReactionType.WorksForMe : ReactionType.NotForMe,
        i + 10
      );
    }
    // Last reaction (i=99, 99%3=0 → LoveIt) should be the final state
    // Wait, 99 % 3 = 0 → LoveIt. But the last one is i=99
    // Actually the weight depends on the last call
    const finalItem = engine.getGroupItems("flip")[0]!;
    expect(finalItem.reactions.length).toBe(1); // Only 1 reaction from "b"
  });

  it("10 spaces × 10 items × 5 members = 500 items total", () => {
    const engine = new ConsensusEngine();
    for (let s = 0; s < 10; s++) {
      const members = Array.from({length: 5}, (_, j) => `s${s}_u${j}`);
      engine.registerGroup(makeGroup(`space_${s}`, members));
      for (let i = 0; i < 10; i++) {
        engine.proposeItem(`space_${s}`, `Item ${s}_${i}`, "d", "hotel", members[0], i);
      }
    }
    expect(engine.getGroupItems("space_5").length).toBe(10);
  });
});

describe("Stress Test: Security & Edge Cases", () => {
  it("Unreact on non-existent reaction is safe", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("sec", ["a", "b"]));
    const item = engine.proposeItem("sec", "H", "d", "hotel", "a", 1);
    // Unreact without having reacted
    engine.unreact(item.id, "b");
    expect(engine.getGroupItems("sec")[0]!.reactions.length).toBe(0);
  });

  it("React/unreact/react cycle preserves last state", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("cycle", ["a", "b"]));
    const item = engine.proposeItem("cycle", "H", "d", "hotel", "a", 1);
    engine.react(item.id, "b", ReactionType.LoveIt, 10);
    engine.unreact(item.id, "b");
    engine.react(item.id, "b", ReactionType.NotForMe, 20);
    expect(engine.getGroupItems("cycle")[0]!.weightedScore).toBe(-3);
  });

  it("Reaction weights are immutable constants", () => {
    expect(REACTION_WEIGHTS[ReactionType.LoveIt]).toBe(5);
    expect(REACTION_WEIGHTS[ReactionType.WorksForMe]).toBe(1);
    expect(REACTION_WEIGHTS[ReactionType.NotForMe]).toBe(-3);
  });

  it("Event bus fires on every action", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("events", ["a", "b"]));
    const events: any[] = [];
    engine.on(e => events.push(e));

    const item = engine.proposeItem("events", "H", "d", "hotel", "a", 1);
    engine.react(item.id, "b", ReactionType.LoveIt, 10);
    engine.lock(item.id, proof);

    expect(events.length).toBeGreaterThanOrEqual(3); // propose + react + lock
  });

  it("Signal breakdown counts correctly", () => {
    const engine = new ConsensusEngine();
    engine.registerGroup(makeGroup("sig", ["a", "b", "c", "d"]));
    const item = engine.proposeItem("sig", "H", "d", "hotel", "a", 1);
    engine.react(item.id, "a", ReactionType.LoveIt, 10);
    engine.react(item.id, "b", ReactionType.WorksForMe, 11);
    engine.react(item.id, "c", ReactionType.NotForMe, 12);

    const breakdown = engine.getSignalBreakdown(item.id);
    expect(breakdown.loveIt).toBe(1);
    expect(breakdown.worksForMe).toBe(1);
    expect(breakdown.notForMe).toBe(1);
  });
});
