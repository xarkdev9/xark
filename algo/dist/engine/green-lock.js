/**
 * Green-Lock Engine
 *
 * The lock is triggered when a group member actually makes a booking
 * and provides proof (screenshot or confirmation number).
 *
 * Lock = real-world booking confirmation, not a vote or arbitrary decision.
 * This makes anti-chaos natural: you can't argue with "we already booked the Hilton."
 *
 * State lifecycle:
 *   Proposed → Heart-Sorted → Booked/Locked (with proof) → Owned → Transferable
 */
import { BookableItemState } from "../models/types.js";
export class GreenLockError extends Error {
    constructor(message) {
        super(message);
        this.name = "GreenLockError";
    }
}
/**
 * Locks an item by providing booking confirmation.
 * The booker is automatically stamped as the owner.
 *
 * @throws GreenLockError if item is already locked
 */
export function lockItem(item, bookingProof) {
    if (item.state === BookableItemState.Locked) {
        throw new GreenLockError(`Item "${item.title}" is already locked. Cannot re-lock a booked item.`);
    }
    if (!bookingProof.value.trim()) {
        throw new GreenLockError("Booking proof cannot be empty. Provide a screenshot or confirmation number.");
    }
    const now = bookingProof.submittedAt;
    const ownership = {
        ownerId: bookingProof.submittedBy,
        assignedAt: now,
        reason: "booker",
    };
    return {
        ...item,
        state: BookableItemState.Locked,
        bookingProof,
        ownership,
        ownershipHistory: [...item.ownershipHistory, ownership],
        lockedAt: now,
    };
}
/**
 * Transfers ownership of a locked item to another member.
 * The new owner takes responsibility for the booking.
 *
 * @throws GreenLockError if item is not locked
 */
export function transferOwnership(item, newOwnerId, timestamp) {
    if (item.state !== BookableItemState.Locked) {
        throw new GreenLockError(`Item "${item.title}" is not locked. Only locked items can have ownership transferred.`);
    }
    if (item.ownership?.ownerId === newOwnerId) {
        throw new GreenLockError(`User is already the owner of "${item.title}".`);
    }
    const newOwnership = {
        ownerId: newOwnerId,
        assignedAt: timestamp,
        reason: "transfer",
    };
    return {
        ...item,
        ownership: newOwnership,
        ownershipHistory: [...item.ownershipHistory, newOwnership],
    };
}
/**
 * Checks if an item is locked (has a confirmed booking).
 */
export function isLocked(item) {
    return item.state === BookableItemState.Locked;
}
/**
 * Gets the current owner of an item, if any.
 */
export function getOwner(item) {
    if (!item.ownership)
        return null;
    return {
        ownerId: item.ownership.ownerId,
        reason: item.ownership.reason,
    };
}
/**
 * Validates whether a user can lock an item.
 * Any group member can lock an item by providing booking proof.
 */
export function canLock(item) {
    return item.state !== BookableItemState.Locked;
}
/**
 * Validates whether ownership can be transferred.
 */
export function canTransferOwnership(item, newOwnerId) {
    return (item.state === BookableItemState.Locked &&
        item.ownership !== null &&
        item.ownership.ownerId !== newOwnerId);
}
//# sourceMappingURL=green-lock.js.map