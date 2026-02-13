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
    updated At: Date;
}

export interface CreatePinDTO {
    title: string;
    directions: string;
    details?: string;
    lat: number;
    lon: number;
    type: 'location' | 'sensation';
    pinCategory: 'normal' | 'community';
    attributeId?: string;
    visibleFrom?: string; // "HH:MM" format
    visibleTo?: string;   // "HH:MM" format
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
    expiresAt: Date;
    likeCount: number;
    dislikeCount: number;
    createdAt: Date;
}
