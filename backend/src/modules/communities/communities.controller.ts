import type { FastifyInstance } from 'fastify';
import { communitiesService } from './communities.service.js';
import { requireAdmin, requireAuth } from '../../middleware/role.middleware.js';
import type {
    CreateCommunityDTO, PostMessageDTO, AddReactionDTO,
    UpdateMemberSettingsDTO, ReportCommunityDTO,
} from './communities.types.js';

export async function communitiesRoutes(fastify: FastifyInstance) {

    // ── POST /communities (admin only) ──────────────────────────────────────
    fastify.post<{ Body: CreateCommunityDTO }>(
        '/',
        { preHandler: requireAdmin },
        async (request: any, reply) => {
            try {
                const community = await communitiesService.createCommunity(request.body, request.user.userId);
                return reply.code(201).send({ message: 'Community created', community });
            } catch (e: any) {
                fastify.log.error(e);
                return reply.code(500).send({ error: 'Failed to create community' });
            }
        }
    );

    // ── POST /communities/find-or-create ────────────────────────────────────
    fastify.post<{ Body: { name: string; communityType?: string } }>(
        '/find-or-create',
        { preHandler: requireAuth },
        async (request: any, reply) => {
            try {
                const { name } = request.body;
                const userId = request.user.userId;
                const community = await communitiesService.findOrCreateCommunity(name, userId);
                await communitiesService.joinCommunity(community.id, userId);
                return reply.send({ community });
            } catch (e: any) {
                fastify.log.error(e);
                return reply.code(500).send({ error: 'Failed to find or create community' });
            }
        }
    );

    // ── GET /communities/joined ─────────────────────────────────────────────
    fastify.get('/joined', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const communities = await communitiesService.getUserCommunities(request.user.userId);
            return reply.send({ communities, count: communities.length });
        } catch (e: any) {
            fastify.log.error(e);
            return reply.code(500).send({ error: 'Failed to fetch communities' });
        }
    });

    // ── GET /communities/near?lat=&lon=&radius= (spec 3.5 empty state) ──────
    fastify.get('/near', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const { lat, lon, radius } = request.query as any;
            if (!lat || !lon) return reply.code(400).send({ error: 'lat and lon required' });
            const communities = await communitiesService.getCommunitiesNear(
                parseFloat(lat), parseFloat(lon),
                radius ? parseFloat(radius) : 5000,
                request.user.userId,
            );
            return reply.send({ communities });
        } catch (e: any) {
            fastify.log.error(e);
            return reply.code(500).send({ error: 'Failed to fetch nearby communities' });
        }
    });

    // ── POST /communities/join-by-invite/:code (spec 3.2) ───────────────────
    fastify.post<{ Params: { code: string } }>(
        '/join-by-invite/:code',
        { preHandler: requireAuth },
        async (request: any, reply) => {
            try {
                const community = await communitiesService.joinByInviteCode(
                    request.params.code, request.user.userId
                );
                return reply.send({ community, message: 'Joined community via invite' });
            } catch (e: any) {
                fastify.log.error(e);
                const code = e?.statusCode ?? 500;
                return reply.code(code).send({ error: e?.message ?? 'Failed to join' });
            }
        }
    );

    // ── GET /communities/:communityId ───────────────────────────────────────
    fastify.get<{ Params: { communityId: string } }>(
        '/:communityId',
        { preHandler: requireAuth },
        async (request: any, reply) => {
            try {
                const community = await communitiesService.getCommunityById(
                    request.params.communityId, request.user.userId
                );
                if (!community) return reply.code(404).send({ error: 'Community not found' });
                return reply.send({ community });
            } catch (e: any) {
                fastify.log.error(e);
                return reply.code(500).send({ error: 'Failed to fetch community' });
            }
        }
    );

    // ── POST /communities/:communityId/join ─────────────────────────────────
    fastify.post('/:communityId/join', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            await communitiesService.joinCommunity(request.params.communityId, request.user.userId);
            return reply.send({ message: 'Joined community successfully' });
        } catch (e: any) {
            fastify.log.error(e);
            return reply.code(500).send({ error: 'Failed to join community' });
        }
    });

    // ── DELETE /communities/:communityId/leave ──────────────────────────────
    fastify.delete('/:communityId/leave', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            await communitiesService.leaveCommunity(request.params.communityId, request.user.userId);
            return reply.send({ message: 'Left community successfully' });
        } catch (e: any) {
            fastify.log.error(e);
            return reply.code(500).send({ error: 'Failed to leave community' });
        }
    });

    // ── POST /communities/:communityId/like (spec 3.4) ──────────────────────
    fastify.post('/:communityId/like', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const result = await communitiesService.likeCommunity(
                request.params.communityId, request.user.userId
            );
            return reply.send(result);
        } catch (e: any) {
            fastify.log.error(e);
            return reply.code(500).send({ error: 'Failed to like community' });
        }
    });

    // ── DELETE /communities/:communityId/like (unlike) ──────────────────────
    fastify.delete('/:communityId/like', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const result = await communitiesService.unlikeCommunity(
                request.params.communityId, request.user.userId
            );
            return reply.send(result);
        } catch (e: any) {
            fastify.log.error(e);
            return reply.code(500).send({ error: 'Failed to unlike community' });
        }
    });

    // ── PUT /communities/:communityId/member-settings (spec 3.3 + 3.4) ──────
    fastify.put<{ Params: { communityId: string }; Body: UpdateMemberSettingsDTO }>(
        '/:communityId/member-settings',
        { preHandler: requireAuth },
        async (request: any, reply) => {
            try {
                await communitiesService.updateMemberSettings(
                    request.params.communityId, request.user.userId, request.body
                );
                return reply.send({ message: 'Settings updated' });
            } catch (e: any) {
                fastify.log.error(e);
                return reply.code(500).send({ error: 'Failed to update settings' });
            }
        }
    );

    // ── POST /communities/:communityId/invite (spec 3.2) ────────────────────
    fastify.post('/:communityId/invite', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const invite = await communitiesService.createInviteLink(
                request.params.communityId, request.user.userId
            );
            return reply.code(201).send({ invite, inviteUrl: `/join/${invite.code}` });
        } catch (e: any) {
            fastify.log.error(e);
            return reply.code(500).send({ error: 'Failed to create invite' });
        }
    });

    // ── POST /communities/:communityId/report (spec 3.4) ────────────────────
    fastify.post<{ Body: ReportCommunityDTO }>(
        '/:communityId/report',
        { preHandler: requireAuth },
        async (request: any, reply) => {
            try {
                // Report stored as a user_activity event for moderation queue
                await (await import('../../config/database.js')).pool.query(
                    `INSERT INTO user_activities (user_id, activity_type, metadata)
                     VALUES ($1, 'reported', $2)`,
                    [request.user.userId, JSON.stringify({
                        target: 'community',
                        targetId: request.params.communityId,
                        reason: request.body.reason,
                    })]
                );
                return reply.send({ message: 'Report submitted' });
            } catch (e: any) {
                fastify.log.error(e);
                return reply.code(500).send({ error: 'Failed to submit report' });
            }
        }
    );

    // ── GET /communities/:communityId/feed (spec 3.1) ────────────────────────
    fastify.get('/:communityId/feed', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const { limit, offset } = request.query as any;
            const feed = await communitiesService.getCommunityFeed(
                request.params.communityId,
                limit ? parseInt(limit) : 30,
                offset ? parseInt(offset) : 0,
            );
            return reply.send({ feed, count: feed.length });
        } catch (e: any) {
            fastify.log.error(e);
            return reply.code(500).send({ error: 'Failed to fetch feed' });
        }
    });

    // ── POST /communities/:communityId/messages ──────────────────────────────
    fastify.post<{ Body: PostMessageDTO }>(
        '/:communityId/messages',
        { preHandler: requireAuth },
        async (request: any, reply) => {
            try {
                const { communityId } = request.params;
                const userId = request.user.userId;
                const community = await communitiesService.getCommunityById(communityId);
                if (!community) return reply.code(404).send({ error: 'Community not found' });
                const isMember = await communitiesService.isMember(communityId, userId);
                if (community.createdBy !== userId && request.user?.role !== 'admin' && !isMember) {
                    return reply.code(403).send({ error: 'Join the community to post messages.' });
                }
                const message = await communitiesService.postMessage(communityId, userId, request.body);
                // Bump community updated_at so feed ordering (spec 3.1) surfaces active communities first
                await (await import('../../config/database.js')).pool.query(
                    `UPDATE communities SET updated_at = NOW() WHERE id = $1`, [communityId]
                );
                const { emitToRoom } = await import('../../config/socket.js');
                emitToRoom(`community_${communityId}`, 'new_message', message);
                return reply.code(201).send({ message: 'Message posted', data: message });
            } catch (e: any) {
                fastify.log.error(e);
                return reply.code(500).send({ error: 'Failed to post message' });
            }
        }
    );

    // ── GET /communities/:communityId/messages ───────────────────────────────
    fastify.get('/:communityId/messages', { preHandler: requireAuth }, async (request: any, reply) => {
        try {
            const { limit, offset } = request.query as any;
            const messages = await communitiesService.getCommunityMessages(
                request.params.communityId,
                Number(limit) || 50,
                Number(offset) || 0,
            );
            return reply.send({ messages, count: messages.length });
        } catch (e: any) {
            fastify.log.error(e);
            return reply.code(500).send({ error: 'Failed to fetch messages' });
        }
    });

    // ── POST /communities/messages/:messageId/reactions ──────────────────────
    fastify.post<{ Body: AddReactionDTO }>(
        '/messages/:messageId/reactions',
        { preHandler: requireAuth },
        async (request: any, reply) => {
            try {
                await communitiesService.toggleReaction(
                    request.params.messageId, request.user.userId, request.body.emoji
                );
                return reply.send({ message: 'Reaction updated' });
            } catch (e: any) {
                fastify.log.error(e);
                return reply.code(500).send({ error: 'Failed to update reaction' });
            }
        }
    );
}
