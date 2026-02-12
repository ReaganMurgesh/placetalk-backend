import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Location service provider
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class LocationService {
  Position? _lastPosition;
  
  /// Get current position
  Future<Position> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Check if we have permission to access location
  Future<bool> hasPermission() async {
    LocationPermission permission = await checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
    }
    
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Ensure location services and permissions are ready
  Future<bool> ensureLocationReady() async {
    // Check if location services are enabled
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Check permissions
    return await hasPermission();
  }

  /// Check if user has moved significantly (>20m) since last check
  Future<bool> hasMovedSignificantly(Position currentPosition) async {
    if (_lastPosition == null) {
      _lastPosition = currentPosition;
      return true; // First time, consider it as moved
    }

    double distanceInMeters = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );

    // Movement threshold: 20 meters
    const double movementThreshold = 20.0;

    if (distanceInMeters >= movementThreshold) {
      _lastPosition = currentPosition;
      return true;
    }

    return false;
  }

  /// Update last known position
  void updateLastPosition(Position position) {
    _lastPosition = position;
  }

  /// Get distance between two coordinates in meters
  double getDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Get continuous position stream with highest accuracy
  Stream<Position> getPositionStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, // HIGHEST accuracy
      distanceFilter: 1, // Update every 1 METER!
      timeLimit: Duration(seconds: 30),
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
