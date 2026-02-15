import type { FastifyInstance } from 'fastify';
import { InteractionsService } from './interactions.service.js';
import { diaryService } from '../diary/diary.service.js';

const interactionsService = new InteractionsService();

export async function interactionsRoutes(fastify: FastifyInstance) {
    /**
     * Like a pin
     */
    fastify.post<{ Params: { id: string } }>(
        '/:id/like',
        async (request: any, reply) => {
            try {
                const pinId = request.params.id;
                const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';

                const result = await interactionsService.likePin(userId, pinId);

                // Log to Diary
                diaryService.logActivity(userId, pinId, 'liked').catch(e => console.error('Diary Log/Like Error:', e));

                return reply.send(result);
            } catch (error: any) {
                if (error.message?.includes('not found')) {
                    return reply.code(404).send({ error: error.message });
                }
                if (error.message?.includes('Already')) {
                    return reply.code(400).send({ error: error.message });
                }
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Failed to like pin' });
            }
        }
    );

    /**
     * Report a pin (Global Deprioritization Vote)
     */
    fastify.post<{ Params: { id: string } }>(
        '/:id/report',
        async (request: any, reply) => {
            try {
                const pinId = request.params.id;
                const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';

                const result = await interactionsService.reportPin(userId, pinId);

                // Log to Diary
                diaryService.logActivity(userId, pinId, 'reported').catch(e => console.error('Diary Log/Report Error:', e));

                return reply.send(result);
            } catch (error: any) {
                if (error.message?.includes('not found')) {
                    return reply.code(404).send({ error: error.message });
                }
                if (error.message?.includes('Already')) {
                    return reply.code(400).send({ error: error.message });
                }
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Failed to report pin' });
            }
        }
    );

    /**
     * Hide a pin (Personal Mute)
     */
    fastify.post<{ Params: { id: string } }>(
        '/:id/hide',
        async (request: any, reply) => {
            try {
                const pinId = request.params.id;
                const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';

                await interactionsService.hidePin(userId, pinId);

                // Log to Diary
                diaryService.logActivity(userId, pinId, 'hidden').catch(e => console.error('Diary Log/Hide Error:', e));

                return reply.send({ message: 'Pin hidden' });
            } catch (error: any) {
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Failed to hide pin' });
            }
        }
    );
}
