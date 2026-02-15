
import { pool } from '../src/config/database';

async function checkTables() {
    try {
        console.log('🔌 Connecting to Database...');

        const result = await pool.query(`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
            ORDER BY table_name;
        `);

        console.log('\n📊 Existing Tables:');
        if (result.rows.length === 0) {
            console.log('⚠️  No tables found!');
        } else {
            result.rows.forEach(row => {
                console.log(` - ${row.table_name}`);
            });
        }

    } catch (error) {
        console.error('❌ Error checking tables:', error);
    } finally {
        await pool.end();
    }
}

checkTables();
