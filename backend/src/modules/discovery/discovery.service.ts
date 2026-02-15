import { pool } from '../../config/database.js';
import type { DiscoveredPin, DiscoveryResponse } from './discovery.types.js';

const DISCOVERY_RADIUS_METERS = parseInt(process.env.DISCOVERY_RADIUS_METERS || '50');
const GEOHASH_PRECISION = parseInt(process.env.GEOHASH_PRECISION || '7');

export class DiscoveryService {
    /**
     * Simplified Discovery Algorithm (PostgreSQL-only, No Redis)
     * Steps:
     * 1. Receive GPS heartbeat
     * 2. Query PostgreSQL directly with PostGIS ST_Distance
     * 3. Return all active pins within 50m
     * 4. Log discoveries
     */
    async processHeartbeat(
        userId: string,
        lat: number,
        lon: number
    ): Promise<DiscoveryResponse> {
        try {
            // Direct PostgreSQL query with PostGIS
            const discoveredPins = await this.queryNearbyPinsPostGIS(lat, lon, userId);

            // Log discoveries for analytics
            for (const pin of discoveredPins) {
                await this.logDiscovery(userId, pin.id, pin.distance);
            }

            console.log(`✅ Discovery: User ${userId} found ${discoveredPins.length} pins at (${lat}, ${lon})`);

            return {
                discovered: discoveredPins,
                count: discoveredPins.length,
                timestamp: new Date(),
            };
        } catch (error) {
            console.error('❌ Discovery error:', error);
            throw error;
        }
    }

    /**
     * Direct PostGIS query for nearby pins
     * Simplified - no Redis, no geohash, just pure distance calculation
     */
    private async queryNearbyPinsPostGIS(
        userLat: number,
        userLon: number,
        userId: string
    ): Promise<DiscoveredPin[]> {
        const currentTime = new Date().toTimeString().slice(0, 5); // "HH:MM"

        const result = await pool.query(
            `
      SELECT 
        p.id,
        p.title,
        p.directions,
        p.details,
        p.type,
        p.pin_category,
        p.attribute_id,
        p.created_by,
        p.like_count AS "likeCount",
        p.dislike_count AS "reportCount",
        ST_Y(p.location::geometry) AS lat,
        ST_X(p.location::geometry) AS lon,
        ST_Distance(
          p.location::geography,
          ST_MakePoint($1, $2)::geography
        ) AS distance,
        COALESCE(upi.is_muted, FALSE) AS "isHidden"
      FROM pins p
      LEFT JOIN user_pin_interactions upi ON p.id = upi.pin_id AND upi.user_id = $5
      WHERE p.expires_at > NOW()
        AND (
          p.visible_from IS NULL 
          OR p.visible_to IS NULL 
          OR (CAST($3 AS TIME) >= p.visible_from AND CAST($3 AS TIME) <= p.visible_to)
        )
        AND ST_Distance(
          p.location::geography,
          ST_MakePoint($1, $2)::geography
        ) < $4
      ORDER BY distance ASC
      `,
            [userLon, userLat, currentTime, DISCOVERY_RADIUS_METERS, userId]
        );

        return result.rows.map((row) => {
            const likeCount = parseInt(row.likeCount) || 0;
            const reportCount = parseInt(row.reportCount) || 0;

            // Global Visibility Rule: Deprioritize if Likes < (Reports * 0.5)
            // (Only if there are actual reports)
            const isDeprioritized = reportCount > 0 && likeCount < (reportCount * 0.5);

            return {
                id: row.id,
                title: row.title,
                directions: row.directions,
                details: row.details,
                lat: row.lat,
                lon: row.lon,
                distance: Math.round(row.distance),
                type: row.type,
                pinCategory: row.pin_category,
                attributeId: row.attribute_id,
                createdBy: row.created_by,
                isHidden: row.isHidden,
                isDeprioritized: isDeprioritized,
            };
        });
    }


    /**
     * Log discovery for analytics
     * AND log to user_activities for Diary "Passed Pins"
     */
    private async logDiscovery(
        userId: string,
        pinId: string,
        distance: number
    ): Promise<void> {
        try {
            // 1. Log to discoveries (Unique per user+pin)
            const result = await pool.query(
                `INSERT INTO discoveries (user_id, pin_id, distance_meters)
         VALUES ($1, $2, $3)
         ON CONFLICT DO NOTHING`,
                [userId, pinId, Math.round(distance)]
            );

            // 2. If new discovery, log to user_activities (Diary)
            // result.rowCount > 0 means a row was inserted (it was new)
            if ((result.rowCount || 0) > 0) {
                await pool.query(
                    `INSERT INTO user_activities (user_id, pin_id, activity_type, metadata)
           VALUES ($1, $2, 'visited', $3)`,
                    [userId, pinId, JSON.stringify({ distance: Math.round(distance) })]
                );
            }
        } catch (error) {
            console.error('Failed to log discovery:', error);
            // Non-critical, continue
        }
    }
}
