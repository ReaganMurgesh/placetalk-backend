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
                SELECT 
                    id, 
                    title, 
                    created_by, 
                    ST_Y(location::geometry) AS lat,
                    ST_X(location::geometry) AS lon,
                    created_at 
                FROM pins 
                ORDER BY created_at DESC
            `);
            
            console.log(`📊 DEBUG: Found ${result.rows.length} pins in database:`);
            result.rows.forEach((pin, i) => {
                console.log(`  ${i+1}. "${pin.title}" at (${pin.lat}, ${pin.lon}) by ${pin.created_by}`);
            });
            
            return reply.send({
                total: result.rows.length,
                pins: result.rows
            });
        } catch (error: any) {
            console.error('❌ DEBUG: Error showing pins:', error);
            return reply.code(500).send({ error: 'Failed to show pins', details: error.message });
        }
    });

    /**
     * DEBUG: Test nearby pins query without auth (simplified)
     * Usage: /debug/test-nearby?lat=37.42&lon=-122.08&radius=100
     */
    fastify.get<{ Querystring: { lat: string; lon: string; radius?: string } }>(
        '/test-nearby',
        async (request, reply) => {
            try {
                const lat = parseFloat(request.query.lat);
                const lon = parseFloat(request.query.lon);
                const radius = parseInt(request.query.radius || '50');

                if (isNaN(lat) || isNaN(lon)) {
                    return reply.code(400).send({ error: 'Invalid lat/lon' });
                }

                console.log(`🔍 DEBUG: Testing nearby query at (${lat}, ${lon}) radius ${radius}m`);

                // Simple query without user_pin_interactions join
                const result = await pool.query(`
                    SELECT 
                        p.id,
                        p.title,
                        p.created_by,
                        ST_Y(p.location::geometry) AS lat,
                        ST_X(p.location::geometry) AS lon,
                        ST_Distance(
                            p.location::geography,
                            ST_MakePoint($1, $2)::geography
                        ) AS distance_meters
                    FROM pins p
                    WHERE p.is_deleted = FALSE
                      AND (p.expires_at IS NULL OR p.expires_at > NOW())
                      AND ST_DWithin(
                          p.location::geography,
                          ST_MakePoint($1, $2)::geography,
                          $3
                      )
                    ORDER BY distance_meters ASC
                `, [lon, lat, radius]);

                console.log(`✅ DEBUG: Found ${result.rows.length} pins within ${radius}m`);
                result.rows.forEach((pin, i) => {
                    console.log(`  ${i+1}. "${pin.title}" at ${pin.distance_meters.toFixed(1)}m`);
                });

                return reply.send({
                    query: { lat, lon, radius },
                    count: result.rows.length,
                    pins: result.rows
                });
            } catch (error: any) {
                console.error('❌ DEBUG: Nearby query error:', error);
                return reply.code(500).send({ error: 'Query failed', details: error.message });
            }
        }
    );

    /**
     * DEBUG: Check database tables exist
     */
    fastify.get('/check-tables', async (request, reply) => {
        try {
            const tables = await pool.query(`
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public'
                ORDER BY table_name
            `);

            // Check user_pin_interactions specifically
            const upiExists = tables.rows.some(r => r.table_name === 'user_pin_interactions');

            return reply.send({
                tables: tables.rows.map(r => r.table_name),
                user_pin_interactions_exists: upiExists
            });
        } catch (error: any) {
            return reply.code(500).send({ error: error.message });
        }
    });
}