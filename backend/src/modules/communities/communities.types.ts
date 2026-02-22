// ── communities.types.ts ─────────────────────────────────────────────────────

export type CommunityType = 'open' | 'invite_only' | 'paid_restricted';

export interface Community {
    id: string;
    name: string;
    description?: string;
    imageUrl?: string;
    createdBy: string;
    communityType: CommunityType;   // spec 3.2
    likeCount: number;              // spec 3.4
    createdAt: Date;
    updatedAt: Date;
    // Viewer-specific fields (populated when userId is provided)
    likedByMe?: boolean;
    isMember?: boolean;
    memberCount?: number;
    // Per-member settings (populated for joined communities)
    notificationsOn?: boolean;      // spec 3.3
    hometownNotify?: boolean;       // spec 3.3 step 3
    isHidden?: boolean;             // spec 3.4
    hideMapPins?: boolean;          // spec 3.4
}

export interface CommunityMember {
    communityId: string;
    userId: string;
    role: 'member' | 'admin';
    joinedAt: Date;
    notificationsOn: boolean;
    hometownNotify: boolean;
    isHidden: boolean;
    hideMapPins: boolean;
}

export interface CommunityInvite {
    id: string;
    communityId: string;
    code: string;
    createdBy: string;
    expiresAt: Date;
    useCount: number;
    createdAt: Date;
}

export interface CommunityMessage {
    id: string;
    communityId: string;
    userId: string;
    content: string;
    imageUrl?: string;
    reactions: Record<string, string[]>;  // {"👍": ["user1", "user2"]}
    createdAt: Date;
}

// Feed item: a pin associated with this community (spec 3.1)
export interface CommunityFeedItem {
    pinId: string;
    title: string;
    directions: string;
    pinType: string;
    pinCategory: string;
    createdBy: string;
    lat: number;
    lon: number;
    likeCount: number;
    externalLink?: string;
    chatEnabled: boolean;
    createdAt: Date;
    chatLastAt?: Date;
    feedUpdatedAt: Date; // max(createdAt, chatLastAt) — feed sort key
}

export interface CreateCommunityDTO {
    name: string;
    description?: string;
    imageUrl?: string;
    communityType?: CommunityType;  // spec 3.2: default 'open'
}

export interface PostMessageDTO {
    content: string;
    imageUrl?: string;
}

export interface AddReactionDTO {
    emoji: string;
}

export interface UpdateMemberSettingsDTO {
    notificationsOn?: boolean;
    hometownNotify?: boolean;
    isHidden?: boolean;
    hideMapPins?: boolean;
}

export interface ReportCommunityDTO {
    reason: string;
}
