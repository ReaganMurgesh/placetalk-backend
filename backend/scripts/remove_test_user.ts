import { pool } from '../src/config/database.js';

/**
 * Removes test user and their pins causing shared data bug
 */
async function removeTestUserData() {
    console.log('🧹 Starting test user cleanup...');
    console.log('🔌 Database connection established');
    
    const testUserId = '123e4567-e89b-12d3-a456-426614174000';
    
    try {
        // Test connection first
        console.log('🔍 Testing database connection...');
        await pool.query('SELECT 1');
        console.log('✅ Database connection successful');
        
        // Step 1: Remove activities related to test user pins
        console.log('📝 Clearing activities for test user pins...');
        const activitiesResult = await pool.query(
            `DELETE FROM user_activities 
             WHERE pin_id IN (SELECT id FROM pins WHERE created_by = $1)`,
            [testUserId]
        );
        console.log(`   Deleted ${activitiesResult.rowCount} activities`);
        
        // Step 2: Remove interactions with test user pins
        console.log('📝 Clearing interactions for test user pins...');
        const interactionsResult = await pool.query(
            `DELETE FROM user_pin_interactions 
             WHERE pin_id IN (SELECT id FROM pins WHERE created_by = $1)`,
            [testUserId]
        );
        console.log(`   Deleted ${interactionsResult.rowCount} interactions`);
        
        // Step 3: Remove test user's pins
        console.log('📍 Removing test user pins...');
        const pinsResult = await pool.query(
            'DELETE FROM pins WHERE created_by = $1',
            [testUserId]
        );
        console.log(`   Deleted ${pinsResult.rowCount} pins from test user`);
        
        // Step 4: Remove test user activities
        console.log('👤 Clearing test user activities...');
        const userActivitiesResult = await pool.query(
            'DELETE FROM user_activities WHERE user_id = $1',
            [testUserId]
        );
        console.log(`   Deleted ${userActivitiesResult.rowCount} user activities`);
        
        // Step 5: Remove test user
        console.log('👤 Removing test user...');
        const userResult = await pool.query(
            'DELETE FROM users WHERE id = $1',
            [testUserId]
        );
        console.log(`   Deleted ${userResult.rowCount} test user`);
        
        // Verification
        console.log('🔍 Verifying cleanup...');
        const verification = await pool.query(`
            SELECT 
                (SELECT COUNT(*) FROM pins WHERE created_by = $1) as remaining_pins,
                (SELECT COUNT(*) FROM users WHERE id = $1) as remaining_users,
                (SELECT COUNT(*) FROM pins) as total_pins
        `, [testUserId]);
        
        const result = verification.rows[0];
        console.log(`   Test user pins remaining: ${result.remaining_pins}`);
        console.log(`   Test user remaining: ${result.remaining_users}`);
        console.log(`   Total pins in DB: ${result.total_pins}`);
        
        console.log('\n✅ Test user cleanup completed!');
        console.log('🎯 New users should now see empty diary');
        console.log('📱 Restart your app and test with fresh user registration');

    } catch (error) {
        console.error('❌ Error during cleanup:', error);
        throw error;
    } finally {
        console.log('🔐 Closing database connection...');
        try {
            await pool.end();
            console.log('✅ Connection closed successfully!');
        } catch (closeError) {
            console.error('❌ Error closing connection:', closeError);
        }
    }
}

// Run the function
removeTestUserData()
    .then(() => {
        console.log('🎉 Cleanup completed successfully');
        process.exit(0);
    })
    .catch((error) => {
        console.error('💥 Cleanup failed:', error);
        process.exit(1);
    });