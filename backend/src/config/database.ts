import 'dotenv/config';
import { Pool } from 'pg';

console.log('DB Config:', {
    host: process.env.DATABASE_HOST || 'localhost',
    port: parseInt(process.env.DATABASE_PORT || '5432'),
    database: process.env.DATABASE_NAME || 'placetalk',
    user: process.env.DATABASE_USER || 'placetalk_user',
    password: process.env.DATABASE_PASSWORD ? '***' : 'UNDEFINED',
});

export const pool = new Pool({
    host: process.env.DATABASE_HOST || 'localhost',
    port: parseInt(process.env.DATABASE_PORT || '5432'),
    database: process.env.DATABASE_NAME || 'placetalk',
    user: process.env.DATABASE_USER || 'placetalk_user',
    password: process.env.DATABASE_PASSWORD?.trim(),
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

pool.on('error', (err) => {
    console.error('Unexpected error on idle PostgreSQL client', err);
    process.exit(-1);
});

export async function testConnection() {
    try {
        const client = await pool.connect();
        const result = await client.query('SELECT NOW()');
        console.log('✅ PostgreSQL Connected:', result.rows[0].now);
        client.release();
        return true;
    } catch (error) {
        console.error('❌ PostgreSQL Connection Error:', error);
        return false;
    }
}
