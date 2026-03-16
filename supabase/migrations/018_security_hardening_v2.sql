-- 018_security_hardening_v2.sql
-- M3 fix: increase invite token entropy from 6 bytes (48 bits) to 16 bytes (128 bits)

ALTER TABLE space_invites ALTER COLUMN token SET DEFAULT encode(gen_random_bytes(16), 'hex');
