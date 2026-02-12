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
        // Step 1: Validate community pin permissions
        if (data.pinCategory === 'community') {
            const userResult = await pool.query(
                'SELECT role FROM users WHERE id = $1',
                [userId]
            );

            if (userResult.rows.length === 0 || userResult.rows[0].role !== 'community') {
                throw new Error('Only community users can create community pins');
            }
        }

        // Step 2: Calculate expiration
        const expiresAt = new Date(Date.now() + DEFAULT_PIN_TTL_HOURS * 60 * 60 * 1000);

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
     * Get user's created pins
     */
    async getUserPins(userId: string): Promise<PinResponse[]> {
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
}
