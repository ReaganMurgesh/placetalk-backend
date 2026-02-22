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

            // Check if pin exists and is not deleted (expires_at NOT checked - expired pins can still be liked)
            const pinCheck = await client.query(
                'SELECT id, like_count, dislike_count FROM pins WHERE id = $1 AND is_deleted = FALSE',
                [pinId]
            );

            if (pinCheck.rows.length === 0) {
                throw new Error('Pin not found');
            }

            // Check existing interaction (uses interactions.interaction_type column)
            const existing = await client.query(
                'SELECT interaction_type FROM interactions WHERE user_id = $1 AND pin_id = $2',
                [userId, pinId]
            );

            if (existing.rows.length > 0) {
                if (existing.rows[0].interaction_type === 'like') {
                    // Already liked — idempotent: return current counts quietly
                    await client.query('ROLLBACK');
                    const cur = await pool.query('SELECT like_count, dislike_count FROM pins WHERE id = $1', [pinId]);
                    return { success: true, likeCount: cur.rows[0].like_count, dislikeCount: cur.rows[0].dislike_count };
                }

                // Flip from dislike → like
                await client.query(
                    'UPDATE interactions SET interaction_type = $1, created_at = NOW() WHERE user_id = $2 AND pin_id = $3 AND interaction_type = $4',
                    ['like', userId, pinId, existing.rows[0].interaction_type]
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
     * Report a pin (formerly Dislike)
     * - Prevents double-voting
     * - If user previously liked, flips to report
     * - Updates dislike_count (used as report_count)
     */
    async reportPin(userId: string, pinId: string): Promise<{ success: boolean; likeCount: number; reportCount: number }> {
        const client = await pool.connect();

        try {
            await client.query('BEGIN');

            // Check if pin exists and is active
            const pinCheck = await client.query(
                'SELECT id FROM pins WHERE id = $1 AND is_deleted = FALSE',
                [pinId]
            );

            if (pinCheck.rows.length === 0) {
                throw new Error('Pin not found');
            }

            // Check existing interaction (uses interactions.interaction_type column)
            const existing = await client.query(
                'SELECT interaction_type FROM interactions WHERE user_id = $1 AND pin_id = $2',
                [userId, pinId]
            );

            if (existing.rows.length > 0) {
                if (existing.rows[0].interaction_type === 'dislike') {
                    // Already reported — idempotent: return current counts quietly
                    await client.query('ROLLBACK');
                    const cur = await pool.query('SELECT like_count, dislike_count FROM pins WHERE id = $1', [pinId]);
                    return { success: true, likeCount: cur.rows[0].like_count, reportCount: cur.rows[0].dislike_count };
                }

                // Flip from like → dislike (report)
                await client.query(
                    'UPDATE interactions SET interaction_type = $1, created_at = NOW() WHERE user_id = $2 AND pin_id = $3 AND interaction_type = $4',
                    ['dislike', userId, pinId, existing.rows[0].interaction_type]
                );

                // Adjust counts: +1 report, -1 like
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
                reportCount: updated.rows[0].dislike_count,
            };
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }
    }

    /**
     * Hide a pin (Personal Mute)
     * - Uses user_pin_interactions table
     * - Sets is_muted = TRUE
     */
    async hidePin(userId: string, pinId: string): Promise<void> {
        await pool.query(
            `INSERT INTO user_pin_interactions (user_id, pin_id, is_muted, last_interaction_at)
       VALUES ($1, $2, TRUE, NOW())
       ON CONFLICT (user_id, pin_id) 
       DO UPDATE SET is_muted = TRUE, last_interaction_at = NOW(), updated_at = NOW()`,
            [userId, pinId]
        );
    }
}
