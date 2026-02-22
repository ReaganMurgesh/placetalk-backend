import { pool } from '../../config/database.js';
import { redisClient, getRedisStatus } from '../../config/redis.js';
import { encodeGeohash } from '../../utils/geohash.js';
import type { CreatePinDTO, UpdatePinDTO, PinResponse } from './pins.types.js';

const DEFAULT_PIN_TTL_HOURS = parseInt(process.env.DEFAULT_PIN_TTL_HOURS || String(365 * 24)); // 1 year
const MAX_DAILY_PINS = parseInt(process.env.MAX_DAILY_PINS || '3');
const GEOHASH_PRECISION = parseInt(process.env.GEOHASH_PRECISION || '7');

// ── Text validation helper ───────────────────────────────────────────────
/**
 * Validates pin text fields and returns an error string or null.
 * Lengths: title ≤ 10 | directions 50–100 | details 0 or 300–500
 */
function validatePinText(data: {
    title?: string;
    directions?: string;
    details?: string | null;
}): string | null {
    if (data.title !== undefined) {
        if (data.title.trim().length === 0) return 'Title is required';
        if (data.title.length > 10) return 'Title must be 10 characters or fewer';
    }
    if (data.directions !== undefined) {
        if (data.directions.length < 50) return 'Directions must be at least 50 characters';
        if (data.directions.length > 100) return 'Directions must be 100 characters or fewer';
    }
    if (data.details !== undefined && data.details !== null && data.details.trim().length > 0) {
        if (data.details.length < 300) return 'Details must be at least 300 characters';
        if (data.details.length > 500) return 'Details must be 500 characters or fewer';
    }
    return null;
}

export class PinsService {
    /**
     * Create Pin Engine - Dual Write System
     * Steps:
     * 1. Validate user permissions
     * 2. Calculate expiration (72 hours default)
     * 3. Write to PostgreSQL (permanent vault)
     * 4. Write to Redis (discovery index)
     * 5. Set TTL in Redis (auto-cleanup)
     */
    async createPin(data: CreatePinDTO, userId: string): Promise<PinResponse> {
        console.log(`\n🆕 PIN CREATION STARTED`);
        console.log(`👤 User ID: ${userId}`);
        console.log(`📍 Location: (${data.lat}, ${data.lon})`);
        console.log(`📝 Title: ${data.title}`);
        console.log(`🏷️ Category: ${data.pinCategory}`);

        // Step 0: Validate text lengths (backend guardrail)
        const textErr = validatePinText({ title: data.title, directions: data.directions, details: data.details });
        if (textErr) throw Object.assign(new Error(textErr), { statusCode: 400 });

        // Step 0b: Fetch creator snapshot
        const creatorRow = await pool.query(
            'SELECT nickname, bio FROM users WHERE id = $1',
            [userId]
        );
        const creatorSnapshot = {
            nickname: creatorRow.rows[0]?.nickname ?? undefined,
            bio: creatorRow.rows[0]?.bio ?? undefined,
        };

        // Step 1a: Enforce 3-pins-per-day quota (spec 2.1)
        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);
        const quotaResult = await pool.query(
            `SELECT COUNT(*) AS cnt FROM pins
             WHERE created_by = $1 AND created_at >= $2 AND is_deleted = FALSE`,
            [userId, todayStart]
        );
        const todayCount = parseInt(quotaResult.rows[0].cnt, 10);
        if (todayCount >= MAX_DAILY_PINS) {
            throw Object.assign(
                new Error(`Daily limit reached: you can place up to ${MAX_DAILY_PINS} pins per day.`),
                { statusCode: 429 }
            );
        }
        // if (data.pinCategory === 'community') {
        //     const userResult = await pool.query(
        //         'SELECT role FROM users WHERE id = $1',
        //         [userId]
        //     );
        //
        //     if (userResult.rows.length === 0 || userResult.rows[0].role !== 'community') {
        //         throw new Error('Only community users can create community pins');
        //     }
        // }

        // Step 2: Calculate expiration
        // Community pins: null (no expiry, spec says "permanent")
        // Normal pins: expires_at = NOW() + 1 year (spec 2.1 default)
        //   If data.expiresAt is supplied, use it instead (future UI timer dial)
        let expiresAt: Date;

        if (data.pinCategory === 'community') {
            // Community pins: 100 years (essentially permanent)
            expiresAt = new Date(Date.now() + 100 * 365 * 24 * 60 * 60 * 1000);
        } else {
            // Normal pins: default 1 year; DEFAULT_PIN_TTL_HOURS is now 8760 (1 year)
            expiresAt = new Date(Date.now() + DEFAULT_PIN_TTL_HOURS * 60 * 60 * 1000);
        }

        // Step 3: Write to PostgreSQL (vault)
        const result = await pool.query(
            `INSERT INTO pins (
        title, directions, details, location, type, pin_category,
        attribute_id, created_by, visible_from, visible_to, expires_at,
        external_link, chat_enabled, is_private, creator_snapshot
      )
      VALUES ($1, $2, $3, ST_MakePoint($4, $5)::geography, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
      RETURNING 
        id, title, directions, details, type, pin_category, attribute_id,
        created_by, expires_at, like_count, dislike_count, created_at,
        external_link, chat_enabled, is_private, creator_snapshot,
        ST_Y(location::geometry) as lat,
        ST_X(location::geometry) as lon`,
            [
                data.title,
                data.directions,
                data.details,
                data.lon,
                data.lat,
                data.type,
                data.pinCategory,
                data.attributeId,
                userId,
                data.visibleFrom,
                data.visibleTo,
                expiresAt,
                data.externalLink ?? null,
                data.chatEnabled ?? false,
                data.isPrivate ?? false,
                JSON.stringify(creatorSnapshot),
            ]
        );

        const pin = result.rows[0];
        
        console.log(`\n✅ PIN CREATED SUCCESSFULLY`);
        console.log(`🔑 Pin ID: ${pin.id}`);
        console.log(`👤 Created By: ${pin.created_by}`);
        console.log(`📍 Coordinates: (${pin.lat}, ${pin.lon})`);
        console.log(`⏰ Expires At: ${pin.expires_at || 'NEVER (Community)'}`);
        console.log(`-------------------------------------------\n`);

        // Step 4: Write to Redis (discovery index) - Optional
        if (getRedisStatus()) {
            const geohash = encodeGeohash(data.lat, data.lon, GEOHASH_PRECISION);
            await redisClient.sAdd(`geo:${geohash}`, pin.id);

            // Step 5: Set TTL in Redis (auto-cleanup after expiration)
            const ttlSeconds = DEFAULT_PIN_TTL_HOURS * 60 * 60;
            await redisClient.expire(`geo:${geohash}`, ttlSeconds);
        }

        // Step 4a: Link community pin to its community (find-or-create by title) — spec 3
        if (data.pinCategory === 'community') {
            await this._autoLinkCommunity(pin.id, data.communityId, data.title, userId);
        }

        return {
            id: pin.id,
            title: pin.title,
            directions: pin.directions,
            details: pin.details,
            lat: pin.lat,
            lon: pin.lon,
            type: pin.type,
            pinCategory: pin.pin_category,
            attributeId: pin.attribute_id,
            createdBy: pin.created_by,
            expiresAt: pin.expires_at,
            likeCount: pin.like_count,
            dislikeCount: pin.dislike_count,
            createdAt: pin.created_at,
            externalLink: pin.external_link,
            chatEnabled: pin.chat_enabled ?? false,
            isPrivate: pin.is_private ?? false,
            communityId: data.communityId,
            creatorSnapshot: pin.creator_snapshot ?? {},
        };
    }

    // Auto-link a community pin to its community (spec 3 feed)
    private async _autoLinkCommunity(pinId: string, communityId: string | undefined, title: string, userId: string): Promise<void> {
        let cid = communityId;
        if (!cid) {
            const existing = await pool.query(`SELECT id FROM communities WHERE name = $1`, [title]);
            if (existing.rows.length > 0) {
                cid = existing.rows[0].id;
            } else {
                const created = await pool.query(
                    `INSERT INTO communities (name, description, community_type, created_by)
                     VALUES ($1, $2, 'open', $3) RETURNING id`,
                    [title, `Community for ${title}`, userId]
                );
                cid = created.rows[0].id;
                await pool.query(
                    `INSERT INTO community_members (community_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
                    [cid, userId]
                );
            }
        }
        await pool.query(`UPDATE pins SET community_id = $1 WHERE id = $2`, [cid, pinId]);
    }

    /**
     * Get pin by ID
     */
    async getPinById(pinId: string): Promise<PinResponse | null> {
        const result = await pool.query(
            `SELECT 
        id, title, directions, details, type, pin_category, attribute_id,
        created_by, expires_at, like_count, dislike_count, created_at,
        external_link, chat_enabled, is_private, creator_snapshot,
        ST_Y(location::geometry) as lat,
        ST_X(location::geometry) as lon
      FROM pins
      WHERE id = $1 AND is_deleted = FALSE`,
            [pinId]
        );

        if (result.rows.length === 0) {
            return null;
        }

        const pin = result.rows[0];
        return {
            id: pin.id,
            title: pin.title,
            directions: pin.directions,
            details: pin.details,
            lat: pin.lat,
            lon: pin.lon,
            type: pin.type,
            pinCategory: pin.pin_category,
            attributeId: pin.attribute_id,
            createdBy: pin.created_by,
            expiresAt: pin.expires_at,
            likeCount: pin.like_count,
            dislikeCount: pin.dislike_count,
            createdAt: pin.created_at,
            externalLink: pin.external_link,
            chatEnabled: pin.chat_enabled ?? false,
            isPrivate: pin.is_private ?? false,
            creatorSnapshot: pin.creator_snapshot ?? {},
        };
    }

    /**
     * Get user's created pins with proper isolation
     */
    async getUserPins(userId: string): Promise<PinResponse[]> {
        console.log(`📍 PinsService: Querying pins for user ${userId}`);
        
        const result = await pool.query(
            `SELECT 
        id, title, directions, details, type, pin_category, attribute_id,
        created_by, expires_at, like_count, dislike_count, created_at,
        external_link, chat_enabled, is_private, creator_snapshot,
        ST_Y(location::geometry) as lat,
        ST_X(location::geometry) as lon
      FROM pins
      WHERE created_by = $1 AND is_deleted = FALSE
      ORDER BY created_at DESC`,
            [userId]
        );

        console.log(`📍 PinsService: Database returned ${result.rows.length} pins for user ${userId}`);
        
        if (result.rows.length > 0) {
            console.log(`📍 PinsService: Sample pin data:`, {
                id: result.rows[0].id,
                title: result.rows[0].title,
                created_by: result.rows[0].created_by,
                created_at: result.rows[0].created_at
            });
        }

        return result.rows.map((pin) => ({
            id: pin.id,
            title: pin.title,
            directions: pin.directions,
            details: pin.details,
            lat: pin.lat,
            lon: pin.lon,
            type: pin.type,
            pinCategory: pin.pin_category,
            attributeId: pin.attribute_id,
            createdBy: pin.created_by,
            expiresAt: pin.expires_at,
            likeCount: pin.like_count,
            dislikeCount: pin.dislike_count,
            createdAt: pin.created_at,
            externalLink: pin.external_link,
            chatEnabled: pin.chat_enabled ?? false,
            isPrivate: pin.is_private ?? false,
            creatorSnapshot: pin.creator_snapshot ?? {},
        }));
    }

    /**
     * Toggle Pin Like/Dislike - Updates counts & tracks user interactions
     */
    async togglePinInteraction(userId: string, pinId: string, interactionType: 'like' | 'dislike') {
        const client = await pool.connect();
        
        try {
            await client.query('BEGIN');

            // Check if user already has an interaction with this pin
            const existingInteraction = await client.query(
                'SELECT interaction_type FROM interactions WHERE user_id = $1 AND pin_id = $2',
                [userId, pinId]
            );

            let action = '';
            
            if (existingInteraction.rows.length === 0) {
                // No existing interaction - add new one
                await client.query(
                    'INSERT INTO interactions (user_id, pin_id, interaction_type) VALUES ($1, $2, $3)',
                    [userId, pinId, interactionType]
                );
                
                // Update pin count
                const countField = interactionType === 'like' ? 'like_count' : 'dislike_count';
                await client.query(
                    `UPDATE pins SET ${countField} = ${countField} + 1 WHERE id = $1`,
                    [pinId]
                );
                
                action = 'added';
            } else {
                const existing = existingInteraction.rows[0].interaction_type;
                
                if (existing === interactionType) {
                    // Same interaction - remove it
                    await client.query(
                        'DELETE FROM interactions WHERE user_id = $1 AND pin_id = $2',
                        [userId, pinId]
                    );
                    
                    // Decrease count
                    const countField = interactionType === 'like' ? 'like_count' : 'dislike_count';
                    await client.query(
                        `UPDATE pins SET ${countField} = GREATEST(${countField} - 1, 0) WHERE id = $1`,
                        [pinId]
                    );
                    
                    action = 'removed';
                } else {
                    // Different interaction - switch it
                    await client.query(
                        'UPDATE interactions SET interaction_type = $3 WHERE user_id = $1 AND pin_id = $2',
                        [userId, pinId, interactionType]
                    );
                    
                    // Update both counts
                    const oldCountField = existing === 'like' ? 'like_count' : 'dislike_count';
                    const newCountField = interactionType === 'like' ? 'like_count' : 'dislike_count';
                    
                    await client.query(
                        `UPDATE pins SET 
                            ${oldCountField} = GREATEST(${oldCountField} - 1, 0),
                            ${newCountField} = ${newCountField} + 1 
                        WHERE id = $1`,
                        [pinId]
                    );
                    
                    action = 'switched';
                }
            }

            // Get updated counts
            const updatedPin = await client.query(
                'SELECT like_count, dislike_count FROM pins WHERE id = $1',
                [pinId]
            );

            await client.query('COMMIT');

            return {
                action,
                likeCount: updatedPin.rows[0].like_count,
                dislikeCount: updatedPin.rows[0].dislike_count
            };

        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }
    }

    // ── spec 2.4: permission helper ──────────────────────────────────────────

    /**
     * Returns true if the user can edit/delete the pin.
     * Rules:
     *   - is_b2b_partner → always allowed (remote)
     *   - otherwise → must own the pin AND be within 50 m
     */
    private async _canModify(
        userId: string,
        pin: { createdBy: string; lat: number; lon: number },
        userLat: number,
        userLon: number
    ): Promise<boolean> {
        // Check B2B partner flag
        const userRow = await pool.query(
            `SELECT is_b2b_partner FROM users WHERE id = $1`,
            [userId]
        );
        if (userRow.rows[0]?.is_b2b_partner) return true;

        // Must be owner
        if (pin.createdBy !== userId) return false;

        // Must be within 50 m
        const distRow = await pool.query(
            `SELECT ST_Distance(
               ST_MakePoint($1, $2)::geography,
               ST_MakePoint($3, $4)::geography
             ) AS dist`,
            [userLon, userLat, pin.lon, pin.lat]
        );
        const dist = parseFloat(distRow.rows[0]?.dist ?? '9999');
        return dist <= 50;
    }

    /**
     * Edit a pin's mutable fields (spec 2.4).
     * Throws 403 if the user lacks permission.
     */
    async updatePin(pinId: string, userId: string, data: UpdatePinDTO): Promise<PinResponse> {
        const existing = await this.getPinById(pinId);
        if (!existing) throw Object.assign(new Error('Pin not found'), { statusCode: 404 });

        const allowed = await this._canModify(userId, existing, data.userLat, data.userLon);
        if (!allowed) {
            throw Object.assign(
                new Error('You must be within 50 m of this pin to edit it.'),
                { statusCode: 403 }
            );
        }

        // Validate text lengths for any provided field
        const textErr = validatePinText({
            title: data.title,
            directions: data.directions,
            details: data.details,
        });
        if (textErr) throw Object.assign(new Error(textErr), { statusCode: 400 });

        const result = await pool.query(
            `UPDATE pins
             SET title       = COALESCE($1, title),
                 directions  = COALESCE($2, directions),
                 details     = COALESCE($3, details),
                 external_link = COALESCE($4, external_link),
                 chat_enabled = COALESCE($5, chat_enabled)
             WHERE id = $6 AND is_deleted = FALSE
             RETURNING
               id, title, directions, details, type, pin_category, attribute_id,
               created_by, expires_at, like_count, dislike_count, created_at,
               external_link, chat_enabled, is_private, creator_snapshot,
               ST_Y(location::geometry) as lat,
               ST_X(location::geometry) as lon`,
            [
                data.title ?? null,
                data.directions ?? null,
                data.details ?? null,
                data.externalLink ?? null,
                data.chatEnabled ?? null,
                pinId,
            ]
        );

        const pin = result.rows[0];
        return {
            id: pin.id, title: pin.title, directions: pin.directions,
            details: pin.details, lat: pin.lat, lon: pin.lon,
            type: pin.type, pinCategory: pin.pin_category,
            attributeId: pin.attribute_id, createdBy: pin.created_by,
            expiresAt: pin.expires_at, likeCount: pin.like_count,
            dislikeCount: pin.dislike_count, createdAt: pin.created_at,
            externalLink: pin.external_link, chatEnabled: pin.chat_enabled ?? false,
            isPrivate: pin.is_private ?? false,
            creatorSnapshot: pin.creator_snapshot ?? {},
        };
    }

    /**
     * Soft-delete a pin (spec 2.4).
     * Throws 403 if the user lacks permission.
     */
    async deletePin(pinId: string, userId: string, userLat: number, userLon: number): Promise<void> {
        const existing = await this.getPinById(pinId);
        if (!existing) throw Object.assign(new Error('Pin not found'), { statusCode: 404 });

        const allowed = await this._canModify(userId, existing, userLat, userLon);
        if (!allowed) {
            throw Object.assign(
                new Error('You must be within 50 m of this pin to delete it.'),
                { statusCode: 403 }
            );
        }

        await pool.query(
            `UPDATE pins SET is_deleted = TRUE WHERE id = $1`,
            [pinId]
        );
        console.log(`🗑️ Pin ${pinId} soft-deleted by ${userId}`);
    }
}
