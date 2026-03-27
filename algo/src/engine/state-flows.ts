/**
 * Preset State Flow Configurations
 *
 * Ready-made flows for common decision types.
 */

import type { StateFlowConfig } from "./state-machine.js";

/** Current default: hotels, flights, restaurants */
export const BOOKING_FLOW: StateFlowConfig = {
  name: "booking",
  initialState: "proposed",
  lockedState: "locked",
  transitions: [
    { from: "proposed", to: "ranked", trigger: "reaction" },
    { from: "ranked", to: "locked", trigger: "commitment" },
    { from: "proposed", to: "locked", trigger: "commitment" },
  ],
};

/** Cars, real estate, appliances */
export const PURCHASE_FLOW: StateFlowConfig = {
  name: "purchase",
  initialState: "researching",
  lockedState: "purchased",
  transitions: [
    { from: "researching", to: "shortlisted", trigger: "reaction" },
    { from: "shortlisted", to: "negotiating", trigger: "manual" },
    { from: "negotiating", to: "purchased", trigger: "commitment" },
    { from: "shortlisted", to: "purchased", trigger: "commitment" },
    { from: "researching", to: "purchased", trigger: "commitment" },
  ],
};

/** Restaurant tonight, movie pick, gift ideas */
export const SIMPLE_VOTE_FLOW: StateFlowConfig = {
  name: "simple_vote",
  initialState: "nominated",
  lockedState: "chosen",
  transitions: [
    { from: "nominated", to: "ranked", trigger: "reaction" },
    { from: "ranked", to: "chosen", trigger: "commitment" },
    { from: "nominated", to: "chosen", trigger: "commitment" },
  ],
};

/** Any solo decision */
export const SOLO_DECISION_FLOW: StateFlowConfig = {
  name: "solo_decision",
  initialState: "considering",
  lockedState: "decided",
  transitions: [
    { from: "considering", to: "leaning", trigger: "reaction" },
    { from: "leaning", to: "decided", trigger: "commitment" },
    { from: "considering", to: "decided", trigger: "commitment" },
  ],
};
