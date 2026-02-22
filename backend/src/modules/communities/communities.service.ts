import crypto from 'crypto';
import { pool } from '../../config/database.js';
import type {
    Community, CommunityMessage, CommunityFeedItem, CommunityInvite,
    CreateCommunityDTO, PostMessageDTO, UpdateMemberSettingsDTO,
} from './communities.types.js';

// ── helpers ──────────────────────────────────────────────────────────────────
const COMMUNITY_COLS = `
    c.id, c.name, c.description, c.image_url AS "imageUrl",
    c.community_type AS "communityType", c.like_count AS "likeCount",
    COALESCE(c.created_by, '00000000-0000-0000-0000-000000000000') AS "createdBy",
    c.created_at AS "createdAt", c.updated_at AS "updatedAt"
`;

function mapCommunity(row: any): Community {
    return {
        id: row.id,
        name: row.name,
        description: row.description,
        imageUrl: row.imageUrl,
        communityType: row.communityType ?? 'open',
        likeCount: Number(row.likeCount ?? 0),
        createdBy: row.createdBy,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        likedByMe: row.likedByMe ?? false,
        isMember: row.isMember ?? false,
        memberCount: row.memberCount !== undefined ? Number(row.memberCount) : undefined,
        notificationsOn: row.notificationsOn,
        hometownNotify: row.hometownNotify,
        isHidden: row.isHidden,
        hideMapPins: row.hideMapPins,
    };
}

export class CommunitiesService {

    // ── Create ────────────────────────────────────────────────────────────────
    async createCommunity(data: CreateCommunityDTO, createdBy: string): Promise<Community> {
        const result = await pool.query(
            `INSERT INTO communities (name, description, image_url, community_type, created_by)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING ${COMMUNITY_COLS}`.replace('c.', ''),
            [data.name, data.description, data.imageUrl, data.communityType ?? 'open', createdBy]
        );
        return mapCommunity(result.rows[0]);
    }

    // ── Find or create (auto-creates with type=open) ──────────────────────────
    async findOrCreateCommunity(name: string, userId: string): Promise<Community> {
        const find = await pool.query(
            `SELECT ${COMMUNITY_COLS},
                    (SELECT EXISTS(SELECT 1 FROM community_likes WHERE community_id = c.id AND user_id = $2)) AS "likedByMe",
                    (SELECT EXISTS(SELECT 1 FROM community_members WHERE community_id = c.id AND user_id = $2)) AS "isMember",
                    (SELECT COUNT(*) FROM community_members WHERE community_id = c.id) AS "memberCount"
             FROM communities c WHERE c.name = $1`,
            [name, userId]
        );
        if (find.rows.length > 0) return mapCommunity(find.rows[0]);

        const create = await pool.query(
            `INSERT INTO communities (name, description, community_type, created_by)
             VALUES ($1, $2, 'open', $3)
             RETURNING ${COMMUNITY_COLS}`.replace(/c\./g, ''),
            [name, `Community for ${name}`, userId]
        );
        return mapCommunity(create.rows[0]);
    }

    // ── Get by ID ─────────────────────────────────────────────────────────────
    async getCommunityById(communityId: string, viewerId?: string): Promise<Community | null> {
        const uid = viewerId ?? '00000000-0000-0000-0000-000000000000';
        const result = await pool.query(
            `SELECT ${COMMUNITY_COLS},
                    (SELECT EXISTS(SELECT 1 FROM community_likes WHERE community_id = c.id AND user_id = $2)) AS "likedByMe",
                    (SELECT EXISTS(SELECT 1 FROM community_members WHERE community_id = c.id AND user_id = $2)) AS "isMember",
                    (SELECT COUNT(*) FROM community_members WHERE community_id = c.id) AS "memberCount"
             FROM communities c WHERE c.id = $1`,
            [communityId, uid]
        );
        return result.rows.length > 0 ? mapCommunity(result.rows[0]) : null;
    }

    // ── Get user's joined communities ─────────────────────────────────────────
    async getUserCommunities(userId: string): Promise<Community[]> {
        const result = await pool.query(
            `SELECT ${COMMUNITY_COLS},
                    TRUE AS "isMember",
                    (SELECT EXISTS(SELECT 1 FROM community_likes WHERE community_id = c.id AND user_id = $1)) AS "likedByMe",
                    (SELECT COUNT(*) FROM community_members WHERE community_id = c.id) AS "memberCount",
                    cm.notifications_on AS "notificationsOn",
                    cm.hometown_notify  AS "hometownNotify",
                    cm.is_hidden        AS "isHidden",
                    cm.hide_map_pins    AS "hideMapPins"
             FROM communities c
             JOIN community_members cm ON c.id = cm.community_id AND cm.user_id = $1
             WHERE cm.user_id = $1
             ORDER BY c.updated_at DESC`,
            [userId]
        );
        return result.rows.map(mapCommunity);
    }

    // ── Discover communities near a location (spec 3.5 empty state) ───────────
    async getCommunitiesNear(lat: number, lon: number, radiusMeters = 5000, userId?: string): Promise<Community[]> {
        const uid = userId ?? '00000000-0000-0000-0000-000000000000';
        const result = await pool.query(
            `SELECT DISTINCT ${COMMUNITY_COLS},
                    (SELECT EXISTS(SELECT 1 FROM community_likes WHERE community_id = c.id AND user_id = $4)) AS "likedByMe",
                    (SELECT EXISTS(SELECT 1 FROM community_members WHERE community_id = c.id AND user_id = $4)) AS "isMember",
                    (SELECT COUNT(*) FROM community_members WHERE community_id = c.id) AS "memberCount"
             FROM communities c
             JOIN pins p ON p.community_id = c.id
             WHERE p.is_deleted = FALSE
               AND p.is_private = FALSE
               AND (c.community_type = 'open' OR c.community_type = 'invite_only')
               AND ST_DWithin(
                     p.location::geography,
                     ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
                     $3
                   )
             ORDER BY c.like_count DESC
             LIMIT 20`,
            [lat, lon, radiusMeters, uid]
        );
        return result.rows.map(mapCommunity);
    }

    // ── Join / Leave ──────────────────────────────────────────────────────────
    async joinCommunity(communityId: string, userId: string): Promise<void> {
        await pool.query(
            `INSERT INTO community_members (community_id, user_id)
             VALUES ($1, $2)
             ON CONFLICT (community_id, user_id) DO NOTHING`,
            [communityId, userId]
        );
    }

    async leaveCommunity(communityId: string, userId: string): Promise<void> {
        await pool.query(
            'DELETE FROM community_members WHERE community_id = $1 AND user_id = $2',
            [communityId, userId]
        );
    }

    // ── Like / Unlike (spec 3.4) ──────────────────────────────────────────────
    async likeCommunity(communityId: string, userId: string): Promise<{ likeCount: number }> {
        await pool.query(
            `INSERT INTO community_likes (community_id, user_id)
             VALUES ($1, $2)
             ON CONFLICT DO NOTHING`,
            [communityId, userId]
        );
        const res = await pool.query(
            `UPDATE communities SET like_count = (
               SELECT COUNT(*) FROM community_likes WHERE community_id = $1
             ) WHERE id = $1 RETURNING like_count AS "likeCount"`,
            [communityId]
        );
        return { likeCount: Number(res.rows[0]?.likeCount ?? 0) };
    }

    async unlikeCommunity(communityId: string, userId: string): Promise<{ likeCount: number }> {
        await pool.query(
            'DELETE FROM community_likes WHERE community_id = $1 AND user_id = $2',
            [communityId, userId]
        );
        const res = await pool.query(
            `UPDATE communities SET like_count = (
               SELECT COUNT(*) FROM community_likes WHERE community_id = $1
             ) WHERE id = $1 RETURNING like_count AS "likeCount"`,
            [communityId]
        );
        return { likeCount: Number(res.rows[0]?.likeCount ?? 0) };
    }

    // ── Per-member settings (spec 3.3 + 3.4) ─────────────────────────────────
    async updateMemberSettings(
        communityId: string,
        userId: string,
        settings: UpdateMemberSettingsDTO
    ): Promise<void> {
        const fields: string[] = [];
        const vals: any[] = [];
        let n = 1;
        if (settings.notificationsOn !== undefined) { fields.push(`notifications_on = $${n++}`); vals.push(settings.notificationsOn); }
        if (settings.hometownNotify !== undefined)  { fields.push(`hometown_notify = $${n++}`);  vals.push(settings.hometownNotify); }
        if (settings.isHidden !== undefined)         { fields.push(`is_hidden = $${n++}`);        vals.push(settings.isHidden); }
        if (settings.hideMapPins !== undefined)      { fields.push(`hide_map_pins = $${n++}`);    vals.push(settings.hideMapPins); }
        if (fields.length === 0) return;
        vals.push(communityId, userId);
        await pool.query(
            `UPDATE community_members SET ${fields.join(', ')}
             WHERE community_id = $${n} AND user_id = $${n + 1}`,
            vals
        );
    }

    // ── 3-stage notification filter check (spec 3.3) ──────────────────────────
    async shouldNotifyMember(
        communityId: string,
        memberId: string,
        pinLat: number,
        pinLon: number
    ): Promise<boolean> {
        const res = await pool.query(
            `SELECT notifications_on, hometown_notify
             FROM community_members
             WHERE community_id = $1 AND user_id = $2`,
            [communityId, memberId]
        );
        if (res.rows.length === 0) return false;
        const { notifications_on, hometown_notify } = res.rows[0];

        // Step 1: notifications OFF → never notify
        if (!notifications_on) return false;

        // Steps 2 & 3 rely on the user's current location, which we don't have server-side.
        // We emit the notification to the client; the client applies step 2/3 via local filter.
        // Return true here so the socket event is sent; Flutter will filter by distance.
        return true;
    }

    // ── Invite links (spec 3.2) ───────────────────────────────────────────────
    async createInviteLink(communityId: string, createdBy: string): Promise<CommunityInvite> {
        const code = crypto.randomBytes(12).toString('hex'); // 24-char hex code
        const res = await pool.query(
            `INSERT INTO community_invites (community_id, code, created_by)
             VALUES ($1, $2, $3)
             RETURNING id, community_id AS "communityId", code, created_by AS "createdBy",
                       expires_at AS "expiresAt", use_count AS "useCount", created_at AS "createdAt"`,
            [communityId, code, createdBy]
        );
        return res.rows[0];
    }

    async joinByInviteCode(code: string, userId: string): Promise<Community> {
        const inv = await pool.query(
            `SELECT ci.community_id, ci.expires_at
             FROM community_invites ci
             WHERE ci.code = $1`,
            [code]
        );
        if (inv.rows.length === 0) throw { statusCode: 404, message: 'Invite not found' };
        const { community_id, expires_at } = inv.rows[0];
        if (new Date(expires_at) < new Date()) throw { statusCode: 410, message: 'Invite expired' };

        await this.joinCommunity(community_id, userId);
        // Increment use count
        await pool.query('UPDATE community_invites SET use_count = use_count + 1 WHERE code = $1', [code]);

        const community = await this.getCommunityById(community_id, userId);
        if (!community) throw { statusCode: 404, message: 'Community not found' };
        return community;
    }

    // ── Community feed (spec 3.1) ─────────────────────────────────────────────
    // Returns pins linked to this community, sorted by max(created_at, chat_last_at) DESC
    async getCommunityFeed(
        communityId: string,
        limit = 30,
        offset = 0
    ): Promise<CommunityFeedItem[]> {
        const res = await pool.query(
            `SELECT
               p.id AS "pinId",
               p.title,
               p.directions,
               p.type AS "pinType",
               p.pin_category AS "pinCategory",
               p.created_by AS "createdBy",
               ST_Y(p.location::geometry) AS lat,
               ST_X(p.location::geometry) AS lon,
               p.like_count AS "likeCount",
               p.external_link AS "externalLink",
               p.chat_enabled AS "chatEnabled",
               p.created_at AS "createdAt",
               p.chat_last_at AS "chatLastAt",
               GREATEST(p.created_at, COALESCE(p.chat_last_at, p.created_at)) AS "feedUpdatedAt"
             FROM pins p
             WHERE p.community_id = $1
               AND p.is_deleted = FALSE
             ORDER BY "feedUpdatedAt" DESC
             LIMIT $2 OFFSET $3`,
            [communityId, limit, offset]
        );
        return res.rows;
    }

    // ── Update chat_last_at on a pin when a community chat message is sent ────
    async touchPinChatActivity(pinId: string): Promise<void> {
        await pool.query(
            `UPDATE pins SET chat_last_at = NOW(), updated_at = NOW() WHERE id = $1`,
            [pinId]
        );
    }

    // ── Link a pin to a community (called at pin creation) ────────────────────
    async linkPinToCommunity(pinId: string, communityId: string): Promise<void> {
        await pool.query(
            `UPDATE pins SET community_id = $1 WHERE id = $2`,
            [communityId, pinId]
        );
    }

    // ── Messages ──────────────────────────────────────────────────────────────
    async postMessage(communityId: string, userId: string, data: PostMessageDTO): Promise<CommunityMessage> {
        const result = await pool.query(
            `INSERT INTO community_messages (community_id, user_id, content, image_url)
             VALUES ($1, $2, $3, $4)
             RETURNING id, community_id AS "communityId", user_id AS "userId",
                       content, image_url AS "imageUrl", reactions, created_at AS "createdAt"`,
            [communityId, userId, data.content, data.imageUrl]
        );
        return result.rows[0];
    }

    async toggleReaction(messageId: string, userId: string, emoji: string): Promise<void> {
        const result = await pool.query(
            'SELECT reactions FROM community_messages WHERE id = $1',
            [messageId]
        );
        if (result.rows.length === 0) throw new Error('Message not found');
        const reactions = result.rows[0].reactions || {};
        if (!reactions[emoji]) reactions[emoji] = [];
        const idx = reactions[emoji].indexOf(userId);
        if (idx > -1) {
            reactions[emoji].splice(idx, 1);
            if (reactions[emoji].length === 0) delete reactions[emoji];
        } else {
            reactions[emoji].push(userId);
        }
        await pool.query('UPDATE community_messages SET reactions = $1 WHERE id = $2',
            [JSON.stringify(reactions), messageId]);
    }

    async getCommunityMessages(communityId: string, limit = 50, offset = 0): Promise<CommunityMessage[]> {
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

    async isMember(communityId: string, userId: string): Promise<boolean> {
        const res = await pool.query(
            'SELECT 1 FROM community_members WHERE community_id = $1 AND user_id = $2',
            [communityId, userId]
        );
        return res.rows.length > 0;
    }
}

export const communitiesService = new CommunitiesService();

