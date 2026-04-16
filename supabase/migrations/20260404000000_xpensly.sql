-- Migration: Xpensly Core Tables
-- Creates 8 normalized tables for trip and expense management

CREATE TABLE xp_trips (
    id TEXT PRIMARY KEY,
    group_id TEXT,
    title TEXT NOT NULL,
    base_currency TEXT NOT NULL DEFAULT 'USD',
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    categories JSONB DEFAULT '[]'::jsonb,
    settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE xp_trip_phases (
    trip_id TEXT NOT NULL REFERENCES xp_trips(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (trip_id, name)
);

CREATE TABLE xp_trip_members (
    trip_id TEXT NOT NULL REFERENCES xp_trips(id) ON DELETE CASCADE,
    id TEXT NOT NULL,
    name TEXT NOT NULL,
    PRIMARY KEY (trip_id, id)
);

CREATE TABLE xp_expenses (
    id TEXT PRIMARY KEY,
    trip_id TEXT NOT NULL REFERENCES xp_trips(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    currency TEXT NOT NULL,
    mode TEXT NOT NULL,
    date TIMESTAMPTZ NOT NULL,
    phase TEXT,
    notes TEXT,
    receipt_url TEXT,
    recurring JSONB,
    tags JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE xp_expense_payers (
    expense_id TEXT NOT NULL REFERENCES xp_expenses(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    PRIMARY KEY (expense_id, user_id)
);

CREATE TABLE xp_expense_splits (
    expense_id TEXT NOT NULL REFERENCES xp_expenses(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    PRIMARY KEY (expense_id, user_id)
);

CREATE TABLE xp_settlements (
    id TEXT PRIMARY KEY,
    trip_id TEXT NOT NULL REFERENCES xp_trips(id) ON DELETE CASCADE,
    from_user_id TEXT NOT NULL,
    to_user_id TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    currency TEXT NOT NULL,
    date TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL
);

CREATE TABLE xp_refunds (
    id TEXT PRIMARY KEY,
    trip_id TEXT NOT NULL REFERENCES xp_trips(id) ON DELETE CASCADE,
    expense_id TEXT NOT NULL REFERENCES xp_expenses(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    date TIMESTAMPTZ NOT NULL
);
