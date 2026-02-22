-- Migration 007: Diary Pin Engagement Metrics
-- Adds pass_through_count, hide_count, report_count to pins table
-- Adds verified_at to user_activities for ghost→verified upgrade flow

-- ── Per-pin engagement counters ───────────────────────────────────────────────
ALTER TABLE pins
  ADD COLUMN IF NOT EXISTS pass_through_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS hide_count         INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS report_count       INTEGER DEFAULT 0;

-- ── Ghost→Verified upgrade tracking ──────────────────────────────────────────
-- Store when a ghost_pass was upgraded to "verified" (liked by user)
ALTER TABLE user_activities
  ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS verified    BOOLEAN DEFAULT FALSE;

-- Partial index: fast lookup of unverified ghost passes per user
CREATE INDEX IF NOT EXISTS idx_user_activities_ghost
    ON user_activities (user_id, pin_id)
    WHERE activity_type = 'ghost_pass';

-- Full-text search index on pins (title + directions + details)
CREATE INDEX IF NOT EXISTS idx_pins_fts
    ON pins
    USING gin(to_tsvector('simple', title || ' ' || COALESCE(directions, '') || ' ' || COALESCE(details, '')));
