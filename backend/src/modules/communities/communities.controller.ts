import type { FastifyInstance } from 'fastify';
import { communitiesService } from './communities.service.js';
import { requireAdmin, requireAuth } from '../../middleware/role.middleware.js';
import type { CreateCommunityDTO, PostMessageDTO, AddReactionDTO } from './communities.types.js';

export async function communitiesRoutes(fastify: FastifyInstance) {
    /**
     * Create a community (admin only)
     */
    fastify.post<{ Body: CreateCommunityDTO }>(
        '/',
        { preHandler: requireAdmin },
        async (request: any, reply) => {
            try {
                const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';
                const community = await communitiesService.createCommunity(request.body, userId);

                return reply.code(201).send({
                    message: 'Community created',
                    community,
                });
            } catch (error: any) {
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Failed to create community' });
            }
        }
    );

    /**
     * Find or Create Community (for Pin linking)
     */
    fastify.post<{ Body: { name: string } }>(
        '/find-or-create',
        { preHandler: requireAuth },
        async (request: any, reply) => {
            try {
                const { name } = request.body;
                const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';

                const community = await communitiesService.findOrCreateCommunity(name, userId);

                // Auto-join the user to this community
                await communitiesService.joinCommunity(community.id, userId);

                return reply.send({ community });
            } catch (error: any) {
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Failed to find or create community' });
            }
        }
    );

    /**
     * Get user's joined communities
     */
    fastify.get('/joined', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';
            const communities = await communitiesService.getUserCommunities(userId);

            return reply.send({ communities, count: communities.length });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to fetch communities' });
        }
    });

    /**
     * Join a community
     */
    fastify.post('/:communityId/join', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const { communityId } = request.params;
            const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';

            await communitiesService.joinCommunity(communityId, userId);

            return reply.send({ message: 'Joined community successfully' });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to join community' });
        }
    });

    /**
     * Leave a community
     */
    fastify.delete('/:communityId/leave', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const { communityId } = request.params;
            const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';

            await communitiesService.leaveCommunity(communityId, userId);

            return reply.send({ message: 'Left community successfully' });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to leave community' });
        }
    });

    /**
     * Post message to community (admin only)
     */
    fastify.post<{ Body: PostMessageDTO }>(
        '/:communityId/messages',
        { preHandler: requireAuth },
        async (request: any, reply) => {
            try {
                const { communityId } = request.params;
                const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';
                const userRole = request.user?.role;

                // Check permissions (Admin OR Community Creator)
                const community = await communitiesService.getCommunityById(communityId);
                if (!community) {
                    return reply.code(404).send({ error: 'Community not found' });
                }

                if (community.createdBy !== userId && userRole !== 'admin') {
                    return reply.code(403).send({ error: 'Only the Community Admin can post updates.' });
                }

                const message = await communitiesService.postMessage(
                    communityId,
                    userId,
                    request.body
                );

                // Emit Socket.io event (will implement in next phase)
                // io.to(`community_${communityId}`).emit('new_message', message);

                return reply.code(201).send({ message: 'Message posted', data: message });
            } catch (error: any) {
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Failed to post message' });
            }
        }
    );

    /**
     * Get community messages
     */
    fastify.get('/:communityId/messages', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const { communityId } = request.params;
            const limit = Number(request.query.limit) || 50;
            const offset = Number(request.query.offset) || 0;

            const messages = await communitiesService.getCommunityMessages(communityId, limit, offset);

            return reply.send({ messages, count: messages.length });
        } catch (error: any) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to fetch messages' });
        }
    });

    /**
     * Add/remove emoji reaction
     */
    fastify.post<{ Body: AddReactionDTO }>(
        '/messages/:messageId/reactions',
        { preHandler: requireAuth },
        async (request: any, reply) => {
            try {
                const { messageId } = request.params;
                const userId = request.user?.userId || '123e4567-e89b-12d3-a456-426614174000';
                const { emoji } = request.body;

                await communitiesService.toggleReaction(messageId, userId, emoji);

                return reply.send({ message: 'Reaction updated' });
            } catch (error: any) {
                fastify.log.error(error);
                return reply.code(500).send({ error: 'Failed to update reaction' });
            }
        }
    );
}
