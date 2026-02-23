import { pool } from '../../config/database.js';
import { redisClient, getRedisStatus } from '../../config/redis.js';
import { encodeGeohash } from '../../utils/geohash.js';

const LIFECYCLE_INTERVAL_MS = 60_000; // Check every 60 seconds
const LIKE_THRESHOLD = 3;             // 3 likes → extend life
const DISLIKE_THRESHOLD = 3;          // 3 dislikes → delete
const EXTENSION_HOURS = 24;           // +24 hours per extension
const GEOHASH_PRECISION = parseInt(process.env.GEOHASH_PRECISION || '7');

/**
 * Ensure the pins_details_length constraint is the relaxed version (<= 2000).
 * Called once at startup and at the top of every lifecycle run so that even
 * if Render somehow still has the old strict constraint (300-500 chars) from
 * a previous deploy, it gets replaced before any UPDATE touches the table.
 */
export async function repairDetailsConstraint(): Promise<void> {
    try {
        // Fix details constraint (old rule: 300–500 chars → new: any length up to 2000)
        await pool.query(`ALTER TABLE pins DROP CONSTRAINT IF EXISTS pins_details_length`);
        await pool.query(`
            ALTER TABLE pins ADD CONSTRAINT pins_details_length
                CHECK (
                    details IS NULL
                    OR char_length(details) = 0
                    OR char_length(details) <= 2000
                ) NOT VALID
        `);

        // Fix directions constraint (old rule: 50–100 chars → new: 5–500)
        await pool.query(`ALTER TABLE pins DROP CONSTRAINT IF EXISTS pins_directions_length`);
        await pool.query(`
            ALTER TABLE pins ADD CONSTRAINT pins_directions_length
                CHECK (char_length(directions) BETWEEN 5 AND 500)
                NOT VALID
        `);
    } catch (err: any) {
        // Log explicitly — if this keeps firing, check DB user permissions
        console.error('🚨 repairDetailsConstraint FAILED (constraints may still be strict):', err?.message ?? err);
        console.error('   Full error:', JSON.stringify({ code: err?.code, detail: err?.detail, hint: err?.hint }));
    }
}

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
    // Always fix the details constraint first so old strict rules never
    // block our UPDATE statements (PostgreSQL re-validates ALL constraints
    // on a row even when only expires_at / updated_at changes).
    await repairDetailsConstraint();

    const client = await pool.connect();

    try {
        // ===== STEP 1: Extend life for well-liked pins =====
        try {
            const extendResult = await client.query(`
                UPDATE pins 
                SET 
                    expires_at = expires_at + INTERVAL '${EXTENSION_HOURS} hours',
                    life_extended_count = life_extended_count + 1,
                    updated_at = NOW(),
                    details = CASE
                        WHEN details IS NOT NULL AND char_length(details) > 500
                            THEN LEFT(details, 500)
                        ELSE details
                    END,
                    directions = CASE
                        WHEN directions IS NOT NULL AND char_length(directions) > 500
                            THEN LEFT(directions, 500)
                        ELSE directions
                    END
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
        } catch (err) {
            console.error('❌ Lifecycle STEP 1 (extend) failed:', err);
        }

        // ===== STEP 2: Delete heavily-disliked pins =====
        try {
            const deleteResult = await client.query(`
                UPDATE pins 
                SET is_deleted = TRUE, updated_at = NOW(),
                    details = CASE
                        WHEN details IS NOT NULL AND char_length(details) > 500
                            THEN LEFT(details, 500)
                        ELSE details
                    END,
                    directions = CASE
                        WHEN directions IS NOT NULL AND char_length(directions) > 500
                            THEN LEFT(directions, 500)
                        ELSE directions
                    END
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
                    await removeFromRedis(pin.lat, pin.lon, pin.id);
                }
            }
        } catch (err) {
            console.error('❌ Lifecycle STEP 2 (delete disliked) failed:', err);
        }

        // ===== STEP 3: Cleanup expired pins from Redis =====
        try {
            const expiredResult = await client.query(`
                UPDATE pins 
                SET is_deleted = TRUE, updated_at = NOW(),
                    details = CASE
                        WHEN details IS NOT NULL AND char_length(details) > 500
                            THEN LEFT(details, 500)
                        ELSE details
                    END,
                    directions = CASE
                        WHEN directions IS NOT NULL AND char_length(directions) > 500
                            THEN LEFT(directions, 500)
                        ELSE directions
                    END
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
        } catch (err) {
            console.error('❌ Lifecycle STEP 3 (expire) failed:', err);
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
