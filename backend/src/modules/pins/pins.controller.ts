import type { FastifyInstance } from 'fastify';
import { PinsService } from './pins.service.js';
import type { CreatePinDTO, UpdatePinDTO } from './pins.types.js';
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
                const { title, directions, details, lat, lon, type, pinCategory, attributeId, visibleFrom, visibleTo, externalLink, chatEnabled, isPrivate, communityId } =
                    request.body;

                if (!title || !directions || lat === undefined || lon === undefined) {
                    return reply.code(400).send({ error: 'Title, directions, and coordinates are required' });
                }

                // Spec 2.2: enforce field sizes server-side regardless of client
                if (title.length > 10) {
                    return reply.code(400).send({ error: 'Title must be 10 characters or less' });
                }
                if (directions.length < 50 || directions.length > 100) {
                    return reply.code(400).send({ error: 'Directions must be 50–100 characters' });
                }
                if (details && details.trim().length > 0 && (details.length < 300 || details.length > 500)) {
                    return reply.code(400).send({ error: 'Details must be 300–500 characters' });
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
                        externalLink,
                        chatEnabled: chatEnabled ?? false,
                        isPrivate: isPrivate ?? false,
                        communityId: communityId ?? undefined,
                    },
                    userId
                );

                return reply.code(201).send({
                    message: 'Pin created successfully',
                    pin,
                });
            } catch (error: any) {
                fastify.log.error(error);
                // Surface any service-level status code (400 validation, 429 quota, etc.)
                if (error.statusCode && error.statusCode < 500) {
                    return reply.code(error.statusCode).send({ error: error.message });
                }
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
     * Spec 2.4: Edit a pin (must be within 50m OR is_b2b_partner)
     */
    fastify.put<{ Params: { id: string }; Body: UpdatePinDTO }>(
        '/:id',
        { preHandler: requireAuth },
        async (request: any, reply) => {
            try {
                const { id } = request.params;
                const userId = request.user.userId;
                const { title, directions, details, externalLink, chatEnabled, userLat, userLon } = request.body;

                if (userLat === undefined || userLon === undefined) {
                    return reply.code(400).send({ error: 'userLat and userLon are required for permission check' });
                }

                // Char limit validation (same as create)
                if (title && title.length > 10) return reply.code(400).send({ error: 'Title must be 10 characters or less' });
                if (directions && (directions.length < 50 || directions.length > 100)) {
                    return reply.code(400).send({ error: 'Directions must be 50–100 characters' });
                }
                if (details && details.trim().length > 0 && (details.length < 300 || details.length > 500)) return reply.code(400).send({ error: 'Details must be 300–500 characters' });

                const pin = await pinsService.updatePin(id, userId, {
                    title, directions, details, externalLink, chatEnabled, userLat, userLon,
                });
                return reply.send({ message: 'Pin updated', pin });
            } catch (error: any) {
                fastify.log.error(error);
                if (error.statusCode && error.statusCode < 500) {
                    return reply.code(error.statusCode).send({ error: error.message });
                }
                return reply.code(500).send({ error: 'Failed to update pin' });
            }
        }
    );

    /**
     * Spec 2.4: Delete a pin (must be within 50m OR is_b2b_partner)
     */
    fastify.delete<{ Params: { id: string }; Body: { userLat: number; userLon: number } }>(
        '/:id',
        { preHandler: requireAuth },
        async (request: any, reply) => {
            try {
                const { id } = request.params;
                const userId = request.user.userId;
                const { userLat, userLon } = request.body ?? {};

                if (userLat === undefined || userLon === undefined) {
                    return reply.code(400).send({ error: 'userLat and userLon are required for permission check' });
                }

                await pinsService.deletePin(id, userId, userLat, userLon);
                return reply.send({ message: 'Pin deleted' });
            } catch (error: any) {
                fastify.log.error(error);
                if (error.statusCode === 403) return reply.code(403).send({ error: error.message });
                if (error.statusCode === 404) return reply.code(404).send({ error: error.message });
                return reply.code(500).send({ error: 'Failed to delete pin' });
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
