-- Phase 0 Foundation: Tables, Indexes, Extensions
-- Run via Supabase SQL Editor or supabase db push
-- Spec: docs/superpowers/specs/2026-03-12-phase0-foundation-design.md

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pgjwt;

-- ══════════════════════════════════════
-- TABLES
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS users (
  id text PRIMARY KEY,
  display_name text NOT NULL,
  photo_url text,
  phone text UNIQUE,
  password_hash text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS spaces (
  id text PRIMARY KEY,
  title text NOT NULL,
  owner_id text NOT NULL REFERENCES users(id),
  atmosphere text,
  is_public boolean NOT NULL DEFAULT false,
  photo_url text,
  last_activity_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS space_members (
  space_id text NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member',
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (space_id, user_id)
);

CREATE TABLE IF NOT EXISTS decision_items (
  id text PRIMARY KEY,
  space_id text NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  title text NOT NULL,
  category text,
  description text,
  state text NOT NULL DEFAULT 'proposed',
  proposed_by text REFERENCES users(id),
  proposed_at timestamptz NOT NULL DEFAULT now(),
  weighted_score float NOT NULL DEFAULT 0,
  agreement_score float NOT NULL DEFAULT 0,
  is_locked boolean NOT NULL DEFAULT false,
  locked_at timestamptz,
  commitment_proof jsonb,
  ownership jsonb,
  ownership_history jsonb NOT NULL DEFAULT '[]'::jsonb,
  version integer NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS reactions (
  item_id text NOT NULL REFERENCES decision_items(id) ON DELETE CASCADE,
  user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  signal text NOT NULL,
  weight integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (item_id, user_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id text PRIMARY KEY,
  space_id text NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  role text NOT NULL,
  content text NOT NULL,
  user_id text,
  sender_name text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tasks (
  id text PRIMARY KEY,
  space_id text NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  title text NOT NULL,
  assignee_id text REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ══════════════════════════════════════
-- INDEXES
-- ══════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_messages_space_created ON messages(space_id, created_at);
CREATE INDEX IF NOT EXISTS idx_decision_items_space ON decision_items(space_id);
CREATE INDEX IF NOT EXISTS idx_decision_items_space_locked ON decision_items(space_id, is_locked);
CREATE INDEX IF NOT EXISTS idx_reactions_item ON reactions(item_id);
CREATE INDEX IF NOT EXISTS idx_space_members_user ON space_members(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_space ON tasks(space_id);
