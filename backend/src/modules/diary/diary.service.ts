import { pool } from '../../config/database.js';
import type { UserActivity, TimelineEntry, UserStats, Badge } from './diary.types.js';

export class DiaryService {
    /**
     * Log a user activity (auto-called on pin interactions)
     */
    async logActivity(
        userId: string,
        pinId: string,
        activityType: 'visited' | 'liked' | 'commented' | 'created' | 'reported' | 'hidden',
        metadata?: Record<string, any>
    ): Promise<UserActivity> {
        const result = await pool.query(
            `INSERT INTO user_activities (user_id, pin_id, activity_type, metadata)
       VALUES ($1, $2, $3, $4)
       RETURNING id, user_id AS "userId", pin_id AS "pinId", 
                 activity_type AS "activityType", metadata, created_at AS "createdAt"`,
            [userId, pinId, activityType, JSON.stringify(metadata || {})]
        );

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
                    p.title AS "pinTitle", 'Normal' AS "pinAttribute", ST_Y(p.location::geometry) AS "pinLat", ST_X(p.location::geometry) AS "pinLon"
       FROM user_activities ua
       INNER JOIN pins p ON ua.pin_id = p.id
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
        const countResult = await pool.query(
            'SELECT COUNT(*) as total FROM user_activities WHERE user_id = $1',
            [userId]
        );

        const streaks = await this.calculateStreak(userId);
        const badges = await this.getUserBadges(userId);

        return {
            totalActivities: parseInt(countResult.rows[0].total),
            currentStreak: streaks.current,
            longestStreak: streaks.longest,
            badges,
        };
    }
}

export const diaryService = new DiaryService();
