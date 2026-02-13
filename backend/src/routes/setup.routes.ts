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
}
