import { describe, it, expect } from "vitest";
import { StateMachine } from "../engine/state-machine.js";
import {
  BOOKING_FLOW,
  PURCHASE_FLOW,
  SIMPLE_VOTE_FLOW,
  SOLO_DECISION_FLOW,
} from "../engine/state-flows.js";

describe("StateMachine", () => {
  describe("BOOKING_FLOW", () => {
    const sm = new StateMachine(BOOKING_FLOW);

    it("has correct initial state", () => {
      expect(sm.getInitialState()).toBe("proposed");
    });

    it("has correct locked state", () => {
      expect(sm.getLockedState()).toBe("locked");
    });

    it("transitions proposed → ranked on reaction", () => {
      expect(sm.transition("proposed", "reaction")).toBe("ranked");
    });

    it("transitions ranked → locked on commitment", () => {
      expect(sm.transition("ranked", "commitment")).toBe("locked");
    });

    it("transitions proposed → locked on commitment (skip sort)", () => {
      expect(sm.transition("proposed", "commitment")).toBe("locked");
    });

    it("returns null for invalid transition", () => {
      expect(sm.transition("locked", "reaction")).toBeNull();
    });

    it("detects locked state", () => {
      expect(sm.isLocked("locked")).toBe(true);
      expect(sm.isLocked("proposed")).toBe(false);
      expect(sm.isLocked("ranked")).toBe(false);
    });

    it("validates canTransition", () => {
      expect(sm.canTransition("proposed", "ranked")).toBe(true);
      expect(sm.canTransition("ranked", "locked")).toBe(true);
      expect(sm.canTransition("locked", "proposed")).toBe(false);
    });

    it("returns flow name", () => {
      expect(sm.getName()).toBe("booking");
    });
  });

  describe("PURCHASE_FLOW", () => {
    const sm = new StateMachine(PURCHASE_FLOW);

    it("has correct initial and locked states", () => {
      expect(sm.getInitialState()).toBe("researching");
      expect(sm.getLockedState()).toBe("purchased");
    });

    it("follows full purchase lifecycle", () => {
      // researching → shortlisted (reaction)
      expect(sm.transition("researching", "reaction")).toBe("shortlisted");
      // shortlisted → negotiating (manual)
      expect(sm.transition("shortlisted", "manual")).toBe("negotiating");
      // negotiating → purchased (commitment)
      expect(sm.transition("negotiating", "commitment")).toBe("purchased");
    });

    it("allows skipping negotiation", () => {
      expect(sm.transition("shortlisted", "commitment")).toBe("purchased");
    });

    it("detects purchased as locked", () => {
      expect(sm.isLocked("purchased")).toBe(true);
      expect(sm.isLocked("researching")).toBe(false);
      expect(sm.isLocked("shortlisted")).toBe(false);
      expect(sm.isLocked("negotiating")).toBe(false);
    });
  });

  describe("SIMPLE_VOTE_FLOW", () => {
    const sm = new StateMachine(SIMPLE_VOTE_FLOW);

    it("has correct initial and locked states", () => {
      expect(sm.getInitialState()).toBe("nominated");
      expect(sm.getLockedState()).toBe("chosen");
    });

    it("follows nomination lifecycle", () => {
      expect(sm.transition("nominated", "reaction")).toBe("ranked");
      expect(sm.transition("ranked", "commitment")).toBe("chosen");
    });

    it("detects chosen as locked", () => {
      expect(sm.isLocked("chosen")).toBe(true);
      expect(sm.isLocked("nominated")).toBe(false);
    });
  });

  describe("SOLO_DECISION_FLOW", () => {
    const sm = new StateMachine(SOLO_DECISION_FLOW);

    it("has correct initial and locked states", () => {
      expect(sm.getInitialState()).toBe("considering");
      expect(sm.getLockedState()).toBe("decided");
    });

    it("follows solo decision lifecycle", () => {
      expect(sm.transition("considering", "reaction")).toBe("leaning");
      expect(sm.transition("leaning", "commitment")).toBe("decided");
    });

    it("allows direct decision", () => {
      expect(sm.transition("considering", "commitment")).toBe("decided");
    });

    it("detects decided as locked", () => {
      expect(sm.isLocked("decided")).toBe(true);
      expect(sm.isLocked("considering")).toBe(false);
      expect(sm.isLocked("leaning")).toBe(false);
    });
  });

  describe("Custom flow", () => {
    it("supports arbitrary state names", () => {
      const sm = new StateMachine({
        name: "wedding",
        initialState: "brainstorming",
        lockedState: "booked",
        transitions: [
          { from: "brainstorming", to: "shortlisted", trigger: "reaction" },
          { from: "shortlisted", to: "site_visit", trigger: "manual" },
          { from: "site_visit", to: "booked", trigger: "commitment" },
        ],
      });

      expect(sm.getInitialState()).toBe("brainstorming");
      expect(sm.transition("brainstorming", "reaction")).toBe("shortlisted");
      expect(sm.transition("shortlisted", "manual")).toBe("site_visit");
      expect(sm.transition("site_visit", "commitment")).toBe("booked");
      expect(sm.isLocked("booked")).toBe(true);
    });
  });
});
