-- CRYPTO-08: Add Kyber-1024 columns for PQXDH hybrid key exchange.
-- Nullable for backward compatibility — peers without Kyber keys fall back to X3DH.

-- Add Kyber columns to key_bundles (nullable for backward compat)
ALTER TABLE key_bundles
  ADD COLUMN IF NOT EXISTS kyber_pre_key TEXT,
  ADD COLUMN IF NOT EXISTS kyber_pre_key_sig TEXT;

-- Add Kyber OTK column
ALTER TABLE one_time_pre_keys
  ADD COLUMN IF NOT EXISTS kyber_otk TEXT;
