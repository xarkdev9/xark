-- Migration: 031_oblivious_decision_items.sql
-- Enforces Zero-Knowledge for decision_items
-- Removes plaintext columns and introduces cryptographic envelopes.

ALTER TABLE IF EXISTS decision_items DROP COLUMN IF EXISTS title;
ALTER TABLE IF EXISTS decision_items DROP COLUMN IF EXISTS description;
ALTER TABLE IF EXISTS decision_items DROP COLUMN IF EXISTS category;
ALTER TABLE IF EXISTS decision_items DROP COLUMN IF EXISTS metadata;
ALTER TABLE IF EXISTS decision_items ADD COLUMN IF NOT EXISTS ciphertext_payload text;
ALTER TABLE IF EXISTS decision_items ADD COLUMN IF NOT EXISTS nonce text;
ALTER TABLE IF EXISTS decision_items ADD COLUMN IF NOT EXISTS commitment_ciphertext text;
ALTER TABLE IF EXISTS decision_items ADD COLUMN IF NOT EXISTS commitment_nonce text;
