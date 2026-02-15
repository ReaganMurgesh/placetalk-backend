-- PlaceTalk Database Schema
-- Requires: PostgreSQL 15+ with PostGIS extension

-- Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- USERS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'explorer' CHECK (role IN ('explorer', 'community', 'admin')),
    home_region VARCHAR(100),
    country VARCHAR(100) DEFAULT 'Japan',
    fcm_token TEXT,  -- Firebase Cloud Messaging token
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
-- PINS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS pins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(150) NOT NULL,
    directions TEXT NOT NULL,
    details TEXT,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    type VARCHAR(20) DEFAULT 'location' CHECK (type IN ('location', 'sensation', 'serendipity')),
    pin_category VARCHAR(20) DEFAULT 'normal' CHECK (pin_category IN ('normal', 'community')),
    attribute_id VARCHAR(50),
    created_by UUID NOT NULL REFERENCES users(id),
    visible_from TIME,
    visible_to TIME,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    like_count INTEGER DEFAULT 0,
    dislike_count INTEGER DEFAULT 0,
    life_extended_count INTEGER DEFAULT 0,  -- Track how many times life was extended
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Spatial index for fast proximity queries
CREATE INDEX IF NOT EXISTS idx_pins_location ON pins USING GIST (location);

-- Index for TTL queries
CREATE INDEX IF NOT EXISTS idx_pins_expires_at ON pins (expires_at) WHERE is_deleted = FALSE;

-- Index for geohash-based lookups
CREATE INDEX IF NOT EXISTS idx_pins_created_by ON pins (created_by);

-- ============================================================
-- INTERACTIONS TABLE (Like/Dislike)
-- ============================================================
CREATE TABLE IF NOT EXISTS interactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    pin_id UUID NOT NULL REFERENCES pins(id),
    interaction_type VARCHAR(10) NOT NULL CHECK (interaction_type IN ('like', 'dislike')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, pin_id)  -- One interaction per user per pin
);

CREATE INDEX IF NOT EXISTS idx_interactions_pin ON interactions (pin_id);
CREATE INDEX IF NOT EXISTS idx_interactions_user ON interactions (user_id);

-- ============================================================
-- DISCOVERIES TABLE (Analytics)
-- ============================================================
CREATE TABLE IF NOT EXISTS discoveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    pin_id UUID NOT NULL REFERENCES pins(id),
    distance_meters INTEGER,
    discovered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, pin_id)  -- Only log first discovery
);

CREATE INDEX IF NOT EXISTS idx_discoveries_user ON discoveries (user_id);
CREATE INDEX IF NOT EXISTS idx_discoveries_pin ON discoveries (pin_id);

-- ============================================================
-- USER PIN INTERACTIONS (Serendipity)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_pin_interactions (
    user_id UUID NOT NULL REFERENCES users(id),
    pin_id UUID NOT NULL REFERENCES pins(id),
    is_good BOOLEAN DEFAULT FALSE,
    is_bad BOOLEAN DEFAULT FALSE,
    is_muted BOOLEAN DEFAULT FALSE,
    last_interaction_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, pin_id)
);

-- ============================================================
-- COMMUNITIES
-- ============================================================
CREATE TABLE IF NOT EXISTS communities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_by UUID NOT NULL REFERENCES users(id),
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS community_members (
    community_id UUID NOT NULL REFERENCES communities(id),
    user_id UUID NOT NULL REFERENCES users(id),
    role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('member', 'admin')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (community_id, user_id)
);

CREATE TABLE IF NOT EXISTS community_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    community_id UUID NOT NULL REFERENCES communities(id),
    user_id UUID NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS message_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES community_messages(id),
    user_id UUID NOT NULL REFERENCES users(id),
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(message_id, user_id, emoji)
);

-- ============================================================
-- USER ACTIVITIES (Diary)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_activities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    pin_id UUID REFERENCES pins(id),
    activity_type VARCHAR(20) NOT NULL, -- visited, liked, commented, created, reported, hidden
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_activities_user ON user_activities (user_id);
CREATE INDEX IF NOT EXISTS idx_user_activities_created_at ON user_activities (created_at);

-- ============================================================
-- HELPFUL VIEWS
-- ============================================================
CREATE OR REPLACE VIEW active_pins AS
SELECT 
    id, title, directions, details, type, pin_category,
    attribute_id, created_by, like_count, dislike_count,
    life_extended_count,
    ST_Y(location::geometry) as lat,
    ST_X(location::geometry) as lon,
    expires_at, created_at
FROM pins
WHERE is_deleted = FALSE AND expires_at > NOW();
