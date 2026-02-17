import { pool } from '../../config/database.js';
import { redisClient, getRedisStatus } from '../../config/redis.js';
import { encodeGeohash } from '../../utils/geohash.js';
import type { CreatePinDTO, PinResponse } from './pins.types.js';

const DEFAULT_PIN_TTL_HOURS = parseInt(process.env.DEFAULT_PIN_TTL_HOURS || '72');
const GEOHASH_PRECISION = parseInt(process.env.GEOHASH_PRECISION || '7');

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
        
        // Step 1: Validate community pin permissions (DISABLED for MVP)
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
        // Community pins do not expire (or set to 100 years)
        // Normal pins expire in 72 hours
        let expiresAt: Date | null = null;

        if (data.pinCategory !== 'community') {
            expiresAt = new Date(Date.now() + DEFAULT_PIN_TTL_HOURS * 60 * 60 * 1000);
        }

        // Step 3: Write to PostgreSQL (vault)
        const result = await pool.query(
            `INSERT INTO pins (
        title, directions, details, location, type, pin_category,
        attribute_id, created_by, visible_from, visible_to, expires_at
      )
      VALUES ($1, $2, $3, ST_MakePoint($4, $5)::geography, $6, $7, $8, $9, $10, $11, $12)
      RETURNING 
        id, title, directions, details, type, pin_category, attribute_id,
        created_by, expires_at, like_count, dislike_count, created_at,
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
        };
    }

    /**
     * Get pin by ID
     */
    async getPinById(pinId: string): Promise<PinResponse | null> {
        const result = await pool.query(
            `SELECT 
        id, title, directions, details, type, pin_category, attribute_id,
        created_by, expires_at, like_count, dislike_count, created_at,
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
}
