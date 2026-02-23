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

    }
