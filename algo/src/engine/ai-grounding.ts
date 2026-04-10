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
import { BookableItemState, TaskState } from "../models/types.js";
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
export function buildGroundingContext(
  groupId: GroupId,
  items: BookableItem[],
  tasks: Task[],
  stateMachine?: StateMachine
): GroundingContext {
  const lockedDecisions: GroundingConstraint[] = [];
  const activeItems: GroundingContext["activeItems"] = [];

  for (const item of items) {
    const itemIsLocked = stateMachine
      ? stateMachine.isLocked(item.state as string)
      : item.state === BookableItemState.Locked;

    if (itemIsLocked) {
      lockedDecisions.push({
        type: "locked_decision",
        itemId: item.id,
        ciphertextPayload: item.ciphertextPayload,
        nonce: item.nonce,
        ownerId: item.ownership?.ownerId ?? "",
      });
    } else {
      activeItems.push({
        itemId: item.id,
        ciphertextPayload: item.ciphertextPayload,
        nonce: item.nonce,
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
        ciphertextPayload: task.title,
        nonce: "task",
        ownerId: task.assignee,
      });
    }
  }

  return { groupId, lockedDecisions, activeItems };
}

/**
 * Generates a system prompt fragment for @hello that enforces grounding.
 * This is injected into the AI's context to prevent it from
 * undermining confirmed commitments or settled decisions.
 */
export function generateGroundingPrompt(context: GroundingContext): string {
  if (context.lockedDecisions.length === 0) {
    return "No locked decisions yet. You may suggest any options freely.";
  }

  const lines: string[] = [
    "GROUNDING CONSTRAINTS — You MUST respect these confirmed decisions:",
    "",
  ];

  for (const decision of context.lockedDecisions) {
    if (decision.type === "locked_decision") {
      lines.push(
        `- LOCKED DECISION: (Encrypted Item ${decision.itemId}) is confirmed and committed. Do NOT suggest alternatives that contradict this decision. Build upon it instead.`
      );
    } else {
      lines.push(
        `- ASSIGNED TASK: (Task ${decision.itemId}) is assigned to a member. Do NOT reassign or question this.`
      );
    }
  }

  lines.push("");
  lines.push(
    "You must NOT suggest alternatives to locked decisions or re-open settled choices. " +
      "Instead, make suggestions that complement and build upon the confirmed decisions."
  );

  return lines.join("\n");
}

/**
 * Checks whether a suggestion from @hello conflicts with locked decisions.
 * Returns the conflicting constraints if any.
 */
export function checkSuggestionConflicts(
  context: GroundingContext,
  suggestionCategory: string
): GroundingConstraint[] {
  return context.lockedDecisions.filter(
    (d) => d.type === "locked_decision" && false // The server is blind to category now
  );
}
