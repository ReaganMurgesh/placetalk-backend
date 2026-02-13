import { pool } from '../../config/database.js';
import type { Community, CommunityMessage, CreateCommunityDTO, PostMessageDTO } from './communities.types.js';

export class CommunitiesService {
    /**
     * Create a new community (admin only)
     */
    async createCommunity(data: CreateCommunityDTO, createdBy: string): Promise<Community> {
        const result = await pool.query(
            `INSERT INTO communities (name, description, image_url, created_by)
       VALUES ($1, $2, $3, $4)
       RETURNING id, name, description, image_url AS "imageUrl", created_by AS "createdBy", 
                 created_at AS "createdAt", updated_at AS "updatedAt"`,
            [data.name, data.description, data.imageUrl, createdBy]
        );

        return result.rows[0];
    }

    /**
     * Get all communities user has joined
     */
    async getUserCommunities(userId: string): Promise<Community[]> {
        const result = await pool.query(
            `SELECT DISTINCT c.id, c.name, c.description, c.image_url AS "imageUrl", 
                    c.created_by AS "createdBy", c.created_at AS "createdAt", c.updated_at AS "updatedAt"
             FROM communities c
             LEFT JOIN community_members cm ON c.id = cm.community_id
             WHERE cm.user_id = $1 OR c.name = 'PlaceTalk Global'
             ORDER BY c.created_at DESC`,
            [userId]
        );

        return result.rows;
    }

    /**
     * Join a community
     */
    async joinCommunity(communityId: string, userId: string): Promise<void> {
        await pool.query(
            `INSERT INTO community_members (community_id, user_id)
       VALUES ($1, $2)
       ON CONFLICT (community_id, user_id) DO NOTHING`,
            [communityId, userId]
        );
    }

    /**
     * Leave a community
     */
    async leaveCommunity(communityId: string, userId: string): Promise<void> {
        await pool.query(
            'DELETE FROM community_members WHERE community_id = $1 AND user_id = $2',
            [communityId, userId]
        );
    }

    /**
     * Post a message to community (admin only)
     */
    async postMessage(
        communityId: string,
        userId: string,
        data: PostMessageDTO
    ): Promise<CommunityMessage> {
        const result = await pool.query(
            `INSERT INTO community_messages (community_id, user_id, content, image_url)
       VALUES ($1, $2, $3, $4)
       RETURNING id, community_id AS "communityId", user_id AS "userId", 
                 content, image_url AS "imageUrl", reactions, created_at AS "createdAt"`,
            [communityId, userId, data.content, data.imageUrl]
        );

        return result.rows[0];
    }

    /**
     * Add or remove reaction to a message
     */
    async toggleReaction(messageId: string, userId: string, emoji: string): Promise<void> {
        // Fetch current reactions
        const result = await pool.query(
            'SELECT reactions FROM community_messages WHERE id = $1',
            [messageId]
        );

        if (result.rows.length === 0) {
            throw new Error('Message not found');
        }

        const reactions = result.rows[0].reactions || {};

        // Toggle reaction (add if not present, remove if present)
        if (!reactions[emoji]) {
            reactions[emoji] = [];
        }

        const userIndex = reactions[emoji].indexOf(userId);
        if (userIndex > -1) {
            // Remove reaction
            reactions[emoji].splice(userIndex, 1);
            if (reactions[emoji].length === 0) {
                delete reactions[emoji];
            }
        } else {
            // Add reaction
            reactions[emoji].push(userId);
        }

        // Update database
        await pool.query(
            'UPDATE community_messages SET reactions = $1 WHERE id = $2',
            [JSON.stringify(reactions), messageId]
        );
    }

    /**
     * Get community messages (paginated)
     */
    async getCommunityMessages(
        communityId: string,
        limit: number = 50,
        offset: number = 0
    ): Promise<CommunityMessage[]> {
        const result = await pool.query(
            `SELECT id, community_id AS "communityId", user_id AS "userId", 
                    content, image_url AS "imageUrl", reactions, created_at AS "createdAt"
       FROM community_messages
       WHERE community_id = $1
       ORDER BY created_at DESC
       LIMIT $2 OFFSET $3`,
            [communityId, limit, offset]
        );

        return result.rows;
    }

    /**
     * Check if user is member of community
     */
    async isMember(communityId: string, userId: string): Promise<boolean> {
        const result = await pool.query(
            'SELECT 1 FROM community_members WHERE community_id = $1 AND user_id = $2',
            [communityId, userId]
        );

        return result.rows.length > 0;
    }
}

export const communitiesService = new CommunitiesService();
