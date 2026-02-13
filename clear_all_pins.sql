-- Delete ALL pins from the database
-- Run this in the Render PostgreSQL shell

DELETE FROM pins;

-- Verify deletion
SELECT COUNT(*) FROM pins;
