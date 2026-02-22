-- Migration 004: Pin Creation Rules (spec 2.1 / 2.2)
-- Adds external_link, chat_enabled to pins table
-- Enlarges title column to reflect 10-char UI enforcement (DB keeps 150 for safety)

ALTER TABLE pins
  ADD COLUMN IF NOT EXISTS external_link TEXT,
  ADD COLUMN IF NOT EXISTS chat_enabled BOOLEAN NOT NULL DEFAULT FALSE;

-- Index: daily pin count per user (quota enforcement)
CREATE INDEX IF NOT EXISTS idx_pins_creator_created_at
  ON pins (created_by, created_at DESC)
  WHERE is_deleted = FALSE;
