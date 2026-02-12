import { pool } from '../../config/database.js';
import { redisClient, getRedisStatus } from '../../config/redis.js';
import { encodeGeohash } from '../../utils/geohash.js';

const LIFECYCLE_INTERVAL_MS = 60_000; // Check every 60 seconds
const LIKE_THRESHOLD = 3;             // 3 likes → extend life
const DISLIKE_THRESHOLD = 3;          // 3 dislikes → delete
const EXTENSION_HOURS = 24;           // +24 hours per extension
const GEOHASH_PRECISION = parseInt(process.env.GEOHASH_PRECISION || '7');

/**
 * Pin Lifecycle Worker
 * 
 * Runs every 60 seconds and enforces:
 * 1. IF likes >= 3 AND not yet extended → expires_at += 24h
 * 2. IF likes >= 6 AND extended once   → expires_at += 24h (second tier)
 * 3. IF dislikes >= 3                  → mark deleted
 * 4. IF now > expires_at               → cleanup from Redis
 */
export function startLifecycleWorker(): void {
    console.log('♻️  Lifecycle Worker started (interval: 60s)');

    setInterval(async () => {
        try {
            await processLifecycle();
        } catch (error) {
            console.error('❌ Lifecycle Worker error:', error);
        }
    }, LIFECYCLE_INTERVAL_MS);

    // Run once immediately on startup
    processLifecycle().catch((err) => {
        console.error('❌ Initial lifecycle run failed:', err);
    });
}

async function processLifecycle(): Promise<void> {
    const client = await pool.connect();

    try {
        // ===== STEP 1: Extend life for well-liked pins =====
        // Pins with >= 3 likes that haven't been extended yet
        const extendResult = await client.query(`
            UPDATE pins 
            SET 
                expires_at = expires_at + INTERVAL '${EXTENSION_HOURS} hours',
                life_extended_count = life_extended_count + 1,
                updated_at = NOW()
            WHERE is_deleted = FALSE 
                AND expires_at > NOW()
                AND like_count >= $1
                AND life_extended_count < FLOOR(like_count::float / $1)
            RETURNING id, title, life_extended_count, expires_at
        `, [LIKE_THRESHOLD]);

        if (extendResult.rows.length > 0) {
            console.log(`✅ Extended life for ${extendResult.rows.length} pins:`);
            for (const pin of extendResult.rows) {
                console.log(`   📌 "${pin.title}" → extended ${pin.life_extended_count}x, expires: ${pin.expires_at}`);
            }
        }

        // ===== STEP 2: Delete heavily-disliked pins =====
        const deleteResult = await client.query(`
            UPDATE pins 
            SET is_deleted = TRUE, updated_at = NOW()
            WHERE is_deleted = FALSE 
                AND dislike_count >= $1
            RETURNING id, title, 
                ST_Y(location::geometry) as lat,
                ST_X(location::geometry) as lon
        `, [DISLIKE_THRESHOLD]);

        if (deleteResult.rows.length > 0) {
            console.log(`🗑️  Deleted ${deleteResult.rows.length} disliked pins:`);
            for (const pin of deleteResult.rows) {
                console.log(`   ❌ "${pin.title}"`);
                // Remove from Redis geohash index
                await removeFromRedis(pin.lat, pin.lon, pin.id);
            }
        }

        // ===== STEP 3: Cleanup expired pins from Redis =====
        const expiredResult = await client.query(`
            UPDATE pins 
            SET is_deleted = TRUE, updated_at = NOW()
            WHERE is_deleted = FALSE 
                AND expires_at <= NOW()
            RETURNING id, title,
                ST_Y(location::geometry) as lat,
                ST_X(location::geometry) as lon
        `);

        if (expiredResult.rows.length > 0) {
            console.log(`⏰ Expired ${expiredResult.rows.length} pins:`);
            for (const pin of expiredResult.rows) {
                console.log(`   ⌛ "${pin.title}"`);
                await removeFromRedis(pin.lat, pin.lon, pin.id);
            }
        }
    } finally {
        client.release();
    }
}

/**
 * Remove a pin from its Redis geohash set
 */
async function removeFromRedis(lat: number, lon: number, pinId: string): Promise<void> {
    if (!getRedisStatus()) {
        return; // Redis unavailable, skip cache removal
    }

    try {
        const geohash = encodeGeohash(lat, lon, GEOHASH_PRECISION);
        await redisClient.sRem(`geo:${geohash}`, pinId);
    } catch (error) {
        console.error(`Failed to remove pin ${pinId} from Redis:`, error);
    }
}
