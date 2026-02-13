-- Migration 003: Social Features (Communities + Diary + Roles)
-- Adds community broadcast system, user activity tracking, and role-based access

-- Add role to users (normal or admin)
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'normal' CHECK (role IN ('normal', 'admin'));
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Communities (broadcast channels)
CREATE TABLE IF NOT EXISTS communities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    image_url TEXT,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Community membership (many-to-many)
CREATE TABLE IF NOT EXISTS community_members (
    community_id UUID REFERENCES communities(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (community_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_community_members_user ON community_members(user_id);
CREATE INDEX IF NOT EXISTS idx_community_members_community ON community_members(community_id);

-- Community messages (admin broadcasts only)
CREATE TABLE IF NOT EXISTS community_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    community_id UUID REFERENCES communities(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    image_url TEXT,
    reactions JSONB DEFAULT '{}',  -- {"👍": ["user1", "user2"], "❤️": ["user3"]}
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_community_messages_community ON community_messages(community_id, created_at DESC);

-- User activities (for serendipity diary)
CREATE TABLE IF NOT EXISTS user_activities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    pin_id UUID REFERENCES pins(id) ON DELETE CASCADE,
    activity_type VARCHAR(20) NOT NULL CHECK (activity_type IN ('visited', 'liked', 'commented', 'created')),
    metadata JSONB DEFAULT '{}',  -- Extra context (e.g., comment text)
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activities_user_date ON user_activities(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activities_pin ON user_activities(pin_id);

-- Comments on activities
COMMENT ON TABLE communities IS 'Communities are broadcast-only channels where admins post and members react';
COMMENT ON COLUMN community_messages.reactions IS 'JSONB object mapping emoji to array of user IDs';
COMMENT ON TABLE user_activities IS 'Tracks all user interactions with pins for the serendipity diary';
COMMENT ON COLUMN user_activities.activity_type IS 'Type: visited (proximity), liked, commented, created';

-- Grant permissions (if using specific DB user)
-- GRANT ALL ON communities, community_members, community_messages, user_activities TO placetalk_app;
