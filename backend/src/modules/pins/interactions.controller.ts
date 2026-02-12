import type { FastifyInstance } from 'fastify';
import { InteractionsService } from './interactions.service.js';

const interactionsService = new InteractionsService();

export async function interactionsRoutes(fastify: FastifyInstance) {
    /**
     * Like a pin — NO AUTH for testing
     */
    fastify.post<{ Params: { id: string } }>(
        '/:id/like',
        async (request: any, reply) => {
            try {
                const pinId = request.params.id;
                const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';

                const result = await interactionsService.likePin(pinId, userId);
                return reply.send(result);
            } catch (error: any) {
                if (error.message?.includes('not found')) {
                    return reply.code(404).send({ error: error.message });
                }
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Failed to like pin' });
            }
        }
    );

    /**
     * Dislike a pin — NO AUTH for testing
     */
    fastify.post<{ Params: { id: string } }>(
        '/:id/dislike',
        async (request: any, reply) => {
            try {
                const pinId = request.params.id;
                const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';

                const result = await interactionsService.dislikePin(pinId, userId);
                return reply.send(result);
            } catch (error: any) {
                if (error.message?.includes('not found')) {
                    return reply.code(404).send({ error: error.message });
                }
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Failed to dislike pin' });
            }
        }
    );
}
