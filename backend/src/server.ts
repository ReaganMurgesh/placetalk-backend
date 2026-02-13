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
