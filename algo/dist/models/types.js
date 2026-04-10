/**
 * Core types for hello's Universal Decision Engine.
 *
 * Two parallel systems:
 * 1. Decision Engine — for any decidable item (hotels, cars, venues, schools…)
 *    State flow is configurable per DecisionSpace.
 * 2. Task Assignment — for non-decidable items (time, who brings snacks)
 *    Created → Assigned → Owned
 */
// --- Reactions ---
export var ReactionType;
(function (ReactionType) {
    ReactionType["LoveIt"] = "love_it";
    ReactionType["WorksForMe"] = "works_for_me";
    ReactionType["NotForMe"] = "not_for_me";
    // Deprecated aliases (same string values as new names)
    ReactionType["Heart"] = "love_it";
    ReactionType["ThumbsUp"] = "works_for_me";
})(ReactionType || (ReactionType = {}));
export const REACTION_WEIGHTS = {
    [ReactionType.LoveIt]: 5,
    [ReactionType.WorksForMe]: 1,
    [ReactionType.NotForMe]: -3,
};
// --- Decision Item States ---
export var BookableItemState;
(function (BookableItemState) {
    BookableItemState["Proposed"] = "proposed";
    BookableItemState["Ranked"] = "ranked";
    BookableItemState["Locked"] = "locked";
    // Deprecated alias
    BookableItemState["HeartSorted"] = "heart_sorted";
})(BookableItemState || (BookableItemState = {}));
// --- Task States (Non-bookable items) ---
export var TaskState;
(function (TaskState) {
    TaskState["Created"] = "created";
    TaskState["Assigned"] = "assigned";
})(TaskState || (TaskState = {}));
// Default config matching current behavior
export const DEFAULT_SPACE_CONFIG = {
    reactionWeights: {
        [ReactionType.LoveIt]: 5,
        [ReactionType.WorksForMe]: 1,
        [ReactionType.NotForMe]: -3,
    },
    groupFavoriteThreshold: 80,
    allowSelfReaction: true,
    requireProofForLock: true,
};
// --- Events ---
export var EventType;
(function (EventType) {
    EventType["ItemProposed"] = "item_proposed";
    EventType["ReactionAdded"] = "reaction_added";
    EventType["ReactionRemoved"] = "reaction_removed";
    EventType["ItemLocked"] = "item_locked";
    EventType["OwnershipTransferred"] = "ownership_transferred";
    EventType["TaskCreated"] = "task_created";
    EventType["TaskAssigned"] = "task_assigned";
    EventType["TaskReleased"] = "task_released";
})(EventType || (EventType = {}));
//# sourceMappingURL=types.js.map