import { pool } from '../src/config/database.js';

/**
 * Clears all pins and related data from the database
 */
async function clearAllPins() {
    console.log('🧹 Starting database cleanup...');
    console.log('🔌 Database connection established');
    
    try {
        // Test connection first
        console.log('🔍 Testing database connection...');
        await pool.query('SELECT 1');
        console.log('✅ Database connection successful');
        
        // Clear related data first (foreign key constraints)
        console.log('📝 Clearing user_pin_interactions...');
        const interactionsResult = await pool.query('DELETE FROM user_pin_interactions');
        console.log(`   Deleted ${interactionsResult.rowCount} interactions`);
        
        console.log('📝 Clearing user_activities...');
        const activitiesResult = await pool.query('DELETE FROM user_activities WHERE pin_id IS NOT NULL');
        console.log(`   Deleted ${activitiesResult.rowCount} activities`);
        
        console.log('📝 Clearing community_messages...');
        const messagesResult = await pool.query('DELETE FROM community_messages WHERE pin_id IS NOT NULL');
        console.log(`   Deleted ${messagesResult.rowCount} messages`);
        
        // Clear pins last
        console.log('📍 Clearing pins...');
        const pinsResult = await pool.query('DELETE FROM pins');
        console.log(`   Deleted ${pinsResult.rowCount} pins`);
        
        console.log('\n✅ Database cleanup completed!');
        console.log('🎯 All pins and related data have been removed');
        console.log('📱 You can now test with fresh data');

    } catch (error) {
        console.error('❌ Error clearing database:', error);
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
clearAllPins()
    .then(() => {
        console.log('🎉 Script completed successfully');
        process.exit(0);
    })
    .catch((error) => {
        console.error('💥 Script failed:', error);
        process.exit(1);
    });