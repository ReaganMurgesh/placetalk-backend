export interface UserActivity {
    id: string;
    userId: string;
    pinId: string;
    activityType: 'visited' | 'liked' | 'commented' | 'created' | 'reported' | 'hidden' | 'ghost_pass' | 'discovered';
    metadata?: Record<string, any>;
    verified?: boolean;
    verifiedAt?: Date | null;
    createdAt: Date;
}

export interface TimelineEntry extends UserActivity {
    pinTitle: string;
    pinAttribute?: string;
    pinLat: number;
    pinLon: number;
}

// ── spec 4.1 Tab 1: Passive Log entry (ghost_pass or verified) ────────────────
export interface PassiveLogEntry {
    activityId: string;
    pinId: string;
    pinTitle: string;
    pinLat: number;
    pinLon: number;
    pinLikeCount: number;
    pinType: string;
    isVerified: boolean;       // true = liked/verified; false = ghost pass
    verifiedAt: Date | null;
    passedAt: Date;
    activityType: string;
}

// ── spec 4.1 Tab 2: My Pin with engagement metrics ────────────────────────────
export interface DiaryPinMetrics {
    id: string;
    title: string;
    directions: string;
    lat: number;
    lon: number;
    pinType: string;
    pinCategory: string;
    likeCount: number;
    dislikeCount: number;
    passThrough: number;
    hideCount: number;
    reportCount: number;
    createdAt: Date;
}

// ── spec 4.2: Search result ────────────────────────────────────────────────────
export interface DiarySearchResult {
    activityId: string;
    pinId: string;
    pinTitle: string;
    pinType: string;
    pinCategory: string;
    pinDirections: string;
    pinLat: number;
    pinLon: number;
    activityType: string;
    isVerified: boolean;
    lastActivity: Date;
}

export interface UserStats {
    totalActivities: number;
    totalPinsCreated: number;
    totalDiscoveries: number;
    currentStreak: number;
    longestStreak: number;
    badges: Badge[];
}

export interface Badge {
    id: string;
    name: string;
    description: string;
    icon: string;
    earnedAt: Date;
}
