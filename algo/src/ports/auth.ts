/**
 * Auth Port
 *
 * Contract for authentication and authorization.
 * Implement this for any auth system: JWT, OAuth2, API keys,
 * Firebase Auth, Supabase Auth, Clerk, Auth0, session cookies, etc.
 *
 * Two-step: authenticate (who are you?) then authorize (can you do this?).
 */

import type { UserId, SpaceId } from "../models/types.js";

/**
 * Actions that can be authorized.
 * Granular enough for role-based or attribute-based access control.
 */
export type Action =
  | "space:create"
  | "space:read"
  | "space:delete"
  | "item:propose"
  | "item:react"
  | "item:lock"
  | "item:transfer"
  | "task:create"
  | "task:claim"
  | "task:release";

/**
 * Authenticated identity. Returned by authenticate().
 * Adapters can extend metadata with provider-specific fields.
 */
export interface Identity {
  userId: UserId;
  displayName?: string;
  metadata?: Record<string, unknown>;
}

export interface AuthPort {
  /**
   * Validates a token/credential and returns the identity.
   * Returns null if invalid/expired.
   */
  authenticate(token: string): Promise<Identity | null>;

  /**
   * Checks if the identity is allowed to perform the action in the space.
   * Called after authenticate().
   */
  authorize(
    identity: Identity,
    action: Action,
    spaceId: SpaceId
  ): Promise<boolean>;
}
