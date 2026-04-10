-- Surgical removal of compromised AES keys from metadata
-- Uses JSONB minus operator to preserve all other fields (width, height, fileSize, etc.)
UPDATE decision_items
SET metadata = metadata - 'imageKey' - 'imageIv'
WHERE metadata ? 'imageKey';
