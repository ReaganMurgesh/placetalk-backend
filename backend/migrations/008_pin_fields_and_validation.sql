-- Migration 008: Key pin fields and text validation guardrails
-- Adds: users.nickname, users.bio, users.username
--       pins.creator_snapshot
--       expires_at nullable
--       DB-level CHECK constraints on text lengths

-- ── Users: display profile fields ──────────────────────────────────────────
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS nickname VARCHAR(20),
  ADD COLUMN IF NOT EXISTS bio      VARCHAR(15),
  ADD COLUMN IF NOT EXISTS username VARCHAR(15);

-- Username must be unique (when set)
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username
  ON users (username)
  WHERE username IS NOT NULL;

-- Username: alphanumeric + underscore only
ALTER TABLE users
  ADD CONSTRAINT users_username_alphanumeric
  CHECK (username IS NULL OR username ~ '^[a-zA-Z0-9_]+$');

-- Nickname / bio length guardrails (belt-and-suspenders; service already validates)
ALTER TABLE users
  ADD CONSTRAINT users_nickname_length
  CHECK (nickname IS NULL OR char_length(nickname) <= 20);

ALTER TABLE users
  ADD CONSTRAINT users_bio_length
  CHECK (bio IS NULL OR char_length(bio) <= 15);

-- Username length guardrail
ALTER TABLE users
  ADD CONSTRAINT users_username_length
  CHECK (username IS NULL OR char_length(username) <= 15);

-- ── Pins: creator snapshot (denormalised for display) ──────────────────────
ALTER TABLE pins
  ADD COLUMN IF NOT EXISTS creator_snapshot JSONB NOT NULL DEFAULT '{}';

-- ── Pins: make expires_at nullable (null = apply 1-year rule at query time) ─
ALTER TABLE pins
  ALTER COLUMN expires_at DROP NOT NULL;

-- ── Pins: DB-level text CHECK constraints ──────────────────────────────────
-- Title: max 10 characters (required, non-empty enforced by service)
ALTER TABLE pins
  ADD CONSTRAINT pins_title_length
  CHECK (char_length(title) <= 10);

-- Directions: 50–100 characters
-- Use NOT VALID so existing rows that may not conform don't block migration;
-- newly inserted / updated rows will be validated.
ALTER TABLE pins
  ADD CONSTRAINT pins_directions_length
  CHECK (char_length(directions) BETWEEN 50 AND 100)
  NOT VALID;

-- Details: optional, but if provided must be 300–500 chars
ALTER TABLE pins
  ADD CONSTRAINT pins_details_length
  CHECK (
    details IS NULL
    OR char_length(details) = 0
    OR char_length(details) <= 2000
  )
  NOT VALID;
