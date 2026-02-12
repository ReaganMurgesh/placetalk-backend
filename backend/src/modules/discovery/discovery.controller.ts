import type { FastifyInstance, FastifyRequest } from 'fastify';
import { DiscoveryService } from './discovery.service.js';
import type { DiscoveryHeartbeatDTO } from './discovery.types.js';

const discoveryService = new DiscoveryService();

export async function discoveryRoutes(fastify: FastifyInstance) {
    /**
     * GPS Heartbeat Endpoint
     * NO AUTH for testing — uses hardcoded userId
     */
    fastify.post<{ Body: DiscoveryHeartbeatDTO }>(
        '/heartbeat',
        async (request: any, reply) => {
            try {
                const { lat, lon } = request.body;
                const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';

                if (typeof lat !== 'number' || typeof lon !== 'number') {
                    return reply.code(400).send({ error: 'Invalid coordinates' });
                }

                if (lat < -90 || lat > 90) {
                    return reply.code(400).send({ error: 'Latitude must be between -90 and 90' });
                }

                if (lon < -180 || lon > 180) {
                    return reply.code(400).send({ error: 'Longitude must be between -180 and 180' });
                }

                const result = await discoveryService.processHeartbeat(userId, lat, lon);

                if (result.count > 0) {
                    fastify.log.info(`User ${userId} discovered ${result.count} pins at (${lat}, ${lon})`);
                }

                return reply.send(result);
            } catch (error: any) {
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Discovery failed' });
            }
        }
    );

    /**
     * Manual discovery check (for testing)
     */
    fastify.get<{ Querystring: { lat: string; lon: string } }>(
        '/nearby',
        async (request: any, reply) => {
            try {
                const lat = parseFloat(request.query.lat);
                const lon = parseFloat(request.query.lon);
                const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';

                if (isNaN(lat) || isNaN(lon)) {
                    return reply.code(400).send({ error: 'Invalid coordinates' });
                }

                const result = await discoveryService.processHeartbeat(userId, lat, lon);
                return reply.send(result);
            } catch (error: any) {
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Failed to fetch nearby pins' });
            }
        }
    );
}
