/**
 * No-Op Auth Adapter
 *
 * Authenticates everyone, authorizes everything. For:
 * - Development and testing
 * - Internal tools with no auth requirements
 * - Prototyping
 *
 * For real auth, replace with:
 * - JwtAuthAdapter (decode + verify JWT tokens)
 * - ApiKeyAuthAdapter (lookup API keys in DB)
 * - FirebaseAuthAdapter (Firebase Admin SDK)
 * - SupabaseAuthAdapter (Supabase JWT)
 * - ClerkAuthAdapter (Clerk session tokens)
 * - OAuth2AuthAdapter (generic OAuth2 token introspection)
 */

import type { AuthPort, Identity, Action } from "../ports/auth.js";
import type { UserId, GroupId } from "../models/types.js";

export class NoopAuthAdapter implements AuthPort {
  async authenticate(token: string): Promise<Identity | null> {
    // Trust the token as a userId. Replace with real validation.
    if (!token) return null;
    return {
      userId: token as UserId,
      displayName: token,
    };
  }

  async authorize(
    _identity: Identity,
    _action: Action,
    _groupId: GroupId
  ): Promise<boolean> {
    return true;
  }
}
