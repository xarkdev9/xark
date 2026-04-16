import { describe, it, expect } from "vitest";
import { lockItem, transferOwnership, isLocked, getOwner, canLock, canTransferOwnership, GreenLockError, } from "../engine/green-lock.js";
import { BookableItemState } from "../models/types.js";
function makeItem(overrides = {}) {
    return {
        id: "item_1",
        groupId: "group_1",
        ciphertextPayload: "Hilton San Diego",
        nonce: "nonce",
        state: BookableItemState.Ranked,
        proposedBy: "user_1",
        proposedAt: 1000,
        reactions: [],
        weightedScore: 10,
        commitmentCiphertext: null,
        commitmentNonce: null,
        ownership: null,
        lockedAt: null,
        version: 1,
        ...overrides,
    };
}
function makeProof(overrides = {}) {
    return {
        type: "confirmation_number",
        value: "CONF-12345",
        submittedBy: "user_2",
        submittedAt: 2000,
        ...overrides,
    };
}
describe("lockItem", () => {
    it("locks an item with booking proof", () => {
        const item = makeItem();
        const proof = makeProof();
        const locked = lockItem(item, proof.value, "nonce", proof.submittedBy, proof.submittedAt);
        expect(locked.state).toBe(BookableItemState.Locked);
        expect(locked.commitmentCiphertext).toEqual(proof.value);
        expect(locked.lockedAt).toBe(2000);
    });
    it("stamps the booker as owner", () => {
        const item = makeItem();
        const proof = makeProof({ submittedBy: "user_3" });
        const locked = lockItem(item, proof.value, "nonce", proof.submittedBy, proof.submittedAt);
        expect(locked.ownership).not.toBeNull();
        expect(locked.ownership.ownerId).toBe("user_3");
        expect(locked.ownership.reason).toBe("booker");
    });
    it("records ownership details properly", () => {
        const item = makeItem();
        const proof = makeProof();
        const locked = lockItem(item, proof.value, "nonce", proof.submittedBy, proof.submittedAt);
        expect(locked.ownership).not.toBeNull();
        expect(locked.ownership.ownerId).toBe("user_2");
        expect(locked.ownership.reason).toBe("booker");
    });
    it("accepts screenshot as proof type", () => {
        const item = makeItem();
        const proof = makeProof({
            type: "screenshot",
            value: "/uploads/booking-confirmation.png",
        });
        const locked = lockItem(item, proof.value, "nonce", proof.submittedBy, proof.submittedAt);
        expect(locked.commitmentCiphertext).toBe("/uploads/booking-confirmation.png");
    });
    it("throws if item is already locked", () => {
        const item = makeItem({ state: BookableItemState.Locked });
        const proof = makeProof();
        expect(() => lockItem(item, proof.value, "nonce", proof.submittedBy, proof.submittedAt)).toThrow(GreenLockError);
        expect(() => lockItem(item, proof.value, "nonce", proof.submittedBy, proof.submittedAt)).toThrow("already locked");
    });
    it("throws if proof value is empty", () => {
        const item = makeItem();
        const proof = makeProof({ value: "   " });
        expect(() => lockItem(item, proof.value, "nonce", proof.submittedBy, proof.submittedAt)).toThrow(GreenLockError);
        expect(() => lockItem(item, proof.value, "nonce", proof.submittedBy, proof.submittedAt)).toThrow("cannot be empty");
    });
    it("does not mutate the original item", () => {
        const item = makeItem();
        const proof = makeProof();
        lockItem(item, proof.value, "nonce", proof.submittedBy, proof.submittedAt);
        expect(item.state).toBe(BookableItemState.Ranked);
        expect(item.ownership).toBeNull();
    });
});
describe("transferOwnership", () => {
    it("transfers ownership to a new user", () => {
        const item = makeItem({
            state: BookableItemState.Locked,
            ownership: { ownerId: "user_2", assignedAt: 2000, reason: "booker" },
        });
        const transferred = transferOwnership(item, "user_4", 3000);
        expect(transferred.ownership.ownerId).toBe("user_4");
        expect(transferred.ownership.reason).toBe("transfer");
    });
    it("throws if item is not locked", () => {
        const item = makeItem({ state: BookableItemState.Ranked });
        expect(() => transferOwnership(item, "user_4", 3000)).toThrow(GreenLockError);
        expect(() => transferOwnership(item, "user_4", 3000)).toThrow("not locked");
    });
    it("throws if transferring to current owner", () => {
        const item = makeItem({
            state: BookableItemState.Locked,
            ownership: { ownerId: "user_2", assignedAt: 2000, reason: "booker" },
        });
        expect(() => transferOwnership(item, "user_2", 3000)).toThrow(GreenLockError);
        expect(() => transferOwnership(item, "user_2", 3000)).toThrow("already the owner");
    });
    it("preserves booking proof after transfer", () => {
        const proof = makeProof();
        const item = makeItem({
            state: BookableItemState.Locked,
            commitmentCiphertext: proof.value,
            commitmentNonce: "nonce",
            ownership: { ownerId: "user_2", assignedAt: 2000, reason: "booker" },
        });
        const transferred = transferOwnership(item, "user_5", 3000);
        expect(transferred.commitmentCiphertext).toEqual(proof.value);
        expect(transferred.state).toBe(BookableItemState.Locked);
    });
});
describe("isLocked", () => {
    it("returns true for locked items", () => {
        expect(isLocked(makeItem({ state: BookableItemState.Locked }))).toBe(true);
    });
    it("returns false for proposed items", () => {
        expect(isLocked(makeItem({ state: BookableItemState.Proposed }))).toBe(false);
    });
    it("returns false for heart-sorted items", () => {
        expect(isLocked(makeItem({ state: BookableItemState.Ranked }))).toBe(false);
    });
});
describe("getOwner", () => {
    it("returns null when no ownership", () => {
        expect(getOwner(makeItem())).toBeNull();
    });
    it("returns owner info when owned", () => {
        const item = makeItem({
            ownership: { ownerId: "user_2", assignedAt: 2000, reason: "booker" },
        });
        const owner = getOwner(item);
        expect(owner).toEqual({ ownerId: "user_2", reason: "booker" });
    });
});
describe("canLock / canTransferOwnership", () => {
    it("canLock returns true for unlocked items", () => {
        expect(canLock(makeItem())).toBe(true);
    });
    it("canLock returns false for locked items", () => {
        expect(canLock(makeItem({ state: BookableItemState.Locked }))).toBe(false);
    });
    it("canTransferOwnership returns true when valid", () => {
        const item = makeItem({
            state: BookableItemState.Locked,
            ownership: { ownerId: "user_2", assignedAt: 2000, reason: "booker" },
        });
        expect(canTransferOwnership(item, "user_3")).toBe(true);
    });
    it("canTransferOwnership returns false for same owner", () => {
        const item = makeItem({
            state: BookableItemState.Locked,
            ownership: { ownerId: "user_2", assignedAt: 2000, reason: "booker" },
        });
        expect(canTransferOwnership(item, "user_2")).toBe(false);
    });
});
//# sourceMappingURL=green-lock.test.js.map