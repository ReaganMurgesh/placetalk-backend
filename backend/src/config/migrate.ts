import 'dotenv/config';
import { pool } from './database.js';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export async function runMigrations() {
    try {
        console.log('🔄 Checking database schema...');

        // Check if tables exist
        const result = await pool.query(`
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = 'users'
            );
        `);

        const tablesExist = result.rows[0].exists;

        if (tablesExist) {
            console.log('✅ Database schema already exists');
            return;
        }

        console.log('📋 Creating database schema...');

        // Read schema.sql from parent directory
        const schemaPath = join(__dirname, '../../schema.sql');
        const schemaSql = readFileSync(schemaPath, 'utf-8');

        // Execute schema
        await pool.query(schemaSql);

        console.log('✅ Database schema created successfully');

        // Create test user for development/testing
        console.log('👤 Creating test user...');
        await pool.query(`
            INSERT INTO users (id, name, email, password_hash, role)
            VALUES (
                '123e4567-e89b-12d3-a456-426614174000',
                'Test User',
                'test@placetalk.app',
                '$2b$10$abcdefghijklmnopqrstuvwxyz1234567890',
                'explorer'
            )
            ON CONFLICT (id) DO NOTHING;
        `);
        console.log('✅ Test user created');
    } catch (error) {
        console.error('❌ Migration failed:', error);
        throw error;
    }
}
