import 'package:dio/dio.dart';
import 'package:placetalk/core/config/api_config.dart';

/// Human-readable address from reverse geocoding
class GeocodedAddress {
  final String display; // Short form: "Road Name, Neighbourhood"
  final String? road;
  final String? neighbourhood;
  final String? city;
  final String? country;

  const GeocodedAddress({
    required this.display,
    this.road,
    this.neighbourhood,
    this.city,
    this.country,
  });

  @override
  String toString() => display;
}

/// LocationIQ reverse geocoding service (free tier: 5,000 req/day)
///
/// Get your free key at: https://locationiq.com/register
/// Then paste it into ApiConfig.locationIqKey
class GeocodingService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
    baseUrl: 'https://us1.locationiq.com/v1',
  ));

  // In-memory cache keyed by "lat4,lon4" (rounded to 4 decimals ≈ 11m precision)
  static final Map<String, GeocodedAddress?> _cache = {};

  static String _key(double lat, double lon) =>
      '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';

  /// Returns the best 1–2 component short address from a raw address map.
  static String _shortLabel(Map<String, dynamic> address) {
    final picked = <String>[];
    // Priority order — pick the two most specific fields present
    const priority = [
      'road',
      'quarter',
      'neighbourhood',
      'suburb',
      'village',
      'hamlet',
      'town',
      'city_district',
      'city',
      'municipality',
      'county',
    ];
    for (final field in priority) {
      final v = address[field] as String?;
      if (v != null && v.isNotEmpty && !picked.contains(v)) {
        picked.add(v);
        if (picked.length >= 2) break;
      }
    }
    return picked.join(', ');
  }

  /// Reverse geocode a lat/lon to a human-readable address.
  ///
  /// Returns `null` if:
  /// - [ApiConfig.locationIqKey] is empty (not configured)
  /// - The network request fails
  /// - LocationIQ returns an error
  ///
  /// Results are cached in-memory; identical coordinates won't re-fetch.
  static Future<GeocodedAddress?> reverseGeocode(double lat, double lon) async {
    if (ApiConfig.locationIqKey.isEmpty) return null;

    final cacheKey = _key(lat, lon);
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final resp = await _dio.get('/reverse', queryParameters: {
        'key': ApiConfig.locationIqKey,
        'lat': lat,
        'lon': lon,
        'format': 'json',
      });

      final data = resp.data as Map<String, dynamic>;
      final address = (data['address'] as Map<String, dynamic>?) ?? {};

      final short = _shortLabel(address);
      final result = GeocodedAddress(
        display: short.isNotEmpty
            ? short
            : (data['display_name'] as String? ?? 'Unknown location'),
        road: address['road'] as String?,
        neighbourhood: (address['neighbourhood'] ??
            address['quarter'] ??
            address['suburb']) as String?,
        city: (address['city'] ??
            address['town'] ??
            address['municipality']) as String?,
        country: address['country'] as String?,
      );

      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      print('⚠️ GeocodingService: reverseGeocode failed — $e');
      _cache[cacheKey] = null;
      return null;
    }
  }

  /// Forward geocode: search a place name → LatLng.
  /// Uses LocationIQ /search endpoint (same free API key).
  /// Returns null if not found or API key not set.
  static Future<dynamic> forwardGeocode(String query) async {
    if (ApiConfig.locationIqKey.isEmpty || query.trim().isEmpty) return null;
    try {
      final resp = await _dio.get('/search', queryParameters: {
        'key': ApiConfig.locationIqKey,
        'q': query.trim(),
        'format': 'json',
        'limit': 1,
      });
      final data = resp.data;
      if (data is List && data.isNotEmpty) {
        final first = data[0] as Map<String, dynamic>;
        final lat = double.tryParse(first['lat']?.toString() ?? '');
        final lon = double.tryParse(first['lon']?.toString() ?? '');
        if (lat != null && lon != null) {
          // Return as a Map so callers don't need to import latlong2 here
          return {'lat': lat, 'lon': lon};
        }
      }
      return null;
    } catch (e) {
      print('\u26a0\ufe0f GeocodingService: forwardGeocode failed — \$e');
      return null;
    }
  }

  /// Clear the in-memory cache (useful after key change)
  static void clearCache() => _cache.clear();
}
