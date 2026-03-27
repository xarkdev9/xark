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
import { BookableItemState, TaskState } from "../models/types.js";
/**
 * Builds the grounding context for @xark from all items and tasks in a group.
 * Locked items become hard constraints; active items are context.
 */
export function buildGroundingContext(groupId, items, tasks) {
    const lockedDecisions = [];
    const activeItems = [];
    for (const item of items) {
        if (item.state === BookableItemState.Locked) {
            lockedDecisions.push({
                type: "locked_booking",
                itemId: item.id,
                title: item.title,
                category: item.category,
                description: item.description,
                ownerId: item.ownership?.ownerId ?? "",
            });
        }
        else {
            activeItems.push({
                itemId: item.id,
                title: item.title,
                category: item.category,
                weightedScore: item.weightedScore,
                state: item.state,
            });
        }
    }
    for (const task of tasks) {
        if (task.state === TaskState.Assigned && task.assignee) {
            lockedDecisions.push({
                type: "assigned_task",
                itemId: task.id,
                title: task.title,
                category: "task",
                description: task.description,
                ownerId: task.assignee,
            });
        }
    }
    return { groupId, lockedDecisions, activeItems };
}
/**
 * Generates a system prompt fragment for @xark that enforces grounding.
 * This is injected into the AI's context to prevent it from
 * undermining confirmed bookings or settled decisions.
 */
export function generateGroundingPrompt(context) {
    if (context.lockedDecisions.length === 0) {
        return "No locked decisions yet. You may suggest any options freely.";
    }
    const lines = [
        "GROUNDING CONSTRAINTS — You MUST respect these confirmed decisions:",
        "",
    ];
    for (const decision of context.lockedDecisions) {
        if (decision.type === "locked_booking") {
            lines.push(`- LOCKED BOOKING: "${decision.title}" (${decision.category}) is confirmed and booked. Do NOT suggest alternatives that contradict this booking. Build upon it instead.`);
        }
        else {
            lines.push(`- ASSIGNED TASK: "${decision.title}" is assigned to a member. Do NOT reassign or question this.`);
        }
    }
    lines.push("");
    lines.push("You must NOT suggest alternatives to locked bookings or re-open settled decisions. " +
        "Instead, make suggestions that complement and build upon the confirmed choices.");
    return lines.join("\n");
}
/**
 * Checks whether a suggestion from @xark conflicts with locked decisions.
 * Returns the conflicting constraints if any.
 */
export function checkSuggestionConflicts(context, suggestionCategory) {
    return context.lockedDecisions.filter((d) => d.type === "locked_booking" && d.category === suggestionCategory);
}
//# sourceMappingURL=ai-grounding.js.map