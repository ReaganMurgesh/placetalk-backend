import { pool } from '../src/config/database.js';
import bcrypt from 'bcrypt';

const SALT_ROUNDS = 10;

/**
 * Complete setup for 2-user testing
 * Creates clean database state with proper test users
 */
async function setupTwoUserTesting() {
    console.log('🚀 Starting comprehensive 2-user test setup...');
    console.log('🔌 Connecting to database...');
    
    try {
        // Test connection
        await pool.query('SELECT 1');
        console.log('✅ Database connection successful');
        
        console.log('\n🧹 STEP 1: Cleaning existing test data...');
        
        // Remove any existing test users and their data
        const testEmails = ['testuser1@placetalk.app', 'testuser2@placetalk.app', 'test@placetalk.app'];
        const testUserIds = ['123e4567-e89b-12d3-a456-426614174000', 'user-test-001', 'user-test-002'];
        
        for (const email of testEmails) {
            const userResult = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
            if (userResult.rows.length > 0) {
                const userId = userResult.rows[0].id;
                console.log(`   Removing data for ${email}...`);
                
                // Clean up user data
                await pool.query('DELETE FROM user_activities WHERE user_id = $1 OR pin_id IN (SELECT id FROM pins WHERE created_by = $1)', [userId]);
                await pool.query('DELETE FROM user_pin_interactions WHERE user_id = $1 OR pin_id IN (SELECT id FROM pins WHERE created_by = $1)', [userId]);
                await pool.query('DELETE FROM discoveries WHERE user_id = $1 OR pin_id IN (SELECT id FROM pins WHERE created_by = $1)', [userId]);
                await pool.query('DELETE FROM interactions WHERE user_id = $1 OR pin_id IN (SELECT id FROM pins WHERE created_by = $1)', [userId]);
                await pool.query('DELETE FROM pins WHERE created_by = $1', [userId]);
                await pool.query('DELETE FROM users WHERE id = $1', [userId]);
            }
        }
        
        // Also clean by hardcoded IDs
        for (const testId of testUserIds) {
            console.log(`   Removing hardcoded test user ${testId}...`);
            await pool.query('DELETE FROM user_activities WHERE user_id = $1 OR pin_id IN (SELECT id FROM pins WHERE created_by = $1)', [testId]);
            await pool.query('DELETE FROM user_pin_interactions WHERE user_id = $1 OR pin_id IN (SELECT id FROM pins WHERE created_by = $1)', [testId]);
            await pool.query('DELETE FROM discoveries WHERE user_id = $1 OR pin_id IN (SELECT id FROM pins WHERE created_by = $1)', [testId]);
            await pool.query('DELETE FROM interactions WHERE user_id = $1 OR pin_id IN (SELECT id FROM pins WHERE created_by = $1)', [testId]);
            await pool.query('DELETE FROM pins WHERE created_by = $1', [testId]);
            await pool.query('DELETE FROM users WHERE id = $1', [testId]);
        }
        
        console.log('✅ Cleanup completed');
        
        console.log('\n👥 STEP 2: Creating test users...');
        
        // Create Test User 1
        const user1Password = await bcrypt.hash('testpass123', SALT_ROUNDS);
        const user1Result = await pool.query(`
            INSERT INTO users (name, email, password_hash, role, country)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id, name, email
        `, ['Test User 1', 'testuser1@placetalk.app', user1Password, 'explorer', 'Japan']);
        
        const user1 = user1Result.rows[0];
        console.log(`✅ Created User 1: ${user1.name} (${user1.email})`);
        console.log(`   ID: ${user1.id}`);
        
        // Create Test User 2  
        const user2Password = await bcrypt.hash('testpass123', SALT_ROUNDS);
        const user2Result = await pool.query(`
            INSERT INTO users (name, email, password_hash, role, country)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id, name, email
        `, ['Test User 2', 'testuser2@placetalk.app', user2Password, 'explorer', 'Japan']);
        
        const user2 = user2Result.rows[0];
        console.log(`✅ Created User 2: ${user2.name} (${user2.email})`);
        console.log(`   ID: ${user2.id}`);
        
        console.log('\n📍 STEP 3: Creating test pins for discovery...');
        
        // User 1 creates pins at specific test locations
        const testLocations = [
            { lat: 35.6762, lon: 139.6503, title: 'Tokyo Station Pin', directions: 'Near the main entrance' },
            { lat: 35.6586, lon: 139.7454, title: 'Tokyo Tower Pin', directions: 'At the base of Tokyo Tower' }
        ];
        
        let pinCount = 0;
        for (const location of testLocations) {
            const expiresAt = new Date(Date.now() + 72 * 60 * 60 * 1000); // 72 hours
            
            await pool.query(`
                INSERT INTO pins (title, directions, details, location, type, pin_category, created_by, expires_at)
                VALUES ($1, $2, $3, ST_MakePoint($4, $5)::geography, $6, $7, $8, $9)
            `, [
                location.title,
                location.directions,
                'Test pin for multi-user discovery',
                location.lon,
                location.lat,
                'location',
                'normal',
                user1.id,
                expiresAt
            ]);
            
            pinCount++;
            console.log(`✅ Created pin ${pinCount}: ${location.title} by User 1`);
        }
        
        console.log('\n🔍 STEP 4: Verifying setup...');
        
        // Verify users
        const userCount = await pool.query('SELECT COUNT(*) FROM users WHERE email LIKE $1', ['testuser%@placetalk.app']);
        console.log(`   Test users created: ${userCount.rows[0].count}`);
        
        // Verify pins
        const pinCountResult = await pool.query('SELECT COUNT(*) FROM pins WHERE created_by = $1', [user1.id]);
        console.log(`   Test pins created: ${pinCountResult.rows[0].count}`);
        
        // Verify no other pins exist
        const totalPins = await pool.query('SELECT COUNT(*) FROM pins');
        console.log(`   Total pins in database: ${totalPins.rows[0].count}`);
        
        console.log('\n🎯 SETUP COMPLETE! Ready for 2-User Testing');
        console.log('\n📱 LOGIN CREDENTIALS:');
        console.log('User 1: testuser1@placetalk.app / testpass123');
        console.log('User 2: testuser2@placetalk.app / testpass123');
        
        console.log('\n🧪 TEST SCENARIOS:');
        console.log('1. Login as User 1 → Should see 2 pins in "My Pins"');
        console.log('2. Login as User 2 → Should see 0 pins in "My Pins" (empty diary)');
        console.log('3. User 2 near Tokyo Station (35.6762, 139.6503) → Should discover User 1\'s pin');
        console.log('4. User 2 creates own pin → Should appear only in User 2\'s "My Pins"');
        console.log('5. Both users should have completely isolated diary data');

    } catch (error) {
        console.error('❌ Setup failed:', error);
        throw error;
    } finally {
        console.log('\n🔐 Closing database connection...');
        await pool.end();
        console.log('✅ Setup script completed!');
    }
}

// Run the setup
setupTwoUserTesting()
    .then(() => {
        console.log('\n🎉 2-User test environment ready!');
        process.exit(0);
    })
    .catch((error) => {
        console.error('\n💥 Setup failed:', error);
        process.exit(1);
    });