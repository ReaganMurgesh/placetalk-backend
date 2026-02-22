import { pool } from '../../config/database.js';
import type { UserActivity, TimelineEntry, UserStats, Badge, PassiveLogEntry, DiaryPinMetrics, DiarySearchResult } from './diary.types.js';

export class DiaryService {
    /**
     * Log a user activity (auto-called on pin interactions)
     */
    async logActivity(
        userId: string,
        pinId: string,
        activityType: 'visited' | 'liked' | 'commented' | 'created' | 'reported' | 'hidden' | 'ghost_pass' | 'discovered',
        metadata?: Record<string, any>
    ): Promise<UserActivity> {
        const result = await pool.query(
            `INSERT INTO user_activities (user_id, pin_id, activity_type, metadata)
       VALUES ($1, $2, $3, $4)
       RETURNING id, user_id AS "userId", pin_id AS "pinId", 
                 activity_type AS "activityType", metadata, created_at AS "createdAt"`,
            [userId, pinId, activityType, JSON.stringify(metadata || {})]
        );

        // ── spec 4.1: auto-increment pin engagement counters ─────────────────
        if (activityType === 'ghost_pass') {
            await pool.query(
                `UPDATE pins SET pass_through_count = COALESCE(pass_through_count,0) + 1 WHERE id = $1`,
                [pinId]
            );
        } else if (activityType === 'hidden') {
            await pool.query(
                `UPDATE pins SET hide_count = COALESCE(hide_count,0) + 1 WHERE id = $1`,
                [pinId]
            );
        } else if (activityType === 'reported') {
            await pool.query(
                `UPDATE pins SET report_count = COALESCE(report_count,0) + 1 WHERE id = $1`,
                [pinId]
            );
        }

        return result.rows[0];
    }

    /**
     * Get user's activity timeline with pin details
     */
    async getUserTimeline(
        userId: string,
        startDate?: Date,
        endDate?: Date,
        limit: number = 100
    ): Promise<TimelineEntry[]> {
        const conditions = ['ua.user_id = $1'];
        const params: any[] = [userId];

        if (startDate) {
            params.push(startDate);
            conditions.push(`ua.created_at >= $${params.length}`);
        }

        if (endDate) {
            params.push(endDate);
            conditions.push(`ua.created_at <= $${params.length}`);
        }

        params.push(limit);

        const result = await pool.query(
            `SELECT ua.id, ua.user_id AS "userId", ua.pin_id AS "pinId", 
                    ua.activity_type AS "activityType", ua.metadata, ua.created_at AS "createdAt",
                    COALESCE(p.title, '[Deleted Pin]') AS "pinTitle",
                    'Normal' AS "pinAttribute",
                    COALESCE(ST_Y(p.location::geometry), 0) AS "pinLat",
                    COALESCE(ST_X(p.location::geometry), 0) AS "pinLon"
       FROM user_activities ua
       LEFT JOIN pins p ON ua.pin_id = p.id
       -- LEFT JOIN attributes a ON p.attribute_id = a.id
       WHERE ${conditions.join(' AND ')}
       ORDER BY ua.created_at DESC
       LIMIT $${params.length}`,
            params
        );

        return result.rows;
    }

    /**
     * Calculate user's current streak (consecutive days with activity)
     */
    async calculateStreak(userId: string): Promise<{ current: number; longest: number }> {
        const result = await pool.query(
            `SELECT DISTINCT DATE(created_at) as date
       FROM user_activities
       WHERE user_id = $1
       ORDER BY date DESC`,
            [userId]
        );

        const dates = result.rows.map(row => new Date(row.date));

        if (dates.length === 0) {
            return { current: 0, longest: 0 };
        }

        let currentStreak = 1;
        let longestStreak = 1;
        let tempStreak = 1;

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        // Check if most recent activity was today or yesterday
        const mostRecent = new Date(dates[0]);
        mostRecent.setHours(0, 0, 0, 0);
        const daysDiff = Math.floor((today.getTime() - mostRecent.getTime()) / (1000 * 60 * 60 * 24));

        if (daysDiff > 1) {
            currentStreak = 0;
        }

        // Calculate streaks
        for (let i = 1; i < dates.length; i++) {
            const prev = new Date(dates[i - 1]);
            const curr = new Date(dates[i]);
            prev.setHours(0, 0, 0, 0);
            curr.setHours(0, 0, 0, 0);

            const diff = Math.floor((prev.getTime() - curr.getTime()) / (1000 * 60 * 60 * 24));

            if (diff === 1) {
                tempStreak++;
                if (i < dates.length - 1 || daysDiff <= 1) {
                    currentStreak = tempStreak;
                }
            } else {
                if (tempStreak > longestStreak) {
                    longestStreak = tempStreak;
                }
                tempStreak = 1;
            }
        }

        longestStreak = Math.max(longestStreak, tempStreak);

        return { current: currentStreak, longest: longestStreak };
    }

    /**
     * Get user badges based on achievements
     */
    async getUserBadges(userId: string): Promise<Badge[]> {
        const badges: Badge[] = [];

        // Get activity counts
        const activityResult = await pool.query(
            `SELECT COUNT(*) as total,
                    COUNT(CASE WHEN activity_type = 'visited' THEN 1 END) as visited
       FROM user_activities
       WHERE user_id = $1`,
            [userId]
        );

        const { total, visited } = activityResult.rows[0];

        // Badge: Explorer (10+ pins visited)
        if (parseInt(visited) >= 10) {
            badges.push({
                id: 'explorer',
                name: 'Explorer',
                description: 'Visited 10+ pins',
                icon: '🗺️',
                earnedAt: new Date(),
            });
        }

        // Badge: Amakusa Wanderer (5+ pins in Amakusa region)
        const amakusaResult = await pool.query(
            `SELECT COUNT(DISTINCT ua.pin_id) as count
       FROM user_activities ua
       INNER JOIN pins p ON ua.pin_id = p.id
       WHERE ua.user_id = $1 
         AND ST_GeoHash(p.location::geometry, 5) LIKE 'wv%'`,  // Amakusa region geohash prefix
            [userId]
        );

        if (parseInt(amakusaResult.rows[0].count) >= 5) {
            badges.push({
                id: 'amakusa_wanderer',
                name: 'Amakusa Wanderer',
                description: 'Discovered 5+ pins in Amakusa',
                icon: '🏝️',
                earnedAt: new Date(),
            });
        }

        /* 
        // Badge: Mikan Lover (Temporarily disabled due to missing schema)
        const mikanResult = await pool.query(
            `SELECT COUNT(DISTINCT ua.pin_id) as count
       FROM user_activities ua
       INNER JOIN pins p ON ua.pin_id = p.id
       LEFT JOIN attributes a ON p.attribute_id = a.id
       WHERE ua.user_id = $1 
         AND a.name = 'agriculture'`,
            [userId]
        );

        if (parseInt(mikanResult.rows[0].count) >= 3) {
            badges.push({
                id: 'mikan_lover',
                name: 'Mikan Lover',
                description: 'Discovered 3+ agriculture pins',
                icon: '🍊',
                earnedAt: new Date(),
            });
        } 
        */

        return badges;
    }

    /**
     * Get user stats (total activities, streaks, badges)
     */
    async getUserStats(userId: string): Promise<UserStats> {
        // Total activities
        const countResult = await pool.query(
            'SELECT COUNT(*) as total FROM user_activities WHERE user_id = $1',
            [userId]
        );

        // Total pins created by user
        const pinsResult = await pool.query(
            'SELECT COUNT(*) as total FROM pins WHERE created_by = $1',
            [userId]
        );

        // Total discoveries (visited pins)
        const discoveriesResult = await pool.query(
            "SELECT COUNT(*) as total FROM user_activities WHERE user_id = $1 AND activity_type = 'visited'",
            [userId]
        );

        const streaks = await this.calculateStreak(userId);
        const badges = await this.getUserBadges(userId);

        return {
            totalActivities: parseInt(countResult.rows[0].total),
            totalPinsCreated: parseInt(pinsResult.rows[0].total),
            totalDiscoveries: parseInt(discoveriesResult.rows[0].total),
            currentStreak: streaks.current,
            longestStreak: streaks.longest,
            badges,
        };
    }

    // ── spec 4.1 Tab 1: Passive Log (ghost + verified) ──────────────────────
    async getPassiveLog(
        userId: string,
        sort: 'recent' | 'like_count' = 'recent',
        limit = 100
    ): Promise<PassiveLogEntry[]> {
        const orderBy = sort === 'like_count'
            ? 'p.like_count DESC, ua.created_at DESC'
            : 'ua.created_at DESC';

        const res = await pool.query(
            `SELECT
               ua.id        AS "activityId",
               ua.pin_id    AS "pinId",
               COALESCE(p.title, '[Deleted Pin]') AS "pinTitle",
               COALESCE(ST_Y(p.location::geometry), 0) AS "pinLat",
               COALESCE(ST_X(p.location::geometry), 0) AS "pinLon",
               COALESCE(p.like_count, 0) AS "pinLikeCount",
               COALESCE(p.type, 'location') AS "pinType",
               COALESCE(ua.verified, FALSE)  AS "isVerified",
               ua.verified_at               AS "verifiedAt",
               ua.created_at                AS "passedAt",
               ua.activity_type             AS "activityType"
             FROM user_activities ua
             LEFT JOIN pins p ON ua.pin_id = p.id
             WHERE ua.user_id = $1
               AND ua.activity_type IN ('ghost_pass', 'visited', 'discovered', 'liked')
             ORDER BY ${orderBy}
             LIMIT $2`,
            [userId, limit]
        );
        return res.rows;
    }

    // ── spec 4.1 Tab 1: Upgrade ghost_pass → Verified ─────────────────────────
    async verifyGhostPin(userId: string, pinId: string): Promise<void> {
        // Mark all ghost_pass activities for this pin as verified
        await pool.query(
            `UPDATE user_activities
               SET verified = TRUE, verified_at = NOW(), activity_type = 'liked'
             WHERE user_id = $1 AND pin_id = $2 AND activity_type = 'ghost_pass'`,
            [userId, pinId]
        );
        // Also like the pin (idempotent upsert into interactions)
        await pool.query(
            `INSERT INTO interactions (user_id, pin_id, interaction_type)
             VALUES ($1, $2, 'like')
             ON CONFLICT (user_id, pin_id) DO UPDATE SET interaction_type = 'like'`,
            [userId, pinId]
        );
        // Recalculate like_count
        await pool.query(
            `UPDATE pins SET like_count = (
               SELECT COUNT(*) FROM interactions WHERE pin_id = $1 AND interaction_type = 'like'
             ) WHERE id = $1`,
            [pinId]
        );
    }

    // ── spec 4.1 Tab 2: My Pins with full metrics ─────────────────────────────
    async getMyPinsWithMetrics(userId: string): Promise<DiaryPinMetrics[]> {
        const res = await pool.query(
            `SELECT
               p.id,
               p.title,
               p.directions,
               COALESCE(ST_Y(p.location::geometry), 0) AS lat,
               COALESCE(ST_X(p.location::geometry), 0) AS lon,
               p.type                                   AS "pinType",
               p.pin_category                           AS "pinCategory",
               COALESCE(p.like_count, 0)                AS "likeCount",
               COALESCE(p.dislike_count, 0)             AS "dislikeCount",
               COALESCE(p.pass_through_count, 0)        AS "passThrough",
               COALESCE(p.hide_count, 0)                AS "hideCount",
               COALESCE(p.report_count, 0)              AS "reportCount",
               p.created_at                             AS "createdAt"
             FROM pins p
             WHERE p.created_by = $1
               AND p.is_deleted = FALSE
             ORDER BY p.created_at DESC`,
            [userId]
        );
        return res.rows;
    }

    // ── spec 4.2: Full-text search across all user activity pins ─────────────
    async searchDiary(userId: string, query: string, limit = 50): Promise<DiarySearchResult[]> {
        if (!query.trim()) return [];
        const res = await pool.query(
            `SELECT
               ua.id          AS "activityId",
               p.id           AS "pinId",
               p.title        AS "pinTitle",
               COALESCE(p.type, 'location')         AS "pinType",
               COALESCE(p.pin_category, 'normal')   AS "pinCategory",
               COALESCE(p.directions, '')           AS "pinDirections",
               COALESCE(ST_Y(p.location::geometry), 0) AS "pinLat",
               COALESCE(ST_X(p.location::geometry), 0) AS "pinLon",
               ua.activity_type    AS "activityType",
               COALESCE(ua.verified, FALSE) AS "isVerified",
               ua.created_at       AS "lastActivity"
             FROM user_activities ua
             JOIN pins p ON ua.pin_id = p.id
             WHERE ua.user_id = $1
               AND p.is_deleted = FALSE
               AND to_tsvector('simple',
                     p.title || ' ' ||
                     COALESCE(p.directions,'') || ' ' ||
                     COALESCE(p.details,''))
                   @@ plainto_tsquery('simple', $2)
             ORDER BY ua.created_at DESC
             LIMIT $3`,
            [userId, query.trim(), limit]
        );
        return res.rows;
    }
}

export const diaryService = new DiaryService();
