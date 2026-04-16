/**
 * Green-Lock / Commitment Engine
 *
 * The lock is triggered when a member provides proof of commitment
 * (confirmation number, receipt, contract, verbal agreement, etc.).
 *
 * Lock = real-world commitment confirmation, not a vote or arbitrary decision.
 * This makes anti-chaos natural: you can't argue with a confirmed decision.
 *
 * State lifecycle (default flow):
 *   Proposed → Ranked → Committed/Locked (with proof) → Owned → Transferable
 */
import type { BookableItem, UserId } from "../models/types.js";
import type { StateMachine } from "./state-machine.js";
export declare class GreenLockError extends Error {
    constructor(message: string);
}
/**
 * Commits/locks an item using a state machine for transitions.
 * The committer is automatically stamped as the owner.
 *
 * @throws GreenLockError if item is already in the locked state or proof is empty
 */
export declare function commitItem(item: BookableItem, commitmentCiphertext: string, commitmentNonce: string, submittedBy: UserId, submittedAt: number, stateMachine: StateMachine, requireProof?: boolean): BookableItem;
/**
 * Locks an item by providing commitment proof.
 * The committer is automatically stamped as the owner.
 * Uses the default BOOKING_FLOW state machine.
 *
 * @deprecated Use commitItem() with a StateMachine for custom flows.
 * @throws GreenLockError if item is already locked
 */
export declare function lockItem(item: BookableItem, commitmentCiphertext: string, commitmentNonce: string, submittedBy: UserId, submittedAt: number): BookableItem;
/**
 * Transfers ownership of a locked item to another member.
 * The new owner takes responsibility for the commitment.
 *
 * @throws GreenLockError if item is not locked
 */
export declare function transferOwnership(item: BookableItem, newOwnerId: UserId, timestamp: number, stateMachine?: StateMachine): BookableItem;
/**
 * Checks if an item is locked (has a confirmed commitment).
 * Optionally uses a state machine for custom flows.
 */
export declare function isLocked(item: BookableItem, stateMachine?: StateMachine): boolean;
/**
 * Gets the current owner of an item, if any.
 */
export declare function getOwner(item: BookableItem): {
    ownerId: UserId;
    reason: string;
} | null;
/**
 * Validates whether a user can lock an item.
 * Any member can lock an item by providing commitment proof.
 */
export declare function canLock(item: BookableItem, stateMachine?: StateMachine): boolean;
/**
 * Validates whether ownership can be transferred.
 */
export declare function canTransferOwnership(item: BookableItem, newOwnerId: UserId, stateMachine?: StateMachine): boolean;
//# sourceMappingURL=green-lock.d.ts.map