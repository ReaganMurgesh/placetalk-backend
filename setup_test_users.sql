-- Complete 2-User Test Setup
-- Run this in your PostgreSQL database to set up proper testing environment
-- This removes test user causing shared pins and creates clean test users

-- STEP 1: Remove existing test user and their pins (fixes shared data bug)
DELETE FROM user_activities WHERE user_id = '123e4567-e89b-12d3-a456-426614174000' OR pin_id IN (SELECT id FROM pins WHERE created_by = '123e4567-e89b-12d3-a456-426614174000');
DELETE FROM user_pin_interactions WHERE user_id = '123e4567-e89b-12d3-a456-426614174000' OR pin_id IN (SELECT id FROM pins WHERE created_by = '123e4567-e89b-12d3-a456-426614174000');
DELETE FROM discoveries WHERE user_id = '123e4567-e89b-12d3-a456-426614174000' OR pin_id IN (SELECT id FROM pins WHERE created_by = '123e4567-e89b-12d3-a456-426614174000');
DELETE FROM interactions WHERE user_id = '123e4567-e89b-12d3-a456-426614174000' OR pin_id IN (SELECT id FROM pins WHERE created_by = '123e4567-e89b-12d3-a456-426614174000');
DELETE FROM pins WHERE created_by = '123e4567-e89b-12d3-a456-426614174000';
DELETE FROM users WHERE id = '123e4567-e89b-12d3-a456-426614174000';

-- STEP 2: Clean up any other test users
DELETE FROM user_activities WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%test%@%');
DELETE FROM user_pin_interactions WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%test%@%');
DELETE FROM discoveries WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%test%@%');
DELETE FROM interactions WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%test%@%');
DELETE FROM pins WHERE created_by IN (SELECT id FROM users WHERE email LIKE '%test%@%');
DELETE FROM users WHERE email LIKE '%test%@%';

-- STEP 3: Create Test User 1
INSERT INTO users (name, email, password_hash, role, country) 
VALUES ('Test User 1', 'testuser1@placetalk.app', '$2b$10$vI8aWBnW3fID.w.OfN2Pme6x7yTimZaCvk8b4LJzVE4fhCKwC6ztG', 'explorer', 'Japan');

-- STEP 4: Create Test User 2  
INSERT INTO users (name, email, password_hash, role, country) 
VALUES ('Test User 2', 'testuser2@placetalk.app', '$2b$10$vI8aWBnW3fID.w.OfN2Pme6x7yTimZaCvk8b4LJzVE4fhCKwC6ztG', 'explorer', 'Japan');

-- STEP 5: Create test pins for User 1 (for discovery testing)
INSERT INTO pins (title, directions, details, location, type, pin_category, created_by, expires_at)
SELECT 
    'Tokyo Station Pin',
    'Near the main entrance',
    'Test pin for multi-user discovery',
    ST_MakePoint(139.6503, 35.6762)::geography,
    'location',
    'normal',
    u.id,
    NOW() + INTERVAL '72 hours'
FROM users u WHERE u.email = 'testuser1@placetalk.app';

INSERT INTO pins (title, directions, details, location, type, pin_category, created_by, expires_at)
SELECT 
    'Tokyo Tower Pin',
    'At the base of Tokyo Tower',
    'Test pin for multi-user discovery',
    ST_MakePoint(139.7454, 35.6586)::geography,
    'location',
    'normal',
    u.id,
    NOW() + INTERVAL '72 hours'
FROM users u WHERE u.email = 'testuser1@placetalk.app';

-- STEP 6: Verify setup
SELECT 
    'SETUP VERIFICATION' as status,
    (SELECT COUNT(*) FROM users WHERE email LIKE 'testuser%@placetalk.app') as test_users_created,
    (SELECT COUNT(*) FROM pins WHERE created_by IN (SELECT id FROM users WHERE email = 'testuser1@placetalk.app')) as test_pins_created,
    (SELECT COUNT(*) FROM pins WHERE created_by = '123e4567-e89b-12d3-a456-426614174000') as old_test_pins_remaining;

-- Login credentials (both users use same password: testpass123)
-- User 1: testuser1@placetalk.app / testpass123  
-- User 2: testuser2@placetalk.app / testpass123