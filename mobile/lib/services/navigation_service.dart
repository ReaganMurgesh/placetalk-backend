
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class NavigationService {
  final Dio _dio = Dio();
  final PolylinePoints _polylinePoints = PolylinePoints();

  // Using OSRM Public Demo Server (Note: Not for heavy production use)
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
          
          // Decode polyline (Google format, used by OSRM)
          List<PointLatLng> points = _polylinePoints.decodePolyline(encodedPolyline);
          
          return points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ Error fetching route: $e');
      return [];
    }
  }
}
