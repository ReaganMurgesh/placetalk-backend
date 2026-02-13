-- Migration: User-Pin Interactions for Serendipity Notifications
-- Tracks per-user mute status and cooldown timers for spaced repetition

CREATE TABLE IF NOT EXISTS user_pin_interactions (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pin_id UUID NOT NULL REFERENCES pins(id) ON DELETE CASCADE,
    
    -- Tracking
    last_seen_at TIMESTAMP DEFAULT NOW(),
    next_notify_at TIMESTAMP,
    
    -- Mute Status
    is_muted BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    PRIMARY KEY (user_id, pin_id)
);

-- Index for efficient cooldown queries
CREATE INDEX idx_user_pin_notify ON user_pin_interactions(user_id, next_notify_at) 
WHERE is_muted = FALSE;

-- Index for looking up user's muted pins
CREATE INDEX idx_user_muted_pins ON user_pin_interactions(user_id, is_muted) 
WHERE is_muted = TRUE;

COMMENT ON TABLE user_pin_interactions IS 'Tracks user-specific pin interactions for spaced repetition and muting';
COMMENT ON COLUMN user_pin_interactions.last_seen_at IS 'Last time user was notified about this pin';
COMMENT ON COLUMN user_pin_interactions.next_notify_at IS 'Earliest time to notify again (NULL = notify immediately)';
COMMENT ON COLUMN user_pin_interactions.is_muted IS 'If TRUE, never notify about this pin again';
