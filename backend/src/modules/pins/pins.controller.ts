import type { FastifyInstance } from 'fastify';
import { PinsService } from './pins.service.js';
import type { CreatePinDTO } from './pins.types.js';
import { requireAuth } from '../../middleware/role.middleware.js';

const pinsService = new PinsService();

export async function pinsRoutes(fastify: FastifyInstance) {
    /**
     * Create a new pin — NO AUTH for testing
     */
    fastify.post<{ Body: CreatePinDTO }>(
        '/',
        { preHandler: requireAuth },
        async (request: any, reply) => {
            try {
                const { title, directions, details, lat, lon, type, pinCategory, attributeId, visibleFrom, visibleTo } =
                    request.body;

                if (!title || !directions || lat === undefined || lon === undefined) {
                    return reply.code(400).send({ error: 'Title, directions, and coordinates are required' });
                }

                if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
                    return reply.code(400).send({ error: 'Invalid coordinates' });
                }

                const userId = request.user.userId; // Remove fallback

                const pin = await pinsService.createPin(
                    {
                        title,
                        directions,
                        details,
                        lat,
                        lon,
                        type: type || 'location',
                        pinCategory: pinCategory || 'normal',
                        attributeId,
                        visibleFrom,
                        visibleTo,
                    },
                    userId
                );

                return reply.code(201).send({
                    message: 'Pin created successfully',
                    pin,
                });
            } catch (error: any) {
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Failed to create pin' });
            }
        }
    );

    /**
     * Get pin by ID — NO AUTH for testing
     */
    fastify.get<{ Params: { id: string } }>(
        '/:id',
        async (request, reply) => {
            try {
                const pin = await pinsService.getPinById(request.params.id);
                if (!pin) {
                    return reply.code(404).send({ error: 'Pin not found' });
                }
                return reply.send({ pin });
            } catch (error) {
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Failed to fetch pin' });
            }
        }
    );

    /**
     * Get user's created pins — with proper user isolation
     */
    fastify.get(
        '/my/pins',
        { preHandler: requireAuth },
        async (request: any, reply) => {
            try {
                const userId = request.user.userId;
                console.log(`👤 PinsController: Getting pins for user ${userId}`);
                
                const pins = await pinsService.getUserPins(userId);
                
                console.log(`📍 PinsController: Found ${pins.length} pins for user ${userId}`);
                
                return reply.send({ pins, count: pins.length });
            } catch (error) {
                console.error(`❌ PinsController: Error fetching pins:`, error);
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Failed to fetch pins' });
            }
        }
    );

    /**
     * SERENDIPITY: Mark pin as "Good" (7-day cooldown)
     */
    fastify.post('/:pinId/mark-good', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const { pinId } = request.params;
            const userId = request.user.userId; // Remove fallback

            const { pinInteractionsService } = await import('./pin-interactions.service.js');
            const interaction = await pinInteractionsService.markPinAsGood(userId, pinId);

            return reply.send({
                success: true,
                message: 'Pin marked as Good - remind me in 7 days',
                interaction,
            });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to mark pin as good' });
        }
    });

    /**
     * SERENDIPITY: Mark pin as "Bad" (mute forever)
     */
    fastify.post('/:pinId/mark-bad', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const { pinId } = request.params;
            const userId = request.user.userId; // Remove fallback

            const { pinInteractionsService } = await import('./pin-interactions.service.js');
            const interaction = await pinInteractionsService.markPinAsBad(userId, pinId);

            return reply.send({
                success: true,
                message: 'Pin muted - you will never be notified again',
                interaction,
            });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to mute pin' });
        }
    });

    /**
     * SERENDIPITY: Unmute pin (tap on map)
     */
    fastify.post('/:pinId/unmute', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const { pinId } = request.params;
            const userId = request.user.userId; // Remove fallback

            const { pinInteractionsService } = await import('./pin-interactions.service.js');
            const interaction = await pinInteractionsService.unmutePinForever(userId, pinId);

            return reply.send({
                success: true,
                message: 'Pin unmuted - you will be notified again',
                interaction,
            });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to unmute pin' });
        }
    });

    /**
     * Get all user interactions (for syncing to mobile)
     */
    fastify.get('/interactions', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const userId = request.user.userId; // Remove fallback

            const { pinInteractionsService } = await import('./pin-interactions.service.js');
            const interactions = await pinInteractionsService.getUserInteractions(userId);

            return reply.send({
                interactions,
                count: interactions.length,
            });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to fetch interactions' });
        }
    });
}
