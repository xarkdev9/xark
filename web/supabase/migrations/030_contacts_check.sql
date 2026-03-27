-- XARK OS v2.0 — Migration 030: Phone index for contact lookup
-- Used by /api/contacts/check to quickly find registered phone numbers.

CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
