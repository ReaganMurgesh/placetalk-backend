import { pool } from '../../config/database.js';
import { redisClient, getRedisStatus } from '../../config/redis.js';
import { encodeGeohash, getNeighbors } from '../../utils/geohash.js';
import type { DiscoveredPin, DiscoveryResponse } from './discovery.types.js';

const DISCOVERY_RADIUS_METERS = parseInt(process.env.DISCOVERY_RADIUS_METERS || '50');
const GEOHASH_PRECISION = parseInt(process.env.GEOHASH_PRECISION || '7');

export class DiscoveryService {
    /**
     * Core Discovery Algorithm: Heartbeat → Notification
     * Steps:
     * A. Receive GPS heartbeat
     * B. Encode to geohash (coarse filtering)
     * C. Query Redis for candidate pins
     * D. PostGIS precise filtering (ST_Distance_Sphere < 50m)
     * E. Log discovery analytics
     * F. Return discovered pins
     */
    async processHeartbeat(
        userId: string,
        lat: number,
        lon: number
    ): Promise<DiscoveryResponse> {
        // Step B: Convert GPS to geohash
        const centerGeohash = encodeGeohash(lat, lon, GEOHASH_PRECISION);
        const searchGeohashes = getNeighbors(centerGeohash); // Include 8 neighbors

        // Step C: Query Redis for candidate pin IDs in these geohash cells
        const candidatePinIds = await this.getCandidatePinsFromRedis(searchGeohashes);

        if (candidatePinIds.length === 0) {
            return {
                discovered: [],
                count: 0,
                timestamp: new Date(),
            };
        }

        // Step D: Precise filtering with PostGIS
        const discoveredPins = await this.preciseDistanceFilter(lat, lon, candidatePinIds);

        // Step E: Log discoveries for analytics
        for (const pin of discoveredPins) {
            await this.logDiscovery(userId, pin.id, pin.distance);
        }

        return {
            discovered: discoveredPins,
            count: discoveredPins.length,
            timestamp: new Date(),
        };
    }

    /**
     * Query Redis for pins in geohash cells
     * Uses Redis sorted sets with geohash as key
     */
    private async getCandidatePinsFromRedis(geohashes: string[]): Promise<string[]> {
        // If Redis unavailable, return empty (will fall back to DB query)
        if (!getRedisStatus()) {
            return [];
        }

        const pinIds: Set<string> = new Set();

        for (const geohash of geohashes) {
            try {
                const pins = await redisClient.sMembers(`geo:${geohash}`);
                pins.forEach((pinId) => pinIds.add(pinId));
            } catch (error) {
                console.error(`Redis error for geohash ${geohash}:`, error);
            }
        }

        return Array.from(pinIds);
    }

    /**
     * Precise distance filtering using PostGIS ST_Distance_Sphere
     * Only returns pins within DISCOVERY_RADIUS_METERS
     */
    private async preciseDistanceFilter(
        userLat: number,
        userLon: number,
        candidatePinIds: string[]
    ): Promise<DiscoveredPin[]> {
        if (candidatePinIds.length === 0) return [];

        // Check time window if set
        const currentTime = new Date().toTimeString().slice(0, 5); // "HH:MM"

        const result = await pool.query(
            `
      SELECT 
        id,
        title,
        directions,
        details,
        type,
        pin_category,
        attribute_id,
        created_by,
        ST_Distance(
          location::geography,
          ST_MakePoint($1, $2)::geography
        ) AS distance
      FROM pins
      WHERE id = ANY($3)
        AND is_deleted = FALSE
        AND expires_at > NOW()
        AND (
          visible_from IS NULL 
          OR visible_to IS NULL 
          OR (CAST($4 AS TIME) >= visible_from AND CAST($4 AS TIME) <= visible_to)
        )
        AND ST_Distance(
          location::geography,
          ST_MakePoint($1, $2)::geography
        ) < $5
      ORDER BY distance ASC
      `,
            [userLon, userLat, candidatePinIds, currentTime, DISCOVERY_RADIUS_METERS]
        );

        return result.rows.map((row) => ({
            id: row.id,
            title: row.title,
            directions: row.directions,
            details: row.details,
            distance: Math.round(row.distance),
            type: row.type,
            pinCategory: row.pin_category,
            attributeId: row.attribute_id,
            createdBy: row.created_by,
        }));
    }

    /**
     * Log discovery for analytics
     */
    private async logDiscovery(
        userId: string,
        pinId: string,
        distance: number
    ): Promise<void> {
        try {
            await pool.query(
                `INSERT INTO discoveries (user_id, pin_id, distance_meters)
         VALUES ($1, $2, $3)
         ON CONFLICT DO NOTHING`,
                [userId, pinId, Math.round(distance)]
            );
        } catch (error) {
            console.error('Failed to log discovery:', error);
            // Non-critical, continue
        }
    }
}
