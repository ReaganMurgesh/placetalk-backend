-- PlaceTalk Initial Database Schema
-- PostgreSQL + PostGIS

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

--  Users Table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(20) CHECK (role IN ('normal', 'community')) DEFAULT 'normal',
  home_region VARCHAR(100),
  country VARCHAR(50) DEFAULT 'Japan',
  notification_sound VARCHAR(50),
  created_at TIMESTAMP DEFAULT NOW(),
  last_login TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

-- Attributes Table
CREATE TABLE attributes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  color_code VARCHAR(7), -- Hex color for UI
  join_type VARCHAR(20) CHECK (join_type IN ('free', 'invite_only')) DEFAULT 'free',
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Pins Table
CREATE TABLE pins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(150) NOT NULL,
  directions TEXT NOT NULL, -- Word-based guidance
  details TEXT,
  location GEOGRAPHY(POINT, 4326) NOT NULL, -- PostGIS geospatial
  type VARCHAR(20) CHECK (type IN ('location', 'sensation')) DEFAULT 'location',
  pin_category VARCHAR(20) CHECK (pin_category IN ('normal', 'community')) DEFAULT 'normal',
  attribute_id UUID REFERENCES attributes(id),
  created_by UUID REFERENCES users(id) ON DELETE CASCADE,
  visible_from TIME, -- Optional time filter
  visible_to TIME,
  expires_at TIMESTAMP NOT NULL,
  like_count INT DEFAULT 0,
  dislike_count INT DEFAULT 0,
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Geospatial index (crucial for performance)
CREATE INDEX idx_pins_location ON pins USING GIST(location);
CREATE INDEX idx_pins_attribute ON pins(attribute_id);
CREATE INDEX idx_pins_creator ON pins(created_by);
CREATE INDEX idx_pins_expiry ON pins(expires_at) WHERE is_deleted = FALSE;

-- Attribute Memberships
CREATE TABLE attribute_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  attribute_id UUID REFERENCES attributes(id) ON DELETE CASCADE,
  joined_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, attribute_id)
);

CREATE INDEX idx_memberships_user ON attribute_memberships(user_id);
CREATE INDEX idx_memberships_attribute ON attribute_memberships(attribute_id);

-- Interactions Table
CREATE TABLE interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pin_id UUID REFERENCES pins(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  action VARCHAR(20) CHECK (action IN ('like', 'dislike', 'favorite', 'comment', 'report')),
  comment TEXT, -- For comment action
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(pin_id, user_id, action) -- Prevent duplicate likes
);

CREATE INDEX idx_interactions_pin ON interactions(pin_id);
CREATE INDEX idx_interactions_user ON interactions(user_id);

-- Discoveries Table (Analytics)
CREATE TABLE discoveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  pin_id UUID REFERENCES pins(id) ON DELETE CASCADE,
  discovered_at TIMESTAMP DEFAULT NOW(),
  distance_meters INT -- How far when discovered
);

CREATE INDEX idx_discoveries_user ON discoveries(user_id);
CREATE INDEX idx_discoveries_pin ON discoveries(pin_id);

-- Diary Entries (Reflection Feature)
CREATE TABLE diary_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  pin_id UUID REFERENCES pins(id) ON DELETE SET NULL, -- Optional link
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_diary_user ON diary_entries(user_id);
