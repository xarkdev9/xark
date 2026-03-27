import { describe, it, expect } from "vitest";
import { ConsensusEngine } from "../engine/consensus-engine.js";
import { StateMachine } from "../engine/state-machine.js";
import {
  PURCHASE_FLOW,
  SIMPLE_VOTE_FLOW,
  SOLO_DECISION_FLOW,
} from "../engine/state-flows.js";
import { ReactionType, DEFAULT_SPACE_CONFIG } from "../models/types.js";
import type { DecisionSpace, Group } from "../models/types.js";

function makeSpace(overrides: Partial<DecisionSpace> = {}): DecisionSpace {
  return {
    id: "space_1",
    name: "Test Space",
    members: [
      { userId: "alice", name: "Alice", avatarUrl: "", joinedAt: 100 },
    ],
    config: { ...DEFAULT_SPACE_CONFIG },
    createdAt: 100,
    ...overrides,
  };
}

describe("Universal Scenarios", () => {
  describe("Solo car purchase (1 person, PURCHASE_FLOW)", () => {
    it("completes solo car purchase lifecycle", () => {
      const engine = new ConsensusEngine();
      const space = makeSpace({
        id: "car_purchase",
        name: "My Car Search",
        config: {
          ...DEFAULT_SPACE_CONFIG,
          allowSelfReaction: true,
          requireProofForLock: true,
        },
      });
      engine.createSpace(space);
      engine.setStateMachine("car_purchase", new StateMachine(PURCHASE_FLOW));

      // Propose options
      const civic = engine.addItem("car_purchase", "Honda Civic 2025", "Reliable sedan", "sedan", "alice", 1000);
      const camry = engine.addItem("car_purchase", "Toyota Camry 2025", "Comfortable sedan", "sedan", "alice", 1001);
      const model3 = engine.addItem("car_purchase", "Tesla Model 3", "Electric", "ev", "alice", 1002);

      expect(civic.state).toBe("researching");
      expect(civic.category).toBe("sedan");

      // React to favorites
      engine.react(civic.id, "alice", ReactionType.LoveIt, 2000);
      engine.react(camry.id, "alice", ReactionType.WorksForMe, 2001);

      // Check items transitioned to "shortlisted"
      const civicAfter = engine.getItem(civic.id)!;
      expect(civicAfter.state).toBe("shortlisted");

      // Sort order: Civic (5) > Camry (1) > Model 3 (0)
      const sorted = engine.getGroupItems("car_purchase");
      expect(sorted[0]!.title).toBe("Honda Civic 2025");
      expect(sorted[1]!.title).toBe("Toyota Camry 2025");
      expect(sorted[2]!.title).toBe("Tesla Model 3");

      // Purchase the Civic
      const locked = engine.lock(civic.id, {
        type: "receipt",
        value: "HONDA-DEALER-78432",
        submittedBy: "alice",
        submittedAt: 3000,
      });

      expect(locked.state).toBe("purchased");
      expect(locked.ownership!.ownerId).toBe("alice");

      // Verify locked vs active
      const lockedItems = engine.getLockedItems("car_purchase");
      expect(lockedItems).toHaveLength(1);
      expect(lockedItems[0]!.title).toBe("Honda Civic 2025");

      const activeItems = engine.getActiveItems("car_purchase");
      expect(activeItems).toHaveLength(2);
    });
  });

  describe("50-person wedding planning (SIMPLE_VOTE_FLOW)", () => {
    it("handles large group venue selection", () => {
      const members = Array.from({ length: 50 }, (_, i) => ({
        userId: `member_${i}`,
        name: `Member ${i}`,
        avatarUrl: "",
        joinedAt: 100,
      }));

      const engine = new ConsensusEngine();
      const space = makeSpace({
        id: "wedding",
        name: "Sarah & Tom Wedding",
        members,
        config: {
          ...DEFAULT_SPACE_CONFIG,
          groupFavoriteThreshold: 60, // Lower threshold for large groups
        },
      });
      engine.createSpace(space);
      engine.setStateMachine("wedding", new StateMachine(SIMPLE_VOTE_FLOW));

      // Propose venues
      const garden = engine.addItem("wedding", "Rose Garden Estate", "Outdoor venue", "venue", "member_0", 1000);
      const ballroom = engine.addItem("wedding", "Grand Ballroom", "Indoor, 500 cap", "venue", "member_0", 1001);
      const beach = engine.addItem("wedding", "Sunset Beach Club", "Oceanfront", "venue", "member_0", 1002);

      expect(garden.state).toBe("nominated");

      // 35 people heart the garden, 10 thumbs-up the ballroom, 5 heart the beach
      for (let i = 0; i < 35; i++) {
        engine.react(garden.id, `member_${i}`, ReactionType.LoveIt, 2000 + i);
      }
      for (let i = 35; i < 45; i++) {
        engine.react(ballroom.id, `member_${i}`, ReactionType.WorksForMe, 2100 + i);
      }
      for (let i = 45; i < 50; i++) {
        engine.react(beach.id, `member_${i}`, ReactionType.LoveIt, 2200 + i);
      }

      // Garden should be ranked first with agreement > 60%
      const ranked = engine.getRankedItems("wedding");
      expect(ranked[0]!.title).toBe("Rose Garden Estate");
      expect(ranked[0]!.weightedScore).toBe(175); // 35 × 5
      expect(ranked[0]!.agreementScore).toBe(70); // 35/50 = 70%
      expect(ranked[0]!.isGroupFavorite).toBe(true); // >60% threshold

      // Items should be in "ranked" state after reactions
      const gardenAfter = engine.getItem(garden.id)!;
      expect(gardenAfter.state).toBe("ranked");

      // Choose the garden
      const chosen = engine.lock(garden.id, {
        type: "contract",
        value: "ROSE-GARDEN-CONTRACT-2026",
        submittedBy: "member_0",
        submittedAt: 5000,
      });

      expect(chosen.state).toBe("chosen");
      expect(chosen.ownership!.ownerId).toBe("member_0");

      // Verify grounding prompt mentions the chosen venue
      const prompt = engine.getGroundingPrompt("wedding");
      expect(prompt).toContain("Rose Garden Estate");
      expect(prompt).toContain("GROUNDING CONSTRAINTS");
    });
  });

  describe("4-friend restaurant pick (SIMPLE_VOTE_FLOW)", () => {
    it("quick restaurant selection for tonight", () => {
      const engine = new ConsensusEngine();
      const space = makeSpace({
        id: "dinner",
        name: "Friday Dinner",
        members: [
          { userId: "alex", name: "Alex", avatarUrl: "", joinedAt: 100 },
          { userId: "beth", name: "Beth", avatarUrl: "", joinedAt: 100 },
          { userId: "cody", name: "Cody", avatarUrl: "", joinedAt: 100 },
          { userId: "dana", name: "Dana", avatarUrl: "", joinedAt: 100 },
        ],
      });
      engine.createSpace(space);
      engine.setStateMachine("dinner", new StateMachine(SIMPLE_VOTE_FLOW));

      // Nominate restaurants
      const sushi = engine.addItem("dinner", "Sushi Ota", "Best sushi in town", "restaurant", "alex", 1000);
      const tacos = engine.addItem("dinner", "Tacos El Gordo", "Street tacos", "restaurant", "beth", 1001);
      const pizza = engine.addItem("dinner", "Pizzeria Luigi", "Wood-fired pizza", "restaurant", "cody", 1002);

      // Everyone loves sushi
      engine.react(sushi.id, "alex", ReactionType.LoveIt, 2000);
      engine.react(sushi.id, "beth", ReactionType.LoveIt, 2001);
      engine.react(sushi.id, "cody", ReactionType.WorksForMe, 2002);
      engine.react(sushi.id, "dana", ReactionType.LoveIt, 2003);

      // Agreement should be 100%
      const score = engine.getAgreementScore(sushi.id);
      expect(score.percentage).toBe(100);
      expect(score.isGroupFavorite).toBe(true);

      // Choose sushi
      const chosen = engine.lock(sushi.id, {
        type: "verbal",
        value: "Reservation at 7pm",
        submittedBy: "alex",
        submittedAt: 3000,
      });

      expect(chosen.state).toBe("chosen");

      // Can't react to chosen restaurant
      expect(() =>
        engine.react(sushi.id, "dana", ReactionType.LoveIt, 4000)
      ).toThrow("locked");
    });
  });

  describe("Solo decision (SOLO_DECISION_FLOW)", () => {
    it("one person deciding on daycare", () => {
      const engine = new ConsensusEngine();
      const space = makeSpace({
        id: "daycare",
        name: "Daycare Decision",
        config: {
          ...DEFAULT_SPACE_CONFIG,
          allowSelfReaction: true,
        },
      });
      engine.createSpace(space);
      engine.setStateMachine("daycare", new StateMachine(SOLO_DECISION_FLOW));

      // Consider options
      const sunshine = engine.addItem("daycare", "Sunshine Academy", "Montessori, $2k/mo", "daycare", "alice", 1000);
      const happy = engine.addItem("daycare", "Happy Kids", "Play-based, $1.5k/mo", "daycare", "alice", 1001);

      expect(sunshine.state).toBe("considering");

      // Lean toward Sunshine
      engine.react(sunshine.id, "alice", ReactionType.LoveIt, 2000);
      const sunshineAfter = engine.getItem(sunshine.id)!;
      expect(sunshineAfter.state).toBe("leaning");

      // Decide
      const decided = engine.lock(sunshine.id, {
        type: "contract",
        value: "SUNSHINE-ENROLLMENT-2026",
        submittedBy: "alice",
        submittedAt: 3000,
      });

      expect(decided.state).toBe("decided");
      expect(decided.ownership!.ownerId).toBe("alice");
    });
  });

  describe("Multiple spaces per user", () => {
    it("one user participates in multiple independent spaces", () => {
      const engine = new ConsensusEngine();

      // Space 1: Solo car purchase
      const carSpace = makeSpace({
        id: "car",
        name: "Car Purchase",
        members: [{ userId: "alice", name: "Alice", avatarUrl: "", joinedAt: 100 }],
      });
      engine.createSpace(carSpace);
      engine.setStateMachine("car", new StateMachine(PURCHASE_FLOW));

      // Space 2: Group dinner
      const dinnerSpace = makeSpace({
        id: "dinner",
        name: "Friday Dinner",
        members: [
          { userId: "alice", name: "Alice", avatarUrl: "", joinedAt: 100 },
          { userId: "bob", name: "Bob", avatarUrl: "", joinedAt: 100 },
        ],
      });
      engine.createSpace(dinnerSpace);
      engine.setStateMachine("dinner", new StateMachine(SIMPLE_VOTE_FLOW));

      // Add items to each space
      const civic = engine.addItem("car", "Honda Civic", "Sedan", "sedan", "alice", 1000);
      const sushi = engine.addItem("dinner", "Sushi Place", "Good sushi", "restaurant", "alice", 1001);

      // Items have different initial states based on their space's flow
      expect(civic.state).toBe("researching");
      expect(sushi.state).toBe("nominated");

      // Items are isolated per space
      const carItems = engine.getGroupItems("car");
      const dinnerItems = engine.getGroupItems("dinner");
      expect(carItems).toHaveLength(1);
      expect(carItems[0]!.title).toBe("Honda Civic");
      expect(dinnerItems).toHaveLength(1);
      expect(dinnerItems[0]!.title).toBe("Sushi Place");
    });
  });

  describe("Pagination", () => {
    it("supports offset/limit on getGroupItems", () => {
      const engine = new ConsensusEngine();
      const group: Group = {
        id: "g1",
        name: "Test",
        members: [{ userId: "alice", name: "Alice", avatarUrl: "", joinedAt: 100 }],
        createdAt: 100,
      };
      engine.registerGroup(group);

      // Add 10 items
      for (let i = 0; i < 10; i++) {
        engine.proposeItem("g1", `Item ${i}`, "", "other", "alice", 1000 + i);
      }

      const page1 = engine.getGroupItems("g1", { offset: 0, limit: 3 });
      expect(page1).toHaveLength(3);

      const page2 = engine.getGroupItems("g1", { offset: 3, limit: 3 });
      expect(page2).toHaveLength(3);

      const all = engine.getGroupItems("g1");
      expect(all).toHaveLength(10);

      // Pages shouldn't overlap
      const page1Ids = page1.map((i) => i.id);
      const page2Ids = page2.map((i) => i.id);
      for (const id of page1Ids) {
        expect(page2Ids).not.toContain(id);
      }
    });
  });

  describe("Custom reaction weights", () => {
    it("uses space-specific reaction weights", () => {
      const engine = new ConsensusEngine();
      const space = makeSpace({
        id: "custom",
        name: "Custom Weights",
        config: {
          ...DEFAULT_SPACE_CONFIG,
          reactionWeights: {
            [ReactionType.LoveIt]: 10,  // Double the default
            [ReactionType.WorksForMe]: 3, // Triple the default
            [ReactionType.NotForMe]: -5, // Custom negative weight
          },
        },
      });
      engine.createSpace(space);

      const item = engine.addItem("custom", "Test", "", "other", "alice", 1000);
      const reacted = engine.react(item.id, "alice", ReactionType.LoveIt, 2000);

      // Should use custom weight of 10, not default of 5
      expect(reacted.weightedScore).toBe(10);
    });
  });

  describe("Open string categories", () => {
    it("accepts any string as category", () => {
      const engine = new ConsensusEngine();
      const group: Group = {
        id: "g1",
        name: "Test",
        members: [],
        createdAt: 100,
      };
      engine.registerGroup(group);

      // All of these should work — no enum restriction
      const sedan = engine.proposeItem("g1", "Honda", "", "sedan", "alice", 1000);
      const venue = engine.proposeItem("g1", "Rose Garden", "", "wedding_venue", "alice", 1001);
      const daycare = engine.proposeItem("g1", "Sunshine", "", "daycare", "alice", 1002);
      const insurance = engine.proposeItem("g1", "Geico", "", "insurance_plan", "alice", 1003);

      expect(sedan.category).toBe("sedan");
      expect(venue.category).toBe("wedding_venue");
      expect(daycare.category).toBe("daycare");
      expect(insurance.category).toBe("insurance_plan");
    });
  });
});
