import { pool } from '../src/config/database.js';
import bcrypt from 'bcrypt';

const SALT_ROUNDS = 10;

/**
 * Creates test users for multi-user testing
 */
async function createTestUsers() {
    try {
        console.log('🚀 Starting test user creation...');
        
        // Create two test users
        const testUsers = [
            {
                id: 'user-test-001',
                email: 'user1@test.com',
                username: 'TestUser1',
                password: 'test123'
            },
            {
                id: 'user-test-002', 
                email: 'user2@test.com',
                username: 'TestUser2',
                password: 'test123'
            }
        ];

        console.log('📝 Processing users...');

        for (const user of testUsers) {
            console.log(`Processing ${user.username}...`);
            const hashedPassword = await bcrypt.hash(user.password, SALT_ROUNDS);
            
            // Check if user already exists
            const existingUser = await pool.query(
                'SELECT id FROM users WHERE email = $1 OR name = $2',
                [user.email, user.username]
            );

            if (existingUser.rows.length > 0) {
                console.log(`User ${user.username} already exists, skipping...`);
                continue;
            }

            // Insert new user
            await pool.query(
                `INSERT INTO users (id, name, email, password_hash, role, created_at, updated_at)
                 VALUES ($1, $2, $3, $4, 'user', NOW(), NOW())`,
                [user.id, user.username, user.email, hashedPassword]
            );

            console.log(`✅ Created test user: ${user.username} (${user.email})`);
            console.log(`   ID: ${user.id}`);
            console.log(`   Login: ${user.email} / ${user.password}`);
        }

        console.log('\n🎯 Test Users Created Successfully!');
        console.log('\nLogin Credentials:');
        console.log('User 1: user1@test.com / test123');
        console.log('User 2: user2@test.com / test123');
        console.log('\nUse these credentials in your Flutter app to test multi-user functionality');

    } catch (error) {
        console.error('❌ Error creating test users:', error);
        process.exit(1);
    } finally {
        console.log('🔐 Closing database connection...');
        await pool.end();
        console.log('✅ Done!');
    }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
    createTestUsers();
}