import { pool } from '../../config/database.js';

export class InteractionsService {
    /**
     * Like a pin
     * - Prevents double-voting (user can only interact once per pin)
     * - If user previously disliked, flips to like
     * - Updates pin's like_count / dislike_count
     */
    async likePin(userId: string, pinId: string): Promise<{ success: boolean; likeCount: number; dislikeCount: number }> {
        const client = await pool.connect();

        try {
            await client.query('BEGIN');

            // Check if pin exists and is active
            const pinCheck = await client.query(
                'SELECT id, like_count, dislike_count FROM pins WHERE id = $1 AND is_deleted = FALSE AND expires_at > NOW()',
                [pinId]
            );

            if (pinCheck.rows.length === 0) {
                throw new Error('Pin not found or expired');
            }

            // Check existing interaction
            const existing = await client.query(
                'SELECT interaction_type FROM interactions WHERE user_id = $1 AND pin_id = $2',
                [userId, pinId]
            );

            if (existing.rows.length > 0) {
                if (existing.rows[0].interaction_type === 'like') {
                    throw new Error('Already liked this pin');
                }

                // Flip from dislike → like
                await client.query(
                    'UPDATE interactions SET interaction_type = $1, created_at = NOW() WHERE user_id = $2 AND pin_id = $3',
                    ['like', userId, pinId]
                );

                // Adjust counts: +1 like, -1 dislike
                await client.query(
                    'UPDATE pins SET like_count = like_count + 1, dislike_count = GREATEST(dislike_count - 1, 0), updated_at = NOW() WHERE id = $1',
                    [pinId]
                );
            } else {
                // New interaction
                await client.query(
                    'INSERT INTO interactions (user_id, pin_id, interaction_type) VALUES ($1, $2, $3)',
                    [userId, pinId, 'like']
                );

                await client.query(
                    'UPDATE pins SET like_count = like_count + 1, updated_at = NOW() WHERE id = $1',
                    [pinId]
                );
            }

            await client.query('COMMIT');

            // Return updated counts
            const updated = await pool.query(
                'SELECT like_count, dislike_count FROM pins WHERE id = $1',
                [pinId]
            );

            return {
                success: true,
                likeCount: updated.rows[0].like_count,
                dislikeCount: updated.rows[0].dislike_count,
            };
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }
    }

    /**
     * Dislike a pin
     * - Prevents double-voting
     * - If user previously liked, flips to dislike
     */
    async dislikePin(userId: string, pinId: string): Promise<{ success: boolean; likeCount: number; dislikeCount: number }> {
        const client = await pool.connect();

        try {
            await client.query('BEGIN');

            // Check if pin exists and is active
            const pinCheck = await client.query(
                'SELECT id FROM pins WHERE id = $1 AND is_deleted = FALSE AND expires_at > NOW()',
                [pinId]
            );

            if (pinCheck.rows.length === 0) {
                throw new Error('Pin not found or expired');
            }

            // Check existing interaction
            const existing = await client.query(
                'SELECT interaction_type FROM interactions WHERE user_id = $1 AND pin_id = $2',
                [userId, pinId]
            );

            if (existing.rows.length > 0) {
                if (existing.rows[0].interaction_type === 'dislike') {
                    throw new Error('Already disliked this pin');
                }

                // Flip from like → dislike
                await client.query(
                    'UPDATE interactions SET interaction_type = $1, created_at = NOW() WHERE user_id = $2 AND pin_id = $3',
                    ['dislike', userId, pinId]
                );

                // Adjust counts: +1 dislike, -1 like
                await client.query(
                    'UPDATE pins SET dislike_count = dislike_count + 1, like_count = GREATEST(like_count - 1, 0), updated_at = NOW() WHERE id = $1',
                    [pinId]
                );
            } else {
                // New interaction
                await client.query(
                    'INSERT INTO interactions (user_id, pin_id, interaction_type) VALUES ($1, $2, $3)',
                    [userId, pinId, 'dislike']
                );

                await client.query(
                    'UPDATE pins SET dislike_count = dislike_count + 1, updated_at = NOW() WHERE id = $1',
                    [pinId]
                );
            }

            await client.query('COMMIT');

            // Return updated counts
            const updated = await pool.query(
                'SELECT like_count, dislike_count FROM pins WHERE id = $1',
                [pinId]
            );

            return {
                success: true,
                likeCount: updated.rows[0].like_count,
                dislikeCount: updated.rows[0].dislike_count,
            };
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }
    }
}
