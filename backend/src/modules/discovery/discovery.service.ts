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
            console.log(`\n📡 HEARTBEAT RECEIVED`);
            console.log(`👤 User: ${userId}`);
            console.log(`📍 Position: (${lat}, ${lon})`);
            
            // Direct PostgreSQL query with PostGIS
            const discoveredPins = await this.queryNearbyPinsPostGIS(lat, lon, userId);

            // Log discoveries for analytics
            for (const pin of discoveredPins) {
                await this.logDiscovery(userId, pin.id, pin.distance);
            }

            console.log(`✅ Discovery complete: Found ${discoveredPins.length} pins for user ${userId}\n`);

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
     * FIXED: Include community pins (no expiration) AND normal active pins
     * SIMPLIFIED: Removed user_pin_interactions join for reliability
     */
    private async queryNearbyPinsPostGIS(
        userLat: number,
        userLon: number,
        userId: string
    ): Promise<DiscoveredPin[]> {
        const currentTime = new Date().toTimeString().slice(0, 5); // "HH:MM"

        console.log(`🔍 Querying pins within ${DISCOVERY_RADIUS_METERS}m at (${userLat}, ${userLon})...`);

        try {
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
        ) AS distance
      FROM pins p
      WHERE p.is_deleted = FALSE
        AND (
          p.expires_at IS NULL          -- Community pins never expire
          OR p.expires_at > NOW()        -- Normal pins still active
        )
        AND (
          p.visible_from IS NULL 
          OR p.visible_to IS NULL 
          OR (CAST($3 AS TIME) >= p.visible_from AND CAST($3 AS TIME) <= p.visible_to)
        )
        AND ST_DWithin(
          p.location::geography,
          ST_MakePoint($1, $2)::geography,
          $4
        )
      ORDER BY distance ASC
      `,
                [userLon, userLat, currentTime, DISCOVERY_RADIUS_METERS]
            );

            console.log(`📊 Database returned ${result.rows.length} pins`);
            
            result.rows.forEach((row, i) => {
                console.log(`  📍 ${i+1}. "${row.title}" (${row.pin_category}) - ${Math.round(row.distance)}m - by: ${row.created_by}`);
            });

            return result.rows.map((row) => {
                const likeCount = parseInt(row.likeCount) || 0;
                const reportCount = parseInt(row.reportCount) || 0;

                // Global Visibility Rule: Deprioritize if Likes < (Reports * 0.5)
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
                    isHidden: false, // Simplified - no muting for now
                    isDeprioritized: isDeprioritized,
                };
            });
        } catch (error) {
            console.error('❌ Discovery query failed:', error);
            throw error;
        }
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
            if ((result.rowCount || 0) > 0) {
                await pool.query(
                    `INSERT INTO user_activities (user_id, pin_id, activity_type, metadata)
           VALUES ($1, $2, 'visited', $3)`,
                    [userId, pinId, JSON.stringify({ distance: Math.round(distance) })]
                );
                console.log(`  ✨ New discovery logged: Pin ${pinId} for user ${userId}`);
            }
        } catch (error) {
            console.error('Failed to log discovery:', error);
        }
    }
}
