/**
 * AI Grounding Module
 *
 * @xark respects locked decisions. Once a booking is confirmed,
 * the AI must ground all future suggestions to the locked state.
 *
 * Example: Once a hotel in San Diego is booked, @xark should only
 * suggest restaurants/activities *in San Diego* — not re-open the
 * destination debate. The AI respects reality, not just preference.
 */
import type { BookableItem, GroupId, Task } from "../models/types.js";
export interface GroundingConstraint {
    type: "locked_booking" | "assigned_task";
    itemId: string;
    title: string;
    category: string;
    description: string;
    ownerId: string;
}
export interface GroundingContext {
    groupId: GroupId;
    lockedDecisions: GroundingConstraint[];
    activeItems: Array<{
        itemId: string;
        title: string;
        category: string;
        weightedScore: number;
        state: string;
    }>;
}
/**
 * Builds the grounding context for @xark from all items and tasks in a group.
 * Locked items become hard constraints; active items are context.
 */
export declare function buildGroundingContext(groupId: GroupId, items: BookableItem[], tasks: Task[]): GroundingContext;
/**
 * Generates a system prompt fragment for @xark that enforces grounding.
 * This is injected into the AI's context to prevent it from
 * undermining confirmed bookings or settled decisions.
 */
export declare function generateGroundingPrompt(context: GroundingContext): string;
/**
 * Checks whether a suggestion from @xark conflicts with locked decisions.
 * Returns the conflicting constraints if any.
 */
export declare function checkSuggestionConflicts(context: GroundingContext, suggestionCategory: string): GroundingConstraint[];
//# sourceMappingURL=ai-grounding.d.ts.map