import 'dotenv/config';
import { createClient, RedisClientType } from 'redis';

// Redis is OPTIONAL - only create client if explicitly configured
let redisClient: RedisClientType | null = null;
let isRedisAvailable = false;

export async function connectRedis() {
    // Only attempt Redis connection if REDIS_URL is set (production)
    const redisUrl = process.env.REDIS_URL;

    if (!redisUrl) {
        console.log('⚠️  Redis not configured - running without cache');
        return;
    }

    try {
        redisClient = createClient({
            url: redisUrl,
            socket: {
                reconnectStrategy: false // Don't retry if connection fails
            }
        });

        redisClient.on('error', (err) => {
            console.error('❌ Redis Error:', err.message);
            isRedisAvailable = false;
        });

        await redisClient.connect();
        isRedisAvailable = true;
        console.log('✅ Redis Connected');
    } catch (error) {
        console.warn('⚠️  Redis connection failed - continuing without cache');
        redisClient = null;
        isRedisAvailable = false;
    }
}

export async function disconnectRedis() {
    if (redisClient && isRedisAvailable) {
        await redisClient.disconnect();
    }
}

export function getRedisClient() {
    return isRedisAvailable ? redisClient : null;
}

export function getRedisStatus() {
    return isRedisAvailable;
}

// Export a no-op client for compatibility
export { redisClient };
