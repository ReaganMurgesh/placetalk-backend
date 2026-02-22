import { pool } from '../../config/database.js';
import type { UserPinInteraction } from './pins.types.js';

/**
 * Service for managing user-pin interactions (mute, cooldown, spaced repetition)
 */
export class PinInteractionsService {
    /**
     * Mark pin as "Good" - Set 7-day cooldown
     */
    async markPinAsGood(userId: string, pinId: string): Promise<UserPinInteraction> {
        const nextNotifyAt = new Date();
        nextNotifyAt.setDate(nextNotifyAt.getDate() + 7); // 7 days from now

        const result = await pool.query(
            `INSERT INTO user_pin_interactions (user_id, pin_id, last_interaction_at, next_notify_at, is_muted)
       VALUES ($1, $2, NOW(), $3, FALSE)
       ON CONFLICT (user_id, pin_id) 
       DO UPDATE SET 
         last_interaction_at = NOW(),
         next_notify_at = $3,
         is_muted = FALSE,
         updated_at = NOW()
       RETURNING *`,
            [userId, pinId, nextNotifyAt]
        );

        return this.mapRow(result.rows[0]);
    }

    /**
     * Mark pin as "Bad" - Mute forever
     */
    async markPinAsBad(userId: string, pinId: string): Promise<UserPinInteraction> {
        const result = await pool.query(
            `INSERT INTO user_pin_interactions (user_id, pin_id, last_interaction_at, is_muted)
       VALUES ($1, $2, NOW(), TRUE)
       ON CONFLICT (user_id, pin_id) 
       DO UPDATE SET 
         is_muted = TRUE,
         updated_at = NOW()
       RETURNING *`,
            [userId, pinId]
        );

        return this.mapRow(result.rows[0]);
    }

    /**
     * Unmute pin (tap on map to re-enable)
     */
    async unmutePinForever(userId: string, pinId: string): Promise<UserPinInteraction> {
        const result = await pool.query(
            `INSERT INTO user_pin_interactions (user_id, pin_id, is_muted, next_notify_at)
       VALUES ($1, $2, FALSE, NULL)
       ON CONFLICT (user_id, pin_id) 
       DO UPDATE SET 
         is_muted = FALSE,
         next_notify_at = NULL,
         updated_at = NOW()
       RETURNING *`,
            [userId, pinId]
        );

        return this.mapRow(result.rows[0]);
    }

    /**
     * Check if user should be notified about this pin
     * Returns FALSE if muted or in cooldown period
     */
    async shouldNotifyUser(userId: string, pinId: string): Promise<boolean> {
        const result = await pool.query(
            `SELECT is_muted, next_notify_at 
       FROM user_pin_interactions 
       WHERE user_id = $1 AND pin_id = $2`,
            [userId, pinId]
        );

        if (result.rows.length === 0) {
            return true; // No interaction record = notify
        }

        const interaction = result.rows[0];

        // Never notify if muted
        if (interaction.is_muted) {
            return false;
        }

        // Check cooldown
        if (interaction.next_notify_at) {
            return new Date() >= new Date(interaction.next_notify_at);
        }

        return true; // No cooldown = notify
    }

    /**
     * Get all user interactions (for syncing to mobile)
     */
    async getUserInteractions(userId: string): Promise<UserPinInteraction[]> {
        const result = await pool.query(
            `SELECT * FROM user_pin_interactions WHERE user_id = $1`,
            [userId]
        );

        return result.rows.map((row) => this.mapRow(row));
    }

    private mapRow(row: any): UserPinInteraction {
        return {
            userId: row.user_id,
            pinId: row.pin_id,
            lastSeenAt: row.last_interaction_at,   // column is last_interaction_at in DB
            nextNotifyAt: row.next_notify_at,
            isMuted: row.is_muted,
            createdAt: row.created_at,
            updatedAt: row.updated_at,
        };
    }
}

export const pinInteractionsService = new PinInteractionsService();
