import { describe, it, expect, beforeEach } from "vitest";
import { RequestHandler } from "../service/request-handler.js";
import { DecisionService } from "../service/decision-service.js";
import { MemoryPersistenceAdapter } from "../adapters/memory-persistence.js";
import { MemoryEventBusAdapter } from "../adapters/memory-event-bus.js";
import { NoopAuthAdapter } from "../adapters/noop-auth.js";
import type { ServiceRequest } from "../service/request-handler.js";
import type { GroupId, UserId } from "../models/types.js";

describe("RequestHandler", () => {
  let handler: RequestHandler;
  let service: DecisionService;
  let auth: NoopAuthAdapter;

  beforeEach(() => {
    auth = new NoopAuthAdapter();
    service = new DecisionService({
      persistence: new MemoryPersistenceAdapter(),
      eventBus: new MemoryEventBusAdapter(),
      auth,
    });
    handler = new RequestHandler(service, auth);
  });

  async function request(
    method: string,
    path: string,
    body?: unknown,
    token = "alice"
  ) {
    return handler.handle({ method, path, body, token });
  }

  describe("Spaces", () => {
    it("POST /spaces creates a space", async () => {
      const res = await request("POST", "/spaces", {
        name: "Trip",
        members: [
          { userId: "alice", name: "Alice", avatarUrl: "", joinedAt: 100 },
        ],
      });
      expect(res.status).toBe(201);
      expect((res.body as any).name).toBe("Trip");
      expect((res.body as any).id).toMatch(/^space_/);
    });

    it("GET /spaces/:id retrieves a space", async () => {
      const create = await request("POST", "/spaces", {
        name: "Trip",
        members: [],
      });
      const groupId = (create.body as any).id;

      const res = await request("GET", `/spaces/${groupId}`);
      expect(res.status).toBe(200);
      expect((res.body as any).name).toBe("Trip");
    });

    it("DELETE /spaces/:id deletes a space", async () => {
      const create = await request("POST", "/spaces", {
        name: "Trip",
        members: [],
      });
      const groupId = (create.body as any).id;

      const del = await request("DELETE", `/spaces/${groupId}`);
      expect(del.status).toBe(204);

      const get = await request("GET", `/spaces/${groupId}`);
      expect(get.status).toBe(404);
    });
  });

  describe("Items", () => {
    let groupId: string;

    beforeEach(async () => {
      const res = await request("POST", "/spaces", {
        name: "Trip",
        members: [
          { userId: "alice", name: "Alice", avatarUrl: "", joinedAt: 100 },
          { userId: "bob", name: "Bob", avatarUrl: "", joinedAt: 100 },
        ],
      });
      groupId = (res.body as any).id;
    });

    it("POST /spaces/:id/items adds an item", async () => {
      const res = await request("POST", `/spaces/${groupId}/items`, {
        title: "Hilton",
        description: "Downtown",
        category: "hotel",
      });
      expect(res.status).toBe(201);
      expect((res.body as any).title).toBe("Hilton");
    });

    it("POST /items/:id/react adds a reaction", async () => {
      const item = await request("POST", `/spaces/${groupId}/items`, {
        title: "Hilton",
      });
      const itemId = (item.body as any).id;

      const res = await request("POST", `/items/${itemId}/react`, {
        reactionType: "love_it",
      });
      expect(res.status).toBe(200);
      expect((res.body as any).weightedScore).toBe(5);
    });

    it("DELETE /items/:id/react removes a reaction", async () => {
      const item = await request("POST", `/spaces/${groupId}/items`, {
        title: "Hilton",
      });
      const itemId = (item.body as any).id;

      await request("POST", `/items/${itemId}/react`, {
        reactionType: "love_it",
      });

      const res = await request("DELETE", `/items/${itemId}/react`);
      expect(res.status).toBe(200);
      expect((res.body as any).weightedScore).toBe(0);
    });

    it("GET /spaces/:id/items/ranked returns sorted items", async () => {
      const a = await request("POST", `/spaces/${groupId}/items`, {
        title: "A",
      });
      const b = await request("POST", `/spaces/${groupId}/items`, {
        title: "B",
      });

      await request("POST", `/items/${(b.body as any).id}/react`, {
        reactionType: "love_it",
      });

      const res = await request("GET", `/spaces/${groupId}/items/ranked`);
      expect(res.status).toBe(200);
      expect((res.body as any)[0].title).toBe("B");
    });

    it("POST /items/:id/lock locks an item", async () => {
      const item = await request("POST", `/spaces/${groupId}/items`, {
        title: "Hilton",
      });
      const itemId = (item.body as any).id;

      const res = await request("POST", `/items/${itemId}/lock`, {
        proofType: "confirmation_number",
        proofValue: "HILTON-99",
      });
      expect(res.status).toBe(200);
      expect((res.body as any).state).toBe("locked");
    });

    it("POST /items/:id/transfer transfers ownership", async () => {
      const item = await request("POST", `/spaces/${groupId}/items`, {
        title: "Hilton",
      });
      const itemId = (item.body as any).id;

      await request("POST", `/items/${itemId}/lock`, {
        proofValue: "X",
      });

      const res = await request("POST", `/items/${itemId}/transfer`, {
        newOwnerId: "bob",
      });
      expect(res.status).toBe(200);
      expect((res.body as any).ownership.ownerId).toBe("bob");
    });

    it("GET /items/:id/signals returns signal breakdown", async () => {
      const item = await request("POST", `/spaces/${groupId}/items`, {
        title: "Hilton",
      });
      const itemId = (item.body as any).id;

      await request("POST", `/items/${itemId}/react`, {
        reactionType: "love_it",
      });

      const res = await request("GET", `/items/${itemId}/signals`);
      expect(res.status).toBe(200);
      expect((res.body as any).loveIt).toBe(1);
    });

    it("GET /spaces/:id/items/locked returns locked items", async () => {
      const item = await request("POST", `/spaces/${groupId}/items`, {
        title: "Hilton",
      });
      const itemId = (item.body as any).id;
      await request("POST", `/items/${itemId}/lock`, { proofValue: "X" });

      const res = await request("GET", `/spaces/${groupId}/items/locked`);
      expect(res.status).toBe(200);
      expect((res.body as any)).toHaveLength(1);
    });

    it("GET /spaces/:id/items/active returns active items", async () => {
      await request("POST", `/spaces/${groupId}/items`, { title: "A" });
      await request("POST", `/spaces/${groupId}/items`, { title: "B" });

      const res = await request("GET", `/spaces/${groupId}/items/active`);
      expect(res.status).toBe(200);
      expect((res.body as any)).toHaveLength(2);
    });
  });

  describe("Tasks", () => {
    let groupId: string;

    beforeEach(async () => {
      const res = await request("POST", "/spaces", {
        name: "Trip",
        members: [],
      });
      groupId = (res.body as any).id;
    });

    it("POST /spaces/:id/tasks creates a task", async () => {
      const res = await request("POST", `/spaces/${groupId}/tasks`, {
        title: "Bring snacks",
        description: "Chips",
      });
      expect(res.status).toBe(201);
      expect((res.body as any).title).toBe("Bring snacks");
    });

    it("POST /tasks/:id/claim claims a task", async () => {
      const task = await request("POST", `/spaces/${groupId}/tasks`, {
        title: "Bring snacks",
      });
      const taskId = (task.body as any).id;

      const res = await request("POST", `/tasks/${taskId}/claim`);
      expect(res.status).toBe(200);
      expect((res.body as any).assignee).toBe("alice");
    });

    it("POST /tasks/:id/release releases a task", async () => {
      const task = await request("POST", `/spaces/${groupId}/tasks`, {
        title: "Bring snacks",
      });
      const taskId = (task.body as any).id;

      await request("POST", `/tasks/${taskId}/claim`);
      const res = await request("POST", `/tasks/${taskId}/release`);
      expect(res.status).toBe(200);
      expect((res.body as any).assignee).toBeNull();
    });
  });

  describe("AI Grounding", () => {
    let groupId: string;

    beforeEach(async () => {
      const res = await request("POST", "/spaces", {
        name: "Trip",
        members: [],
      });
      groupId = (res.body as any).id;
    });

    it("GET /spaces/:id/grounding returns context", async () => {
      const res = await request("GET", `/spaces/${groupId}/grounding`);
      expect(res.status).toBe(200);
      expect((res.body as any).lockedDecisions).toEqual([]);
    });

    it("GET /spaces/:id/grounding/prompt returns prompt", async () => {
      const res = await request("GET", `/spaces/${groupId}/grounding/prompt`);
      expect(res.status).toBe(200);
      expect((res.body as any).prompt).toContain("No locked decisions");
    });

    it("GET /spaces/:id/conflicts checks for conflicts", async () => {
      const res = await request(
        "GET",
        `/spaces/${groupId}/conflicts`,
        undefined,
        "alice"
      );
      // Need to pass query params through
      expect(res.status).toBe(200);
    });
  });

  describe("Error Handling", () => {
    it("returns 403 for missing token", async () => {
      const res = await handler.handle({
        method: "GET",
        path: "/spaces/x",
      });
      expect(res.status).toBe(403);
    });

    it("returns 404 for unknown routes", async () => {
      const res = await request("GET", "/nonexistent");
      expect(res.status).toBe(404);
    });

    it("returns 404 for non-existent items", async () => {
      const res = await request("GET", "/items/nonexistent");
      expect(res.status).toBe(404);
    });

    it("returns 400 for locked item reactions", async () => {
      const space = await request("POST", "/spaces", {
        name: "Trip",
        members: [],
      });
      const groupId = (space.body as any).id;

      const item = await request("POST", `/spaces/${groupId}/items`, {
        title: "Hotel",
      });
      const itemId = (item.body as any).id;

      await request("POST", `/items/${itemId}/lock`, { proofValue: "X" });

      const res = await request("POST", `/items/${itemId}/react`, {
        reactionType: "love_it",
      });
      expect(res.status).toBe(400);
    });
  });
});
