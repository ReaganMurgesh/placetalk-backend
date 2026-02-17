import type { FastifyInstance } from 'fastify';
import { diaryService } from './diary.service.js';
import { requireAuth } from '../../middleware/role.middleware.js';

export async function diaryRoutes(fastify: FastifyInstance) {
    /**
     * Get user's activity timeline
     */
    fastify.get('/timeline', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const userId = request.user.userId; // Remove fallback
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

    /**
     * Get user stats (streaks, badges, total activities)
     */
    fastify.get('/stats', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const userId = request.user.userId; // Remove fallback
            const stats = await diaryService.getUserStats(userId);

            return reply.send(stats);
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to fetch stats' });
        }
    });

    /**
     * Log activity manually (usually auto-triggered)
     */
    fastify.post('/log', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const userId = request.user.userId; // Remove fallback
            const { pinId, activityType, metadata } = request.body;

            const activity = await diaryService.logActivity(userId, pinId, activityType, metadata);

            return reply.code(201).send({ message: 'Activity logged', activity });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to log activity' });
        }
    });
}
