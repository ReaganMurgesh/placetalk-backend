import 'dotenv/config';
import { Pool } from 'pg';

// Database connection configuration
// Priority: DATABASE_URL (Render) > Individual env vars (Docker)
const connectionString = process.env.DATABASE_URL;

console.log('DB Connection:', connectionString ? `Using DATABASE_URL (${connectionString.split('@')[1]?.split('/')[0] || 'hidden'})` : 'Using individual env vars');

// Build pool options — enable SSL for Render external connections
const poolOptions = connectionString
    ? {
        connectionString,
        ssl: connectionString.includes('render.com') || connectionString.includes('amazonaws.com') || connectionString.includes('singapore-postgres') || process.env.DATABASE_SSL === 'true'
            ? { rejectUnauthorized: false }
            : false,
        max: 10,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 10000, // Give 10s per attempt
    }
    : {
        host: process.env.DATABASE_HOST || 'localhost',
        port: parseInt(process.env.DATABASE_PORT || '5432'),
        database: process.env.DATABASE_NAME || 'placetalk',
        user: process.env.DATABASE_USER || 'placetalk_user',
        password: process.env.DATABASE_PASSWORD?.trim(),
        max: 10,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 10000,
    };

export const pool = new Pool(poolOptions);

pool.on('error', (err) => {
    console.error('Unexpected error on idle PostgreSQL client', err);
    // Don't exit — let the pool recover
});

/**
 * Test DB connection with retry logic.
 * Render free tier: DNS may not be ready on cold start — retry up to 5 times.
 */
export async function testConnection(maxRetries = 5, delayMs = 3000): Promise<boolean> {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            const client = await pool.connect();
            const result = await client.query('SELECT NOW()');
            console.log(`✅ PostgreSQL Connected (attempt ${attempt}):`, result.rows[0].now);
            client.release();
            return true;
        } catch (error: any) {
            console.error(`❌ PostgreSQL Connection Error (attempt ${attempt}/${maxRetries}):`, error.message);
            if (attempt < maxRetries) {
                console.log(`🔄 Retrying in ${delayMs / 1000}s...`);
                await new Promise(resolve => setTimeout(resolve, delayMs));
                delayMs = Math.min(delayMs * 1.5, 10000); // Exponential backoff, max 10s
            }
        }
    }
    console.error('❌ All database connection attempts failed.');
    return false;
}
