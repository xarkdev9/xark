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
import { BookableItemState } from "../models/types.js";
export class GreenLockError extends Error {
    constructor(message) {
        super(message);
        this.name = "GreenLockError";
    }
}
/**
 * Commits/locks an item using a state machine for transitions.
 * The committer is automatically stamped as the owner.
 *
 * @throws GreenLockError if item is already in the locked state or proof is empty
 */
export function commitItem(item, commitmentCiphertext, commitmentNonce, submittedBy, submittedAt, stateMachine, requireProof = true) {
    if (stateMachine.isLocked(item.state)) {
        throw new GreenLockError(`Item is already locked. Cannot re-lock a committed item.`);
    }
    if (requireProof && !commitmentCiphertext.trim()) {
        throw new GreenLockError("Commitment proof cannot be empty. Provide a screenshot, confirmation number, or other proof.");
    }
    const now = submittedAt;
    const ownership = {
        ownerId: submittedBy,
        assignedAt: now,
        reason: "booker",
    };
    return {
        ...item,
        state: stateMachine.getLockedState(),
        commitmentCiphertext,
        commitmentNonce,
        ownership,
        lockedAt: now,
    };
}
/**
 * Locks an item by providing commitment proof.
 * The committer is automatically stamped as the owner.
 * Uses the default BOOKING_FLOW state machine.
 *
 * @deprecated Use commitItem() with a StateMachine for custom flows.
 * @throws GreenLockError if item is already locked
 */
export function lockItem(item, commitmentCiphertext, commitmentNonce, submittedBy, submittedAt) {
    if (item.state === BookableItemState.Locked) {
        throw new GreenLockError(`Item is already locked. Cannot re-lock a booked item.`);
    }
    if (!commitmentCiphertext.trim()) {
        throw new GreenLockError("Commitment proof cannot be empty. Provide a screenshot, confirmation number, or other proof.");
    }
    const now = submittedAt;
    const ownership = {
        ownerId: submittedBy,
        assignedAt: now,
        reason: "booker",
    };
    return {
        ...item,
        state: BookableItemState.Locked,
        commitmentCiphertext,
        commitmentNonce,
        ownership,
        lockedAt: now,
    };
}
/**
 * Transfers ownership of a locked item to another member.
 * The new owner takes responsibility for the commitment.
 *
 * @throws GreenLockError if item is not locked
 */
export function transferOwnership(item, newOwnerId, timestamp, stateMachine) {
    const isItemLocked = stateMachine
        ? stateMachine.isLocked(item.state)
        : item.state === BookableItemState.Locked;
    if (!isItemLocked) {
        throw new GreenLockError(`Item is not locked. Only locked items can have ownership transferred.`);
    }
    if (item.ownership?.ownerId === newOwnerId) {
        throw new GreenLockError(`User is already the owner.`);
    }
    const newOwnership = {
        ownerId: newOwnerId,
        assignedAt: timestamp,
        reason: "transfer",
    };
    return {
        ...item,
        ownership: newOwnership,
    };
}
/**
 * Checks if an item is locked (has a confirmed commitment).
 * Optionally uses a state machine for custom flows.
 */
export function isLocked(item, stateMachine) {
    if (stateMachine) {
        return stateMachine.isLocked(item.state);
    }
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
 * Any member can lock an item by providing commitment proof.
 */
export function canLock(item, stateMachine) {
    if (stateMachine) {
        return !stateMachine.isLocked(item.state);
    }
    return item.state !== BookableItemState.Locked;
}
/**
 * Validates whether ownership can be transferred.
 */
export function canTransferOwnership(item, newOwnerId, stateMachine) {
    const isItemLocked = stateMachine
        ? stateMachine.isLocked(item.state)
        : item.state === BookableItemState.Locked;
    return (isItemLocked &&
        item.ownership !== null &&
        item.ownership.ownerId !== newOwnerId);
}
//# sourceMappingURL=green-lock.js.map