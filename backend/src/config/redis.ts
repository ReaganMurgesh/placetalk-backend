import 'dotenv/config';
import { createClient } from 'redis';

let isRedisAvailable = false;

export const redisClient = createClient({
    socket: {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT || '6379'),
    },
});

redisClient.on('error', (err) => console.error('❌ Redis Client Error:', err));
redisClient.on('connect', () => {
    console.log('✅ Redis Connected');
    isRedisAvailable = true;
});

export async function connectRedis() {
    try {
        await redisClient.connect();
    } catch (error) {
        console.warn('⚠️  Redis unavailable - running without cache (performance may be reduced)');
        isRedisAvailable = false;
    }
}

export async function disconnectRedis() {
    if (isRedisAvailable) {
        await redisClient.disconnect();
    }
}

export function getRedisStatus() {
    return isRedisAvailable;
}
