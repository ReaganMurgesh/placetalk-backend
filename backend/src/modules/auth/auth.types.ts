export interface RegisterDTO {
    name: string;
    email: string;
    password: string;
    role: 'normal' | 'community';
    homeRegion?: string;
    country?: string;
    /** Max 20 chars */
    nickname?: string;
    /** Max 15 chars */
    bio?: string;
    /** Max 15 alphanumeric chars; unique display handle */
    username?: string;
}

export interface LoginDTO {
    email: string;
    password: string;
}

/** PATCH /auth/profile */
export interface UpdateProfileDTO {
    /** Max 20 chars */
    nickname?: string;
    /** Max 15 chars */
    bio?: string;
    /** Max 15 alphanumeric; unique display handle */
    username?: string;
}

export interface UserResponse {
    id: string;
    name: string;
    email: string;
    role: string;
    homeRegion?: string;
    country: string;
    createdAt: Date;
    nickname?: string;
    bio?: string;
    username?: string;
    isB2bPartner: boolean;
}

export interface AuthTokens {
    accessToken: string;
    refreshToken: string;
}
