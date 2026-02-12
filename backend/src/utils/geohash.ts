import geohash from 'ngeohash';

/**
 * Encode latitude and longitude into a geohash string
 * @param lat Latitude (-90 to 90)
 * @param lon Longitude (-180 to 180)
 * @param precision Geohash precision (1-12, default 7)
 * @returns Geohash string
 */
export function encodeGeohash(lat: number, lon: number, precision: number = 7): string {
    if (lat < -90 || lat > 90) {
        throw new Error('Latitude must be between -90 and 90');
    }
    if (lon < -180 || lon > 180) {
        throw new Error('Longitude must be between -180 and 180');
    }
    if (precision < 1 || precision > 12) {
        throw new Error('Precision must be between 1 and 12');
    }

    return geohash.encode(lat, lon, precision);
}

/**
 * Decode geohash string into latitude and longitude
 * @param hash Geohash string
 * @returns {lat, lon} coordinates
 */
export function decodeGeohash(hash: string): { lat: number; lon: number } {
    const decoded = geohash.decode(hash);
    return { lat: decoded.latitude, lon: decoded.longitude };
}

/**
 * Get all neighboring geohashes (8 surrounding cells + center)
 * Useful for expanding search area
 * @param hash Geohash string
 * @returns Array of 9 geohashes (center + 8 neighbors)
 */
export function getNeighbors(hash: string): string[] {
    const neighbors = geohash.neighbors(hash);
    return [
        hash, // center
        ...Object.values(neighbors), // 8 neighbors
    ];
}

/**
 * Calculate approximate bounding box size at different geohash precisions
 * Precision 7 ≈ 153m × 153m grid (good for 50m radius discovery)
 */
export const GEOHASH_PRECISION_INFO = {
    1: { width: 5000, height: 5000, unit: 'km' },
    2: { width: 1250, height: 625, unit: 'km' },
    3: { width: 156, height: 156, unit: 'km' },
    4: { width: 39.1, height: 19.5, unit: 'km' },
    5: { width: 4.89, height: 4.89, unit: 'km' },
    6: { width: 1.22, height: 0.61, unit: 'km' },
    7: { width: 153, height: 153, unit: 'm' },  // ← Recommended for 50m discovery
    8: { width: 38.2, height: 19.1, unit: 'm' },
    9: { width: 4.77, height: 4.77, unit: 'm' },
    10: { width: 1.19, height: 0.596, unit: 'm' },
    11: { width: 149, height: 149, unit: 'mm' },
    12: { width: 37.2, height: 18.6, unit: 'mm' },
};

/**
 * Calculate distance between two points using Haversine formula
 * @param lat1 First point latitude
 * @param lon1 First point longitude
 * @param lat2 Second point latitude
 * @param lon2 Second point longitude
 * @returns Distance in meters
 */
export function calculateDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number
): number {
    const R = 6371e3; // Earth radius in meters
    const φ1 = (lat1 * Math.PI) / 180;
    const φ2 = (lat2 * Math.PI) / 180;
    const Δφ = ((lat2 - lat1) * Math.PI) / 180;
    const Δλ = ((lon2 - lon1) * Math.PI) / 180;

    const a =
        Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
        Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c; // Distance in meters
}
