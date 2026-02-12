export interface RegisterDTO {
    name: string;
    email: string;
    password: string;
    role: 'normal' | 'community';
    homeRegion?: string;
    country?: string;
}

export interface LoginDTO {
    email: string;
    password: string;
}

export interface UserResponse {
    id: string;
    name: string;
    email: string;
    role: string;
    homeRegion?: string;
    country: string;
    createdAt: Date;
}

export interface AuthTokens {
    accessToken: string;
    refreshToken: string;
}
