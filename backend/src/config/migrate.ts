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

        // 2. Ensure interactions.interaction_type column exists (the service uses this name).
        //    Old versions of this migration erroneously renamed it to 'action' — repair that here.
        const actionColCheck = await pool.query(`
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'interactions' AND column_name = 'action'
        `);
        const itColCheck = await pool.query(`
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'interactions' AND column_name = 'interaction_type'
        `);
        if (actionColCheck.rows.length > 0 && itColCheck.rows.length === 0) {
            // The column was mistakenly renamed from interaction_type to action — reverse it
            await pool.query(`ALTER TABLE interactions RENAME COLUMN action TO interaction_type`);
            console.log('✅ Repaired: renamed interactions.action → interaction_type');
        } else {
            console.log('✅ interactions.interaction_type column OK');
        }

        // 3. Ensure pins.updated_at column exists
        await pool.query(`ALTER TABLE pins ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW()`);

        // 3b. Ensure users.is_b2b_partner column exists (migration 005)
        await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS is_b2b_partner BOOLEAN NOT NULL DEFAULT FALSE`);
        await pool.query(`CREATE INDEX IF NOT EXISTS idx_users_b2b ON users(id) WHERE is_b2b_partner = TRUE`);
        console.log('✅ users.is_b2b_partner OK');

        // ── Migration 004: external_link, chat_enabled on pins ──────────────
        await pool.query(`ALTER TABLE pins ADD COLUMN IF NOT EXISTS external_link TEXT`);
        await pool.query(`ALTER TABLE pins ADD COLUMN IF NOT EXISTS chat_enabled BOOLEAN NOT NULL DEFAULT FALSE`);
        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_pins_creator_created_at
            ON pins (created_by, created_at DESC)
            WHERE is_deleted = FALSE
        `);
        console.log('✅ pins external_link / chat_enabled OK');

        // ── Migration 005: is_private on pins ───────────────────────────────
        await pool.query(`ALTER TABLE pins ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT FALSE`);
        // Ensure pin_category allows 'paid'
        await pool.query(`ALTER TABLE pins DROP CONSTRAINT IF EXISTS pins_pin_category_check`);
        await pool.query(`
            DO $$ BEGIN
                ALTER TABLE pins ADD CONSTRAINT pins_pin_category_check
                    CHECK (pin_category IN ('normal', 'community', 'paid'));
            EXCEPTION WHEN duplicate_object THEN NULL;
            END $$
        `);
        await pool.query(`CREATE INDEX IF NOT EXISTS idx_pins_private ON pins(is_private) WHERE is_deleted = FALSE`);
        console.log('✅ pins.is_private OK');

        // ── Migration 006: community_id, chat_last_at on pins; community sub-tables ──
        await pool.query(`ALTER TABLE pins ADD COLUMN IF NOT EXISTS community_id UUID REFERENCES communities(id) ON DELETE SET NULL`);
        await pool.query(`ALTER TABLE pins ADD COLUMN IF NOT EXISTS chat_last_at TIMESTAMP WITH TIME ZONE`);
        await pool.query(`CREATE INDEX IF NOT EXISTS idx_pins_community ON pins(community_id) WHERE is_deleted = FALSE`);
        // communities extra columns
        await pool.query(`ALTER TABLE communities ADD COLUMN IF NOT EXISTS community_type VARCHAR(20) NOT NULL DEFAULT 'open'`);
        await pool.query(`ALTER TABLE communities ADD COLUMN IF NOT EXISTS like_count INTEGER NOT NULL DEFAULT 0`);
        // community_members extra columns
        await pool.query(`ALTER TABLE community_members ADD COLUMN IF NOT EXISTS notifications_on BOOLEAN NOT NULL DEFAULT FALSE`);
        await pool.query(`ALTER TABLE community_members ADD COLUMN IF NOT EXISTS hometown_notify BOOLEAN NOT NULL DEFAULT FALSE`);
        await pool.query(`ALTER TABLE community_members ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN NOT NULL DEFAULT FALSE`);
        await pool.query(`ALTER TABLE community_members ADD COLUMN IF NOT EXISTS hide_map_pins BOOLEAN NOT NULL DEFAULT FALSE`);
        // community_invites table
        await pool.query(`
            CREATE TABLE IF NOT EXISTS community_invites (
                id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
                code         VARCHAR(32) NOT NULL UNIQUE,
                created_by   UUID NOT NULL REFERENCES users(id),
                expires_at   TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '7 days'),
                use_count    INTEGER NOT NULL DEFAULT 0,
                created_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            )
        `);
        await pool.query(`CREATE INDEX IF NOT EXISTS idx_community_invites_code ON community_invites(code)`);
        // community_likes table
        await pool.query(`
            CREATE TABLE IF NOT EXISTS community_likes (
                community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
                user_id      UUID NOT NULL REFERENCES users(id),
                created_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                PRIMARY KEY (community_id, user_id)
            )
        `);
        console.log('✅ community_id / community tables OK');

        // ── Migration 007: pin engagement metrics + diary verified flag ─────
        await pool.query(`ALTER TABLE pins ADD COLUMN IF NOT EXISTS pass_through_count INTEGER DEFAULT 0`);
        await pool.query(`ALTER TABLE pins ADD COLUMN IF NOT EXISTS hide_count INTEGER DEFAULT 0`);
        await pool.query(`ALTER TABLE pins ADD COLUMN IF NOT EXISTS report_count INTEGER DEFAULT 0`);
        await pool.query(`ALTER TABLE user_activities ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP WITH TIME ZONE`);
        await pool.query(`ALTER TABLE user_activities ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT FALSE`);
        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_user_activities_ghost
            ON user_activities (user_id, pin_id)
            WHERE activity_type = 'ghost_pass'
        `);
        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_pins_fts
            ON pins
            USING gin(to_tsvector('simple', title || ' ' || COALESCE(directions, '') || ' ' || COALESCE(details, '')))
        `);
        console.log('✅ pin metrics / diary verified OK');

        // ── Migration 008: key pin fields + text validation guardrails ──────────

        // 4. users: nickname, bio, username (display profile fields)
        await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS nickname VARCHAR(20)`);
        await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS bio VARCHAR(15)`);
        await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS username VARCHAR(15)`);

        // Unique index on username (non-null only)
        await pool.query(`
            CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username
            ON users (username)
            WHERE username IS NOT NULL
        `);

        // Alphanumeric constraint on username (skip if already exists)
        await pool.query(`
            DO $$ BEGIN
                ALTER TABLE users ADD CONSTRAINT users_username_alphanumeric
                    CHECK (username IS NULL OR username ~ '^[a-zA-Z0-9_]+$');
            EXCEPTION WHEN duplicate_object THEN NULL;
            END $$
        `);

        // Length constraints on nickname, bio, username (skip if already exist)
        await pool.query(`
            DO $$ BEGIN
                ALTER TABLE users ADD CONSTRAINT users_nickname_length
                    CHECK (nickname IS NULL OR char_length(nickname) <= 20);
            EXCEPTION WHEN duplicate_object THEN NULL;
            END $$
        `);
        await pool.query(`
            DO $$ BEGIN
                ALTER TABLE users ADD CONSTRAINT users_bio_length
                    CHECK (bio IS NULL OR char_length(bio) <= 15);
            EXCEPTION WHEN duplicate_object THEN NULL;
            END $$
        `);
        await pool.query(`
            DO $$ BEGIN
                ALTER TABLE users ADD CONSTRAINT users_username_length
                    CHECK (username IS NULL OR char_length(username) <= 15);
            EXCEPTION WHEN duplicate_object THEN NULL;
            END $$
        `);
        console.log('✅ users profile fields (nickname, bio, username) OK');

        // 5. pins: creator_snapshot — denormalised nickname/bio at creation time
        await pool.query(`ALTER TABLE pins ADD COLUMN IF NOT EXISTS creator_snapshot JSONB NOT NULL DEFAULT '{}'`);
        console.log('✅ pins.creator_snapshot OK');

        // 6. pins: make expires_at nullable (null = apply 1-year rule at query time)
        await pool.query(`ALTER TABLE pins ALTER COLUMN expires_at DROP NOT NULL`);
        console.log('✅ pins.expires_at now nullable OK');

        // 7. pins: DB-level text CHECK constraints (NOT VALID so existing rows are skipped)
        await pool.query(`
            DO $$ BEGIN
                ALTER TABLE pins ADD CONSTRAINT pins_title_length
                    CHECK (char_length(title) <= 10)
                    NOT VALID;
            EXCEPTION WHEN duplicate_object THEN NULL;
            END $$
        `);
        await pool.query(`ALTER TABLE pins DROP CONSTRAINT IF EXISTS pins_directions_length`);
        await pool.query(`
            DO $$ BEGIN
                ALTER TABLE pins ADD CONSTRAINT pins_directions_length
                    CHECK (char_length(directions) BETWEEN 5 AND 500)
                    NOT VALID;
            EXCEPTION WHEN duplicate_object THEN NULL;
            END $$
        `);

        // Always drop the old details constraint then recreate it with the
        // relaxed rule. Two separate queries so there is no ambiguity about
        // which exception handler fires — critical for Render cold-start safety.
        await pool.query(`ALTER TABLE pins DROP CONSTRAINT IF EXISTS pins_details_length`);
        await pool.query(`
            ALTER TABLE pins ADD CONSTRAINT pins_details_length
                CHECK (
                    details IS NULL
                    OR char_length(details) = 0
                    OR char_length(details) <= 2000
                )
                NOT VALID
        `);
        console.log('✅ pins text CHECK constraints OK');

        console.log('✅ Database migration completed successfully!');
    } catch (error) {
        console.error('❌ Migration failed:', error);
        throw error;
    }
}
