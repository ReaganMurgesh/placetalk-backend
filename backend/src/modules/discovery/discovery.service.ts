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
            const discoveredPins = await this.queryNearbyPinsPostGIS(lat, lon);

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
        userLon: number
    ): Promise<DiscoveredPin[]> {
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
        ST_Y(location::geometry) AS lat,
        ST_X(location::geometry) AS lon,
        ST_Distance(
          location::geography,
          ST_MakePoint($1, $2)::geography
        ) AS distance
      FROM pins
      WHERE expires_at > NOW()
        AND (
          visible_from IS NULL 
          OR visible_to IS NULL 
          OR (CAST($3 AS TIME) >= visible_from AND CAST($3 AS TIME) <= visible_to)
        )
        AND ST_Distance(
          location::geography,
          ST_MakePoint($1, $2)::geography
        ) < $4
      ORDER BY distance ASC
      `,
            [userLon, userLat, currentTime, DISCOVERY_RADIUS_METERS]
        );

        return result.rows.map((row) => ({
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
