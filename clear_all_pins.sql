-- Remove test user and pins causing shared data on map and diary
-- ⚠️  This removes the test user whose pins show for all users
-- Run this to fix both diary AND map pin issues

-- Step 1: Remove activities for test user pins
DELETE FROM user_activities 
WHERE pin_id IN (SELECT id FROM pins WHERE created_by = '123e4567-e89b-12d3-a456-426614174000');

-- Step 2: Remove interactions with test user pins  
DELETE FROM user_pin_interactions 
WHERE pin_id IN (SELECT id FROM pins WHERE created_by = '123e4567-e89b-12d3-a456-426614174000');

-- Step 3: Remove test user's pins (this fixes map showing pins)
DELETE FROM pins WHERE created_by = '123e4567-e89b-12d3-a456-426614174000';

-- Step 4: Remove test user activities
DELETE FROM user_activities WHERE user_id = '123e4567-e89b-12d3-a456-426614174000';

-- Step 5: Remove test user completely
DELETE FROM users WHERE id = '123e4567-e89b-12d3-a456-426614174000';

-- Step 6: Verify cleanup and show results
SELECT 
    'Cleanup Results:' as status,
    (SELECT COUNT(*) FROM pins) as total_pins_remaining,
    (SELECT COUNT(*) FROM pins WHERE created_by = '123e4567-e89b-12d3-a456-426614174000') as test_user_pins_remaining,
    (SELECT COUNT(*) FROM users WHERE id = '123e4567-e89b-12d3-a456-426614174000') as test_user_remaining;
