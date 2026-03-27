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
import type { BookableItem, BookingProof, UserId } from "../models/types.js";
export declare class GreenLockError extends Error {
    constructor(message: string);
}
/**
 * Locks an item by providing booking confirmation.
 * The booker is automatically stamped as the owner.
 *
 * @throws GreenLockError if item is already locked
 */
export declare function lockItem(item: BookableItem, bookingProof: BookingProof): BookableItem;
/**
 * Transfers ownership of a locked item to another member.
 * The new owner takes responsibility for the booking.
 *
 * @throws GreenLockError if item is not locked
 */
export declare function transferOwnership(item: BookableItem, newOwnerId: UserId, timestamp: number): BookableItem;
/**
 * Checks if an item is locked (has a confirmed booking).
 */
export declare function isLocked(item: BookableItem): boolean;
/**
 * Gets the current owner of an item, if any.
 */
export declare function getOwner(item: BookableItem): {
    ownerId: UserId;
    reason: string;
} | null;
/**
 * Validates whether a user can lock an item.
 * Any group member can lock an item by providing booking proof.
 */
export declare function canLock(item: BookableItem): boolean;
/**
 * Validates whether ownership can be transferred.
 */
export declare function canTransferOwnership(item: BookableItem, newOwnerId: UserId): boolean;
//# sourceMappingURL=green-lock.d.ts.map