/**
 * Request Handler — Framework-Agnostic HTTP Layer
 *
 * Maps HTTP-like requests to DecisionService methods.
 * Works with ANY framework: Express, Fastify, Hono, Koa,
 * AWS Lambda, Cloudflare Workers, Deno Deploy, Bun.serve, etc.
 *
 * Your framework adapter just converts its native request into
 * a ServiceRequest and calls handler.handle(). Example:
 *
 *   // Express
 *   app.all('/api/*', async (req, res) => {
 *     const result = await handler.handle({
 *       method: req.method,
 *       path: req.path.replace('/api', ''),
 *       body: req.body,
 *       token: req.headers.authorization?.replace('Bearer ', ''),
 *     });
 *     res.status(result.status).json(result.body);
 *   });
 *
 *   // AWS Lambda
 *   export const handler = async (event) => {
 *     const result = await handler.handle({
 *       method: event.httpMethod,
 *       path: event.path,
 *       body: JSON.parse(event.body),
 *       token: event.headers.Authorization?.replace('Bearer ', ''),
 *     });
 *     return { statusCode: result.status, body: JSON.stringify(result.body) };
 *   };
 */

import type { DecisionService } from "./decision-service.js";
import { AuthError, NotFoundError } from "./decision-service.js";
import type { AuthPort } from "../ports/auth.js";
import type { Identity } from "../ports/auth.js";
import type { ItemId, GroupId, TaskId, UserId } from "../models/types.js";
import type { ReactionType, CommitmentProof } from "../models/types.js";

// --- Request / Response types ---

export interface ServiceRequest {
  method: string; // GET, POST, PUT, DELETE
  path: string; // e.g., "/spaces/xyz/items"
  body?: unknown;
  token?: string; // auth token
  query?: Record<string, string>; // query params
}

export interface ServiceResponse {
  status: number;
  body: unknown;
}

// --- Handler ---

export class RequestHandler {
  constructor(
    private readonly service: DecisionService,
    private readonly auth: AuthPort
  ) {}

  async handle(req: ServiceRequest): Promise<ServiceResponse> {
    try {
      // Authenticate
      const identity = await this.authenticate(req.token);

      // Route
      return await this.route(req, identity);
    } catch (err) {
      return this.errorResponse(err);
    }
  }

  private async authenticate(token?: string): Promise<Identity> {
    if (!token) {
      throw new AuthError("space:read" as any, "" as GroupId);
    }
    const identity = await this.auth.authenticate(token);
    if (!identity) {
      throw new AuthError("space:read" as any, "" as GroupId);
    }
    return identity;
  }

  private async route(
    req: ServiceRequest,
    identity: Identity
  ): Promise<ServiceResponse> {
    const { method, path } = req;
    const segments = path.split("/").filter(Boolean);
    const body = (req.body ?? {}) as Record<string, unknown>;

    // POST /spaces
    if (method === "POST" && segments[0] === "spaces" && segments.length === 1) {
      const space = await this.service.createSpace(
        identity,
        body.name as string,
        (body.members ?? []) as any[],
        body.config as any,
        body.flow as any
      );
      return { status: 201, body: space };
    }

    // GET /spaces/:groupId
    if (method === "GET" && segments[0] === "spaces" && segments.length === 2) {
      const space = await this.service.getSpace(identity, segments[1] as GroupId);
      return { status: 200, body: space };
    }

    // DELETE /spaces/:groupId
    if (method === "DELETE" && segments[0] === "spaces" && segments.length === 2) {
      await this.service.deleteSpace(identity, segments[1] as GroupId);
      return { status: 204, body: null };
    }

    // POST /spaces/:groupId/items
    if (
      method === "POST" &&
      segments[0] === "spaces" &&
      segments[2] === "items" &&
      segments.length === 3
    ) {
      const item = await this.service.addItem(
        identity,
        segments[1] as GroupId,
        body.title as string,
        (body.description ?? "") as string,
        (body.category ?? "general") as string
      );
      return { status: 201, body: item };
    }

    // GET /spaces/:groupId/items/ranked
    if (
      method === "GET" &&
      segments[0] === "spaces" &&
      segments[2] === "items" &&
      segments[3] === "ranked"
    ) {
      const ranked = await this.service.getRankedItems(
        identity,
        segments[1] as GroupId
      );
      return { status: 200, body: ranked };
    }

    // GET /spaces/:groupId/items/locked
    if (
      method === "GET" &&
      segments[0] === "spaces" &&
      segments[2] === "items" &&
      segments[3] === "locked"
    ) {
      const locked = await this.service.getLockedItems(
        identity,
        segments[1] as GroupId
      );
      return { status: 200, body: locked };
    }

    // GET /spaces/:groupId/items/active
    if (
      method === "GET" &&
      segments[0] === "spaces" &&
      segments[2] === "items" &&
      segments[3] === "active"
    ) {
      const active = await this.service.getActiveItems(
        identity,
        segments[1] as GroupId
      );
      return { status: 200, body: active };
    }

    // GET /items/:itemId
    if (method === "GET" && segments[0] === "items" && segments.length === 2) {
      const item = await this.service.getItem(identity, segments[1] as ItemId);
      return { status: 200, body: item };
    }

    // POST /items/:itemId/react
    if (
      method === "POST" &&
      segments[0] === "items" &&
      segments[2] === "react"
    ) {
      const item = await this.service.react(
        identity,
        segments[1] as ItemId,
        body.reactionType as ReactionType
      );
      return { status: 200, body: item };
    }

    // DELETE /items/:itemId/react
    if (
      method === "DELETE" &&
      segments[0] === "items" &&
      segments[2] === "react"
    ) {
      const item = await this.service.unreact(identity, segments[1] as ItemId);
      return { status: 200, body: item };
    }

    // POST /items/:itemId/lock
    if (
      method === "POST" &&
      segments[0] === "items" &&
      segments[2] === "lock"
    ) {
      const proof: CommitmentProof = {
        type: (body.proofType ?? "confirmation_number") as string,
        value: body.proofValue as string,
        submittedBy: identity.userId,
        submittedAt: Date.now(),
      };
      const item = await this.service.lock(identity, segments[1] as ItemId, proof);
      return { status: 200, body: item };
    }

    // POST /items/:itemId/transfer
    if (
      method === "POST" &&
      segments[0] === "items" &&
      segments[2] === "transfer"
    ) {
      const item = await this.service.transfer(
        identity,
        segments[1] as ItemId,
        body.newOwnerId as UserId
      );
      return { status: 200, body: item };
    }

    // GET /items/:itemId/agreement
    if (
      method === "GET" &&
      segments[0] === "items" &&
      segments[2] === "agreement"
    ) {
      const score = await this.service.getAgreementScore(
        identity,
        segments[1] as ItemId
      );
      return { status: 200, body: score };
    }

    // GET /items/:itemId/signals
    if (
      method === "GET" &&
      segments[0] === "items" &&
      segments[2] === "signals"
    ) {
      const breakdown = await this.service.getSignalBreakdown(
        identity,
        segments[1] as ItemId
      );
      return { status: 200, body: breakdown };
    }

    // POST /spaces/:groupId/tasks
    if (
      method === "POST" &&
      segments[0] === "spaces" &&
      segments[2] === "tasks" &&
      segments.length === 3
    ) {
      const task = await this.service.addTask(
        identity,
        segments[1] as GroupId,
        body.title as string,
        (body.description ?? "") as string
      );
      return { status: 201, body: task };
    }

    // POST /tasks/:taskId/claim
    if (
      method === "POST" &&
      segments[0] === "tasks" &&
      segments[2] === "claim"
    ) {
      const task = await this.service.claimTask(
        identity,
        segments[1] as TaskId
      );
      return { status: 200, body: task };
    }

    // POST /tasks/:taskId/release
    if (
      method === "POST" &&
      segments[0] === "tasks" &&
      segments[2] === "release"
    ) {
      const task = await this.service.releaseTask(
        identity,
        segments[1] as TaskId
      );
      return { status: 200, body: task };
    }

    // GET /spaces/:groupId/grounding/prompt (must be before /grounding)
    if (
      method === "GET" &&
      segments[0] === "spaces" &&
      segments[2] === "grounding" &&
      segments[3] === "prompt" &&
      segments.length === 4
    ) {
      const prompt = await this.service.getGroundingPrompt(
        identity,
        segments[1] as GroupId
      );
      return { status: 200, body: { prompt } };
    }

    // GET /spaces/:groupId/grounding
    if (
      method === "GET" &&
      segments[0] === "spaces" &&
      segments[2] === "grounding" &&
      segments.length === 3
    ) {
      const context = await this.service.getGroundingContext(
        identity,
        segments[1] as GroupId
      );
      return { status: 200, body: context };
    }

    // GET /spaces/:groupId/conflicts?category=hotel
    if (
      method === "GET" &&
      segments[0] === "spaces" &&
      segments[2] === "conflicts"
    ) {
      const category = req.query?.category ?? "";
      const conflicts = await this.service.checkConflicts(
        identity,
        segments[1] as GroupId,
        category
      );
      return { status: 200, body: conflicts };
    }

    return { status: 404, body: { error: "Not found", path } };
  }

  private errorResponse(err: unknown): ServiceResponse {
    if (err instanceof AuthError) {
      return { status: 403, body: { error: err.message } };
    }
    if (err instanceof NotFoundError) {
      return { status: 404, body: { error: err.message } };
    }
    if (err instanceof Error) {
      // Version conflict → 409
      if (err.name === "VersionConflictError") {
        return { status: 409, body: { error: err.message } };
      }
      // Green-lock errors → 422
      if (err.name === "GreenLockError") {
        return { status: 422, body: { error: err.message } };
      }
      // General validation → 400
      return { status: 400, body: { error: err.message } };
    }
    return { status: 500, body: { error: "Internal server error" } };
  }
}
