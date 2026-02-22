export interface DiscoveryHeartbeatDTO {
    userId: string;
    lat: number;
    lon: number;
}

export interface DiscoveredPin {
    id: string;
    title: string;
    directions: string;
    details?: string;
    lat: number;
    lon: number;
    distance: number; // meters
    type: 'location' | 'sensation';
    pinCategory: 'normal' | 'community';
    attributeId?: string;
    createdBy: string;
    likeCount: number;
    dislikeCount: number;
    createdAt: string;
    isHidden: boolean;
    isDeprioritized: boolean;
    /** Creator display snapshot (nickname + bio) */
    creatorSnapshot: { nickname?: string; bio?: string };
}

export interface DiscoveryResponse {
    discovered: DiscoveredPin[];
    count: number;
    timestamp: Date;
}
