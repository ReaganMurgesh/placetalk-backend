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

        // Test user creation removed - use scripts/create_test_users.ts instead
        console.log('👤 Test user creation skipped (use create_test_users.ts script)');
        
        console.log('✅ Database migration completed successfully!');
    } catch (error) {
        console.error('❌ Migration failed:', error);
        throw error;
    }
}
