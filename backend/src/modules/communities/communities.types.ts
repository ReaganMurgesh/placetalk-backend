export interface Community {
    id: string;
    name: string;
    description?: string;
    imageUrl?: string;
    createdBy: string;
    createdAt: Date;
    updatedAt: Date;
}

export interface CommunityMember {
    communityId: string;
    userId: string;
    joinedAt: Date;
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

export interface CreateCommunityDTO {
    name: string;
    description?: string;
    imageUrl?: string;
}

export interface PostMessageDTO {
    content: string;
    imageUrl?: string;
}

export interface AddReactionDTO {
    emoji: string;
}
