-- Migration 005: Pin Types & Visibility + Edit/Delete Permissions (spec 2.3 / 2.4)

-- 2.3: Add is_private flag for Paid/Restricted pins
ALTER TABLE pins
  ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT FALSE;

-- Update pin_category constraint to allow 'paid' category
ALTER TABLE pins
  DROP CONSTRAINT IF EXISTS pins_pin_category_check;

ALTER TABLE pins
  ADD CONSTRAINT pins_pin_category_check
  CHECK (pin_category IN ('normal', 'community', 'paid'));

-- 2.4: Special admin (B2B partner) flag — toggled manually via Supabase admin dashboard
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_b2b_partner BOOLEAN NOT NULL DEFAULT FALSE;

-- Index for fast permission lookups on edit/delete
CREATE INDEX IF NOT EXISTS idx_users_b2b ON users(id) WHERE is_b2b_partner = TRUE;
CREATE INDEX IF NOT EXISTS idx_pins_private ON pins(is_private) WHERE is_deleted = FALSE;
