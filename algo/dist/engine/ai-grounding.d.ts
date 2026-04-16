/**
 * AI Grounding Module
 *
 * @hello respects locked/committed decisions. Once a commitment is confirmed,
 * the AI must ground all future suggestions to the locked state.
 *
 * Example: Once a hotel in San Diego is booked, @hello should only
 * suggest restaurants/activities *in San Diego* — not re-open the
 * destination debate. The AI respects reality, not just preference.
 */
import type { BookableItem, GroupId, Task } from "../models/types.js";
import type { StateMachine } from "./state-machine.js";
export interface GroundingConstraint {
    type: "locked_decision" | "assigned_task";
    itemId: string;
    ciphertextPayload: string;
    nonce: string;
    ownerId: string;
}
export interface GroundingContext {
    groupId: GroupId;
    lockedDecisions: GroundingConstraint[];
    activeItems: Array<{
        itemId: string;
        ciphertextPayload: string;
        nonce: string;
        weightedScore: number;
        state: string;
    }>;
}
/**
 * Builds the grounding context for @hello from all items and tasks in a group/space.
 * Locked items become hard constraints; active items are context.
 *
 * @param stateMachine Optional state machine for custom lock detection.
 */
export declare function buildGroundingContext(groupId: GroupId, items: BookableItem[], tasks: Task[], stateMachine?: StateMachine): GroundingContext;
/**
 * Generates a system prompt fragment for @hello that enforces grounding.
 * This is injected into the AI's context to prevent it from
 * undermining confirmed commitments or settled decisions.
 */
export declare function generateGroundingPrompt(context: GroundingContext): string;
/**
 * Checks whether a suggestion from @hello conflicts with locked decisions.
 * Returns the conflicting constraints if any.
 */
export declare function checkSuggestionConflicts(context: GroundingContext, suggestionCategory: string): GroundingConstraint[];
//# sourceMappingURL=ai-grounding.d.ts.map