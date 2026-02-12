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
    distance: number; // meters
    type: 'location' | 'sensation';
    pinCategory: 'normal' | 'community';
    attributeId?: string;
    createdBy: string;
}

export interface DiscoveryResponse {
    discovered: DiscoveredPin[];
    count: number;
    timestamp: Date;
}
