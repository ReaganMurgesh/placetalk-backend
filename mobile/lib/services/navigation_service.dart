
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class NavigationService {
  final Dio _dio = Dio();

  /// Navigate to pin using external maps app (Google Maps preferred)
  static Future<bool> navigateToPin({
    required double pinLat,
    required double pinLon,
    required String pinTitle,
  }) async {
    try {
      print('🗺️ NavigationService: Opening maps navigation to $pinTitle');
      
      // Try Google Maps with walking directions
      final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$pinLat,$pinLon&travelmode=walking'
      );
      
      if (await canLaunchUrl(googleMapsUrl)) {
        print('✅ NavigationService: Launching Google Maps');
        return await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      }
      
      // Fallback to generic geo URL
      final fallbackUrl = Uri.parse('geo:$pinLat,$pinLon?q=$pinLat,$pinLon($pinTitle)');
      if (await canLaunchUrl(fallbackUrl)) {
        print('✅ NavigationService: Launching fallback maps');
        return await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
      
      print('❌ NavigationService: No maps app available');
      return false;
    } catch (e) {
      print('❌ NavigationService: Error launching maps - $e');
      return false;
    }
  }
  
  /// Calculate distance between two points in meters
  static double calculateDistance({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) {
    return Geolocator.distanceBetween(startLat, startLon, endLat, endLon);
  }
  
  /// Check if user is near a pin (within threshold)
  static bool isNearPin({
    required double userLat,
    required double userLon,
    required double pinLat,
    required double pinLon,
    double thresholdMeters = 10.0, // 10m threshold for "reaching" pin
  }) {
    final distance = calculateDistance(
      startLat: userLat,
      startLon: userLon,
      endLat: pinLat,
      endLon: pinLon,
    );
    return distance <= thresholdMeters;
  }
  
  /// Format distance for display
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m away';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km away';
    }
  }
  final String _baseUrl = 'http://router.project-osrm.org/route/v1/walking';

  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    try {
      // OSRM expects: /lon,lat;lon,lat
      final startStr = '${start.longitude},${start.latitude}';
      final endStr = '${end.longitude},${end.latitude}';
      
      final url = '$_baseUrl/$startStr;$endStr?overview=full&geometries=polyline';

      print('🗺️ Fetching route: $url');
      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final encodedPolyline = data['routes'][0]['geometry'];
          
          // Decode polyline manual implementation (Google format)
          return _decodePolyline(encodedPolyline);
        }
      }
      return [];
    } catch (e) {
      print('❌ Error fetching route: $e');
      return [];
    }
  }

  /// Decodes an encoded polyline string into a list of LatLng points.
  /// Algorithm: Google Maps Polyline Encoding Algorithm
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}
