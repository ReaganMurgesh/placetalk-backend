import 'dotenv/config';
import { pool } from './database.js';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export async function runMigrations() {
    try {
        console.log('🔄 Checking database schema...');

        // Check if tables exist
        const result = await pool.query(`
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = 'users'
            );
        `);

        const tablesExist = result.rows[0].exists;

        if (tablesExist) {
            console.log('✅ Database schema already exists');
        } else {
            console.log('📋 Creating database schema...');

            // Read schema.sql from parent directory
            const schemaPath = join(__dirname, '../../schema.sql');
            const schemaSql = readFileSync(schemaPath, 'utf-8');

            // Execute schema
            await pool.query(schemaSql);

            console.log('✅ Database schema created successfully');
            console.log('👤 Test user creation skipped (use create_test_users.ts script)');
        }

        // ── Always run incremental migrations (idempotent) ──────────────

        // 1. Ensure user_pin_interactions table exists (needed for discovery + hide)
        await pool.query(`
            CREATE TABLE IF NOT EXISTS user_pin_interactions (
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                pin_id UUID NOT NULL REFERENCES pins(id) ON DELETE CASCADE,
                last_interaction_at TIMESTAMP DEFAULT NOW(),
                next_notify_at TIMESTAMP,
                is_muted BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW(),
                PRIMARY KEY (user_id, pin_id)
            )
        `);
        await pool.query(`CREATE INDEX IF NOT EXISTS idx_upi_user ON user_pin_interactions(user_id)`);
        await pool.query(`CREATE INDEX IF NOT EXISTS idx_upi_muted ON user_pin_interactions(user_id, is_muted) WHERE is_muted = TRUE`);
        console.log('✅ user_pin_interactions table OK');

        // 2. Ensure interactions table has action column (not interaction_type)
        const actionColCheck = await pool.query(`
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'interactions' AND column_name = 'action'
        `);
        if (actionColCheck.rows.length === 0) {
            // Rename interaction_type to action if it exists, else add action
            const itColCheck = await pool.query(`
                SELECT column_name FROM information_schema.columns
                WHERE table_name = 'interactions' AND column_name = 'interaction_type'
            `);
            if (itColCheck.rows.length > 0) {
                await pool.query(`ALTER TABLE interactions RENAME COLUMN interaction_type TO action`);
                console.log('✅ Renamed interaction_type → action');
            } else {
                await pool.query(`ALTER TABLE interactions ADD COLUMN IF NOT EXISTS action VARCHAR(20)`);
                console.log('✅ Added action column to interactions');
            }
        }
        console.log('✅ interactions.action column OK');

        // 3. Ensure pins.updated_at column exists
        await pool.query(`ALTER TABLE pins ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW()`);

        console.log('✅ Database migration completed successfully!');
    } catch (error) {
        console.error('❌ Migration failed:', error);
        throw error;
    }
}
