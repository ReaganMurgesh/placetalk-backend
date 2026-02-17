import type { FastifyInstance } from 'fastify';
import { pool } from '../config/database.js';

export async function debugRoutes(fastify: FastifyInstance) {
    /**
     * EMERGENCY: Clear all pins (for testing user isolation)
     */
    fastify.delete('/clear-all-pins', async (request, reply) => {
        try {
            console.log('🚨 DEBUG: Clearing ALL pins from database');
            
            // Use TRUNCATE CASCADE to handle all foreign keys automatically
            await pool.query('TRUNCATE TABLE pins CASCADE');
            
            // Check what's left
            const result = await pool.query('SELECT COUNT(*) FROM pins');
            const remainingPins = result.rows[0].count;
            
            console.log(`✅ DEBUG: Database cleaned. Pins remaining: ${remainingPins}`);
            
            return reply.send({ 
                success: true, 
                message: 'All pins cleared successfully',
                remainingPins: remainingPins
            });
        } catch (error: any) {
            console.error('❌ DEBUG: Error clearing pins:', error);
            return reply.code(500).send({ error: 'Failed to clear pins', details: error.message });
        }
    });
    
    /**
     * DEBUG: Show all pins with their creators
     */
    fastify.get('/show-all-pins', async (request, reply) => {
        try {
            const result = await pool.query(`
                SELECT id, title, created_by, created_at 
                FROM pins 
                ORDER BY created_at DESC
            `);
            
            console.log(`📊 DEBUG: Found ${result.rows.length} pins in database:`);
            result.rows.forEach((pin, i) => {
                console.log(`  ${i+1}. "${pin.title}" by ${pin.created_by} (${pin.created_at})`);
            });
            
            return reply.send({
                total: result.rows.length,
                pins: result.rows
            });
        } catch (error) {
            console.error('❌ DEBUG: Error showing pins:', error);
            return reply.code(500).send({ error: 'Failed to show pins' });
        }
    });
}