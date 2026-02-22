/**
 * User-Pin Interaction for Serendipity Notifications
 * Tracks per-user mute status and cooldown timers
 */
export interface UserPinInteraction {
    userId: string;
    pinId: string;
    lastSeenAt: Date;
    nextNotifyAt?: Date | null;
    isMuted: boolean;
    createdAt: Date;
    updatedAt: Date;
}

export interface CreatePinDTO {
    title: string;
    directions: string;
    details?: string;
    lat: number;
    lon: number;
    type: 'location' | 'sensation';
    pinCategory: 'normal' | 'community' | 'paid';
    attributeId?: string;
    visibleFrom?: string;
    visibleTo?: string;
    externalLink?: string;
    chatEnabled?: boolean;
    isPrivate?: boolean;  // spec 2.3: Paid/restricted visibility
    communityId?: string; // spec 3: link to a specific community
}

export interface UpdatePinDTO {
    title?: string;
    directions?: string;
    details?: string;
    externalLink?: string;
    chatEnabled?: boolean;
    // lat/lon deliberately excluded — pins cannot be relocated after drop
    userLat: number; // caller's current coordinates for 50m permission check
    userLon: number;
}

export interface PinResponse {
    id: string;
    title: string;
    directions: string;
    details?: string;
    lat: number;
    lon: number;
    type: string;
    pinCategory: string;
    attributeId?: string;
    createdBy: string;
    expiresAt: Date | null;
    likeCount: number;
    dislikeCount: number;
    createdAt: Date;
    externalLink?: string;
    chatEnabled: boolean;
    isPrivate: boolean;
    communityId?: string; // spec 3
    /** Snapshot of creator's nickname + bio at creation time */
    creatorSnapshot: { nickname?: string; bio?: string };
}
