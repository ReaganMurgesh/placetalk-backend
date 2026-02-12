import type { FastifyInstance } from 'fastify';
import { PinsService } from './pins.service.js';
import type { CreatePinDTO } from './pins.types.js';

const pinsService = new PinsService();

export async function pinsRoutes(fastify: FastifyInstance) {
    /**
     * Create a new pin — NO AUTH for testing
     */
    fastify.post<{ Body: CreatePinDTO }>(
        '/',
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

                const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';

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
     * Get user's created pins — NO AUTH for testing
     */
    fastify.get(
        '/my/pins',
        async (request: any, reply) => {
            try {
                const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';
                const pins = await pinsService.getUserPins(userId);
                return reply.send({ pins, count: pins.length });
            } catch (error) {
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Failed to fetch pins' });
            }
        }
    );
}
