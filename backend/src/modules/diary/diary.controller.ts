import type { FastifyInstance } from 'fastify';
import { diaryService } from './diary.service.js';
import { requireAuth } from '../../middleware/role.middleware.js';

export async function diaryRoutes(fastify: FastifyInstance) {
    // ── Existing: timeline ────────────────────────────────────────────────────
    fastify.get('/timeline', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const userId = request.user.userId;
            const limit = Number(request.query.limit) || 100;
            const startDate = request.query.startDate ? new Date(request.query.startDate) : undefined;
            const endDate = request.query.endDate ? new Date(request.query.endDate) : undefined;
            const timeline = await diaryService.getUserTimeline(userId, startDate, endDate, limit);
            return reply.send({ timeline, count: timeline.length });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to fetch timeline' });
        }
    });

    // ── Existing: stats ───────────────────────────────────────────────────────
    fastify.get('/stats', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const userId = request.user.userId;
            const stats = await diaryService.getUserStats(userId);
            return reply.send(stats);
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to fetch stats' });
        }
    });

    // ── Existing: log activity (now also increments pin metrics) ─────────────
    fastify.post('/log', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const userId = request.user.userId;
            const { pinId, activityType, metadata } = request.body as any;
            const activity = await diaryService.logActivity(userId, pinId, activityType, metadata);
            return reply.code(201).send({ message: 'Activity logged', activity });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to log activity' });
        }
    });

    // ── spec 4.1 Tab 1: Passive log (ghost + verified) ────────────────────────
    // GET /diary/passive-log?sort=recent|like_count&limit=100
    fastify.get('/passive-log', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const userId = request.user.userId;
            const sort = (request.query.sort === 'like_count') ? 'like_count' : 'recent';
            const limit = Number(request.query.limit) || 100;
            const log = await diaryService.getPassiveLog(userId, sort, limit);
            return reply.send({ entries: log, count: log.length });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to fetch passive log' });
        }
    });

    // ── spec 4.1 Tab 1: Upgrade ghost → Verified (Like action) ───────────────
    // POST /diary/ghost/:pinId/verify
    fastify.post('/ghost/:pinId/verify', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const userId = request.user.userId;
            const { pinId } = request.params;
            await diaryService.verifyGhostPin(userId, pinId);
            return reply.send({ message: 'Ghost pin verified', pinId });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to verify ghost pin' });
        }
    });

    // ── spec 4.1 Tab 2: My pins with full engagement metrics ─────────────────
    // GET /diary/my-pins-metrics
    fastify.get('/my-pins-metrics', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const userId = request.user.userId;
            const pins = await diaryService.getMyPinsWithMetrics(userId);
            return reply.send({ pins, count: pins.length });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to fetch pin metrics' });
        }
    });

    // ── spec 4.2: Full-text search ────────────────────────────────────────────
    // GET /diary/search?q=keyword
    fastify.get('/search', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const userId = request.user.userId;
            const q = (request.query.q as string) || '';
            const results = await diaryService.searchDiary(userId, q);
            return reply.send({ results, count: results.length });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Search failed' });
        }
    });
}
