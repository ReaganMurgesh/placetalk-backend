-- Migration 006: Community types, feed, invite links, like/hide, notification settings
-- Spec 3.1–3.5

-- ── communities table additions ────────────────────────────────────────────
ALTER TABLE communities
  ADD COLUMN IF NOT EXISTS community_type VARCHAR(20) NOT NULL DEFAULT 'open'
    CHECK (community_type IN ('open', 'invite_only', 'paid_restricted'));

ALTER TABLE communities
  ADD COLUMN IF NOT EXISTS like_count INTEGER NOT NULL DEFAULT 0;

-- ── community_members additions (per-member settings) ──────────────────────
-- notifications_on: spec 3.3 step 1
-- hometown_notify: spec 3.3 step 3
-- is_hidden / hide_map_pins: spec 3.4 hide action
ALTER TABLE community_members
  ADD COLUMN IF NOT EXISTS notifications_on BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE community_members
  ADD COLUMN IF NOT EXISTS hometown_notify BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE community_members
  ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE community_members
  ADD COLUMN IF NOT EXISTS hide_map_pins BOOLEAN NOT NULL DEFAULT FALSE;

-- ── pins: link to community + chat activity tracking (feed ordering) ────────
ALTER TABLE pins
  ADD COLUMN IF NOT EXISTS community_id UUID REFERENCES communities(id) ON DELETE SET NULL;

ALTER TABLE pins
  ADD COLUMN IF NOT EXISTS chat_last_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX IF NOT EXISTS idx_pins_community ON pins(community_id) WHERE is_deleted = FALSE;

-- ── community_invites: invite-only and paid links ───────────────────────────
CREATE TABLE IF NOT EXISTS community_invites (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  code         VARCHAR(32) NOT NULL UNIQUE,
  created_by   UUID NOT NULL REFERENCES users(id),
  expires_at   TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '7 days'),
  use_count    INTEGER NOT NULL DEFAULT 0,
  created_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_community_invites_code ON community_invites(code);

-- ── community_likes: deduplication for like action ─────────────────────────
CREATE TABLE IF NOT EXISTS community_likes (
  community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES users(id),
  created_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (community_id, user_id)
);
