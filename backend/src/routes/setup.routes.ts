import type { FastifyInstance } from 'fastify';
import { pool } from '../config/database.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export async function setupRoutes(fastify: FastifyInstance) {
    /**
     * Run database migrations
     * Call this endpoint once to set up social features tables
     */
    fastify.get('/setup/migrate-social', async (request, reply) => {
        try {
            // Read the migration SQL file
            const migrationPath = path.join(__dirname, '../../migrations/003_social_features.sql');
            const migrationSQL = fs.readFileSync(migrationPath, 'utf8');

            // Execute the migration
            await pool.query(migrationSQL);

            return reply.send({
                success: true,
                message: 'Social features migration completed successfully!',
                tables: [
                    'communities',
                    'community_members',
                    'community_messages',
                    'user_activities',
                    'users (updated with role field)'
                ]
            });
        } catch (error: any) {
            fastify.log.error(error);

            // Check if tables already exist
            if (error.message?.includes('already exists')) {
                return reply.send({
                    success: true,
                    message: 'Migration already run - tables exist',
                    note: 'Social features are ready to use!'
                });
            }

            return reply.code(500).send({
                success: false,
                error: 'Migration failed',
                details: error.message
            });
        }
    });

    /**
     * Health check for social features
     */
    fastify.get('/setup/check-social', async (request, reply) => {
        try {
            const tableChecks = await Promise.all([
                pool.query("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'communities')"),
                pool.query("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'community_members')"),
                pool.query("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'community_messages')"),
                pool.query("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_activities')"),
            ]);

            const tablesExist = {
                communities: tableChecks[0].rows[0].exists,
                community_members: tableChecks[1].rows[0].exists,
                community_messages: tableChecks[2].rows[0].exists,
                user_activities: tableChecks[3].rows[0].exists,
            };

            const allExist = Object.values(tablesExist).every(exists => exists);

            return reply.send({
                ready: allExist,
                tables: tablesExist,
                message: allExist
                    ? 'Social features tables are ready!'
                    : 'Some tables are missing. Run /setup/migrate-social'
            });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({
                error: 'Health check failed',
                details: error.message
            });
        }
        });

        /**
         * Force-fix DB check constraints for the pins table.
         * Drops the old strict constraints and recreates them with relaxed rules.
         * Also normalizes any existing pins that violate the old constraints.
         * Call this once via:  POST /setup/fix-constraints
         */
        fastify.post('/fix-constraints', async (request, reply) => {
            const steps: Array<{ step: string; status: string; detail?: string }> = [];

            // Step: read existing constraints
            try {
                const existing = await pool.query(`
                    SELECT conname, pg_get_constraintdef(oid) AS def
                    FROM pg_constraint
                    WHERE conrelid = 'pins'::regclass
                      AND conname IN ('pins_details_length', 'pins_directions_length')
                `);
                steps.push({ step: 'read_existing_constraints', status: 'ok', detail: JSON.stringify(existing.rows) });
            } catch (err: any) {
                steps.push({ step: 'read_existing_constraints', status: 'error', detail: err.message });
            }

            // Drop and recreate details constraint (relaxed)
            try {
                await pool.query(`ALTER TABLE pins DROP CONSTRAINT IF EXISTS pins_details_length`);
                await pool.query(`
                    ALTER TABLE pins ADD CONSTRAINT pins_details_length
                        CHECK (details IS NULL OR char_length(details) = 0 OR char_length(details) <= 2000)
                        NOT VALID
                `);
                steps.push({ step: 'relax_details_constraint', status: 'ok' });
            } catch (err: any) {
                steps.push({ step: 'relax_details_constraint', status: 'error', detail: err.message });
            }

            // Drop and recreate directions constraint (relaxed)
            try {
                await pool.query(`ALTER TABLE pins DROP CONSTRAINT IF EXISTS pins_directions_length`);
                await pool.query(`
                    ALTER TABLE pins ADD CONSTRAINT pins_directions_length
                        CHECK (char_length(directions) BETWEEN 5 AND 500)
                        NOT VALID
                `);
                steps.push({ step: 'relax_directions_constraint', status: 'ok' });
            } catch (err: any) {
                steps.push({ step: 'relax_directions_constraint', status: 'error', detail: err.message });
            }

            // Normalize oversized details (>500) and directions (>500)
            try {
                const res = await pool.query(`
                    UPDATE pins
                    SET
                        details = CASE WHEN details IS NOT NULL AND char_length(details) > 500 THEN LEFT(details, 500) ELSE details END,
                        directions = CASE WHEN directions IS NOT NULL AND char_length(directions) > 500 THEN LEFT(directions, 500) ELSE directions END,
                        updated_at = NOW()
                    WHERE char_length(details) > 500 OR char_length(directions) > 500
                    RETURNING id, title, char_length(details) AS details_len, char_length(directions) AS directions_len
                `);
                steps.push({ step: 'normalize_existing_text', status: 'ok', detail: `${res.rowCount} rows updated` });
            } catch (err: any) {
                steps.push({ step: 'normalize_existing_text', status: 'error', detail: err.message });
            }

            // Verify constraints
            try {
                const after = await pool.query(`
                    SELECT conname, pg_get_constraintdef(oid) AS def
                    FROM pg_constraint
                    WHERE conrelid = 'pins'::regclass
                      AND conname IN ('pins_details_length', 'pins_directions_length')
                `);
                steps.push({ step: 'verify_constraints_after', status: 'ok', detail: JSON.stringify(after.rows) });
            } catch (err: any) {
                steps.push({ step: 'verify_constraints_after', status: 'error', detail: err.message });
            }

            const anyError = steps.some(s => s.status === 'error');
            return reply.code(anyError ? 207 : 200).send({ success: !anyError, steps });
        });

    /**
     * Fix the interactions table column name mismatch.
     * The original schema created the column as "action" but the service
     * queries use "interaction_type".  This endpoint renames it and verifies.
     * Call via:  POST /setup/fix-interactions
     */
    fastify.post('/fix-interactions', async (request, reply) => {
        const steps: Array<{ step: string; status: string; detail?: string }> = [];

        // 1. Check what columns exist
        try {
            const cols = await pool.query(`
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = 'interactions'
                ORDER BY column_name
            `);
            steps.push({ step: 'read_columns', status: 'ok', detail: JSON.stringify(cols.rows.map((r: any) => r.column_name)) });
        } catch (err: any) {
            steps.push({ step: 'read_columns', status: 'error', detail: err.message });
        }

        // 2. Rename action → interaction_type if needed
        try {
            const actionExists = await pool.query(`
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'interactions' AND column_name = 'action'
            `);
            const itExists = await pool.query(`
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'interactions' AND column_name = 'interaction_type'
            `);

            if (actionExists.rows.length > 0 && itExists.rows.length === 0) {
                await pool.query(`ALTER TABLE interactions RENAME COLUMN action TO interaction_type`);
                steps.push({ step: 'rename_action_to_interaction_type', status: 'ok', detail: 'renamed' });
            } else if (itExists.rows.length > 0) {
                steps.push({ step: 'rename_action_to_interaction_type', status: 'ok', detail: 'already interaction_type — no rename needed' });
            } else {
                steps.push({ step: 'rename_action_to_interaction_type', status: 'error', detail: 'neither action nor interaction_type column found — table may be missing' });
            }
        } catch (err: any) {
            steps.push({ step: 'rename_action_to_interaction_type', status: 'error', detail: err.message });
        }

        // 3. Drop old CHECK constraint on action column (may have stale reference)
        try {
            const constraints = await pool.query(`
                SELECT conname, pg_get_constraintdef(oid) AS def FROM pg_constraint
                WHERE conrelid = 'interactions'::regclass AND contype IN ('c', 'u')
            `);
            steps.push({ step: 'list_constraints', status: 'ok', detail: JSON.stringify(constraints.rows) });
        } catch (err: any) {
            steps.push({ step: 'list_constraints', status: 'error', detail: err.message });
        }

        // 4. Fix unique constraint: ensure UNIQUE(user_id, pin_id), not old UNIQUE(pin_id, user_id, action/interaction_type)
        try {
            const oldUniques = await pool.query(`
                SELECT DISTINCT c.conname
                FROM pg_constraint c
                JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
                WHERE c.conrelid = 'interactions'::regclass
                  AND c.contype = 'u'
                  AND a.attname IN ('action', 'interaction_type')
            `);
            const dropped: string[] = [];
            for (const row of oldUniques.rows) {
                await pool.query(`ALTER TABLE interactions DROP CONSTRAINT IF EXISTS "${row.conname}"`);
                dropped.push(row.conname);
            }
            // Deduplicate: keep most recent row per user+pin
            const dupResult = await pool.query(`
                DELETE FROM interactions a
                USING interactions b
                WHERE a.created_at < b.created_at
                  AND a.user_id = b.user_id
                  AND a.pin_id = b.pin_id
            `);
            // Add correct unique constraint
            await pool.query(`
                DO $$ BEGIN
                    ALTER TABLE interactions ADD CONSTRAINT interactions_user_pin_unique UNIQUE (user_id, pin_id);
                EXCEPTION WHEN duplicate_object THEN NULL;
                END $$
            `);
            steps.push({
                step: 'fix_unique_constraint',
                status: 'ok',
                detail: `dropped: ${JSON.stringify(dropped)}, deduped: ${dupResult.rowCount ?? 0} rows, added UNIQUE(user_id, pin_id)`
            });
        } catch (err: any) {
            steps.push({ step: 'fix_unique_constraint', status: 'error', detail: err.message });
        }

        // 5. Test an INSERT and ROLLBACK to verify the column works
        try {
            await pool.query('BEGIN');
            await pool.query(`
                INSERT INTO interactions (user_id, pin_id, interaction_type)
                VALUES (
                    (SELECT id FROM users LIMIT 1),
                    (SELECT id FROM pins WHERE is_deleted = FALSE LIMIT 1),
                    'like'
                )
                ON CONFLICT DO NOTHING
            `);
            await pool.query('ROLLBACK');
            steps.push({ step: 'test_insert_interaction_type', status: 'ok', detail: 'INSERT using interaction_type succeeded (rolled back)' });
        } catch (err: any) {
            await pool.query('ROLLBACK').catch(() => {});
            steps.push({ step: 'test_insert_interaction_type', status: 'error', detail: err.message });
        }

        const anyError = steps.some(s => s.status === 'error');
        return reply.code(anyError ? 207 : 200).send({ success: !anyError, steps });
    });
}
