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

import type { BookableItem, CommitmentProof, UserId } from "../models/types.js";
import { BookableItemState } from "../models/types.js";
import type { StateMachine } from "./state-machine.js";

export class GreenLockError extends Error {
  constructor(message: string) {
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
export function commitItem(
  item: BookableItem,
  proof: CommitmentProof,
  stateMachine: StateMachine,
  requireProof = true
): BookableItem {
  if (stateMachine.isLocked(item.state as string)) {
    throw new GreenLockError(
      `Item "${item.title}" is already locked. Cannot re-lock a committed item.`
    );
  }

  if (requireProof && !proof.value.trim()) {
    throw new GreenLockError(
      "Commitment proof cannot be empty. Provide a screenshot, confirmation number, or other proof."
    );
  }

  const now = proof.submittedAt;
  const ownership = {
    ownerId: proof.submittedBy,
    assignedAt: now,
    reason: "booker" as const,
  };

  return {
    ...item,
    state: stateMachine.getLockedState() as BookableItem["state"],
    commitmentProof: proof,
    bookingProof: proof,
    ownership,
    ownershipHistory: [...item.ownershipHistory, ownership],
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
export function lockItem(
  item: BookableItem,
  bookingProof: CommitmentProof
): BookableItem {
  if (item.state === BookableItemState.Locked) {
    throw new GreenLockError(
      `Item "${item.title}" is already locked. Cannot re-lock a booked item.`
    );
  }

  if (!bookingProof.value.trim()) {
    throw new GreenLockError(
      "Commitment proof cannot be empty. Provide a screenshot, confirmation number, or other proof."
    );
  }

  const now = bookingProof.submittedAt;
  const ownership = {
    ownerId: bookingProof.submittedBy,
    assignedAt: now,
    reason: "booker" as const,
  };

  return {
    ...item,
    state: BookableItemState.Locked,
    commitmentProof: bookingProof,
    bookingProof,
    ownership,
    ownershipHistory: [...item.ownershipHistory, ownership],
    lockedAt: now,
  };
}

/**
 * Transfers ownership of a locked item to another member.
 * The new owner takes responsibility for the commitment.
 *
 * @throws GreenLockError if item is not locked
 */
export function transferOwnership(
  item: BookableItem,
  newOwnerId: UserId,
  timestamp: number,
  stateMachine?: StateMachine
): BookableItem {
  const isItemLocked = stateMachine
    ? stateMachine.isLocked(item.state as string)
    : item.state === BookableItemState.Locked;

  if (!isItemLocked) {
    throw new GreenLockError(
      `Item "${item.title}" is not locked. Only locked items can have ownership transferred.`
    );
  }

  if (item.ownership?.ownerId === newOwnerId) {
    throw new GreenLockError(
      `User is already the owner of "${item.title}".`
    );
  }

  const newOwnership = {
    ownerId: newOwnerId,
    assignedAt: timestamp,
    reason: "transfer" as const,
  };

  return {
    ...item,
    ownership: newOwnership,
    ownershipHistory: [...item.ownershipHistory, newOwnership],
  };
}

/**
 * Checks if an item is locked (has a confirmed commitment).
 * Optionally uses a state machine for custom flows.
 */
export function isLocked(item: BookableItem, stateMachine?: StateMachine): boolean {
  if (stateMachine) {
    return stateMachine.isLocked(item.state as string);
  }
  return item.state === BookableItemState.Locked;
}

/**
 * Gets the current owner of an item, if any.
 */
export function getOwner(
  item: BookableItem
): { ownerId: UserId; reason: string } | null {
  if (!item.ownership) return null;
  return {
    ownerId: item.ownership.ownerId,
    reason: item.ownership.reason,
  };
}

/**
 * Validates whether a user can lock an item.
 * Any member can lock an item by providing commitment proof.
 */
export function canLock(item: BookableItem, stateMachine?: StateMachine): boolean {
  if (stateMachine) {
    return !stateMachine.isLocked(item.state as string);
  }
  return item.state !== BookableItemState.Locked;
}

/**
 * Validates whether ownership can be transferred.
 */
export function canTransferOwnership(
  item: BookableItem,
  newOwnerId: UserId,
  stateMachine?: StateMachine
): boolean {
  const isItemLocked = stateMachine
    ? stateMachine.isLocked(item.state as string)
    : item.state === BookableItemState.Locked;

  return (
    isItemLocked &&
    item.ownership !== null &&
    item.ownership.ownerId !== newOwnerId
  );
}
