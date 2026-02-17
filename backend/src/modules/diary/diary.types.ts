export interface UserActivity {
    id: string;
    userId: string;
    pinId: string;
    activityType: 'visited' | 'liked' | 'commented' | 'created' | 'reported' | 'hidden';
    metadata?: Record<string, any>;
    createdAt: Date;
}

export interface TimelineEntry extends UserActivity {
    pinTitle: string;
    pinAttribute?: string;
    pinLat: number;
    pinLon: number;
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
