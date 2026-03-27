/**
 * Core types for Xark's Green-Lock Consensus Engine.
 *
 * Two parallel systems:
 * 1. Green-Lock Engine — for bookable items (hotels, flights, restaurants)
 *    Proposed → Heart-Sorted → Booked/Locked → Owned → Transferable
 * 2. Task Assignment — for non-bookable items (time, who brings snacks)
 *    Created → Assigned → Owned
 */
// --- Reactions ---
export var ReactionType;
(function (ReactionType) {
    ReactionType["Heart"] = "heart";
    ReactionType["ThumbsUp"] = "thumbs_up";
})(ReactionType || (ReactionType = {}));
export const REACTION_WEIGHTS = {
    [ReactionType.Heart]: 5,
    [ReactionType.ThumbsUp]: 1,
};
// --- Bookable Item States (Green-Lock Engine) ---
export var BookableItemState;
(function (BookableItemState) {
    BookableItemState["Proposed"] = "proposed";
    BookableItemState["HeartSorted"] = "heart_sorted";
    BookableItemState["Locked"] = "locked";
})(BookableItemState || (BookableItemState = {}));
// --- Task States (Non-bookable items) ---
export var TaskState;
(function (TaskState) {
    TaskState["Created"] = "created";
    TaskState["Assigned"] = "assigned";
})(TaskState || (TaskState = {}));
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
})(EventType || (EventType = {}));
//# sourceMappingURL=types.js.map