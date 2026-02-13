import 'dotenv/config';
import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import jwt from '@fastify/jwt';
import { testConnection } from './config/database.js';
import { runMigrations } from './config/migrate.js';
import { connectRedis } from './config/redis.js';
import { authRoutes } from './modules/auth/auth.controller.js';
import { discoveryRoutes } from './modules/discovery/discovery.controller.js';
import { pinsRoutes } from './modules/pins/pins.controller.js';
import { interactionsRoutes } from './modules/pins/interactions.controller.js';
import { startLifecycleWorker } from './modules/pins/lifecycle.worker.js';

const fastify = Fastify({
    logger: {
        level: process.env.NODE_ENV === 'production' ? 'warn' : 'info',
    },
});

// Register plugins
await fastify.register(cors, {
    origin: true,  // Allow all origins (mobile app)
});

await fastify.register(helmet, {
    contentSecurityPolicy: false,
});

await fastify.register(jwt, {
    secret: process.env.JWT_SECRET || 'your-secret-key',
});

// JWT authentication decorator
fastify.decorate('authenticate', async function (request, reply) {
    try {
        await request.jwtVerify();
    } catch (err) {
        reply.send(err);
    }
});

// Health check endpoint
fastify.get('/health', async () => {
    return {
        status: 'ok',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV || 'development',
    };
});

// Database migration endpoint (run once to setup social features)
fastify.get('/migrate-social', async (request, reply) => {
    try {
        const { pool } = await import('./config/database.js');
        const logs: string[] = [];

        // 1. Inspect existing constraints
        const constraints = await pool.query(`
            SELECT conname, pg_get_constraintdef(oid) as def
            FROM pg_constraint
            WHERE conrelid = 'users'::regclass AND conname LIKE '%role%'
        `);
        logs.push(`Found existing constraints: ${constraints.rows.map(r => r.conname).join(', ')}`);

        // 2. Drop ALL role constraints to be safe
        for (const row of constraints.rows) {
            await pool.query(`ALTER TABLE users DROP CONSTRAINT "${row.conname}"`);
            logs.push(`Dropped constraint: ${row.conname}`);
        }

        // 3. Drop hardcoded names just in case they weren't found above
        await pool.query(`ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check`);

        // 4. SANITIZE DATA: Fix any rows that would violate the new constraint
        // Set NULL or invalid roles to 'normal'
        await pool.query(`
            UPDATE users 
            SET role = 'normal' 
            WHERE role IS NULL 
               OR role NOT IN ('normal', 'community', 'admin')
        `);
        logs.push('Sanitized existing user roles (set invalid/null to normal)');

        // 5. Add the CORRECT constraint
        // Allowing 'normal', 'community', AND 'admin' to cover all bases
        await pool.query(`
            ALTER TABLE users ADD CONSTRAINT users_role_check 
            CHECK (role IN ('normal', 'community', 'admin'))
        `);
        logs.push('Added correct users_role_check constraint');

        // 5. Run other social tables creation
        await pool.query(`
            CREATE TABLE IF NOT EXISTS communities (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                name VARCHAR(100) NOT NULL,
                description TEXT,
                image_url TEXT,
                created_by UUID REFERENCES users(id) ON DELETE SET NULL,
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW()
            );
            
            CREATE TABLE IF NOT EXISTS community_members (
                community_id UUID REFERENCES communities(id) ON DELETE CASCADE,
                user_id UUID REFERENCES users(id) ON DELETE CASCADE,
                joined_at TIMESTAMP DEFAULT NOW(),
                PRIMARY KEY (community_id, user_id)
            );
            CREATE INDEX IF NOT EXISTS idx_community_members_user ON community_members(user_id);
            
            CREATE TABLE IF NOT EXISTS community_messages (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                community_id UUID REFERENCES communities(id) ON DELETE CASCADE,
                user_id UUID REFERENCES users(id) ON DELETE SET NULL,
                content TEXT NOT NULL,
                image_url TEXT,
                reactions JSONB DEFAULT '{}',
                created_at TIMESTAMP DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_community_messages_community ON community_messages(community_id, created_at DESC);
            
            CREATE TABLE IF NOT EXISTS user_activities (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                user_id UUID REFERENCES users(id) ON DELETE CASCADE,
                pin_id UUID REFERENCES pins(id) ON DELETE CASCADE,
                activity_type VARCHAR(20) NOT NULL CHECK (activity_type IN ('visited', 'liked', 'commented', 'created')),
                metadata JSONB DEFAULT '{}',
                created_at TIMESTAMP DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_activities_user_date ON user_activities(user_id, created_at DESC);
        `);

        return {
            success: true,
            message: 'Deep migration fix completed!',
            logs: logs,
            tables: ['communities', 'community_members', 'community_messages', 'user_activities']
        };
    } catch (error: any) {
        fastify.log.error(error);
        return reply.code(500).send({ success: false, error: error.message, stack: error.stack });
    }
});

// One-time setup endpoint to create test user
fastify.get('/setup-test-user', async (request, reply) => {
    try {
        const { pool } = await import('./config/database.js');
        await pool.query(`
            INSERT INTO users (id, name, email, password_hash, role)
            VALUES (
                '123e4567-e89b-12d3-a456-426614174000',
                'Test User',
                'test@placetalk.app',
                '$2b$10$abcdefghijklmnopqrstuvwxyz1234567890',
                'explorer'
            )
            ON CONFLICT (email) DO UPDATE SET
                id = EXCLUDED.id,
                name = EXCLUDED.name;
        `);
        return { success: true, message: 'Test user created' };
    } catch (error: any) {
        return { success: false, error: error.message };
    }
});

// Register ALL routes
await fastify.register(authRoutes, { prefix: '/auth' });
await fastify.register(discoveryRoutes, { prefix: '/discovery' });
await fastify.register(pinsRoutes, { prefix: '/pins' });
await fastify.register(interactionsRoutes, { prefix: '/pins' });

// Social features routes (Phase 8)
const { communitiesRoutes } = await import('./modules/communities/communities.controller.js');
await fastify.register(communitiesRoutes, { prefix: '/communities' });

const { diaryRoutes } = await import('./modules/diary/diary.controller.js');
await fastify.register(diaryRoutes, { prefix: '/diary' });

// Setup/migration routes (for database setup without shell access)
const { setupRoutes } = await import('./routes/setup.routes.js');
await fastify.register(setupRoutes, { prefix: '/setup' });


// Startup
const start = async () => {
    try {
        // Test database connection
        const dbConnected = await testConnection();
        if (!dbConnected) {
            console.error('Failed to connect to PostgreSQL. Exiting...');
            process.exit(1);
        }

        // Run migrations (create tables if they don't exist)
        await runMigrations();

        // Connect to Redis (disabled - not available on Render free tier)
        // await connectRedis();

        // Start lifecycle worker (checks every 60 seconds)
        startLifecycleWorker();

        // Start server
        const port = parseInt(process.env.PORT || '3000');
        await fastify.listen({ port, host: '0.0.0.0' });

        console.log(`
    🚀 PlaceTalk Backend Server Running!
    
    📍 URL: http://localhost:${port}
    🌐 Environment: ${process.env.NODE_ENV || 'development'}
    🗄️  Database: PostgreSQL + PostGIS
    ⚡ Cache: Redis
    🔐 Auth: JWT
    ♻️  Lifecycle Worker: Active (60s interval)
    
    API Endpoints:
    - GET  /health                Health check
    - POST /auth/register         User registration
    - POST /auth/login            User login
    - GET  /auth/me               Current user (authenticated)
    - POST /discovery/heartbeat   GPS heartbeat → discover pins
    - GET  /discovery/nearby      Query nearby pins
    - POST /pins                  Create a pin
    - GET  /pins/:id              Get pin by ID
    - GET  /pins/my/pins          Get user's pins
    - POST /pins/:id/like         Like a pin
    - POST /pins/:id/dislike      Dislike a pin
    
    Ready to discover serendipity! 🎲
    `);
    } catch (err) {
        fastify.log.error(err);
        process.exit(1);
    }
};

start();
