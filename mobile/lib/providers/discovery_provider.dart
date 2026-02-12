import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:placetalk/services/api_client.dart';
import 'package:placetalk/services/location_service.dart';
import 'package:placetalk/models/pin.dart';
import 'package:placetalk/providers/auth_provider.dart';

/// Discovery state
class DiscoveryState {
  final List<Pin> discoveredPins;
  final List<Pin> createdPins;
  final bool isDiscovering;
  final String? error;
  final Position? lastPosition;
  final DateTime? lastDiscoveryTime;

  DiscoveryState({
    this.discoveredPins = const [],
    this.createdPins = const [],
    this.isDiscovering = false,
    this.error,
    this.lastPosition,
    this.lastDiscoveryTime,
  });

  // All pins (discovered + created)
  List<Pin> get allPins => [...discoveredPins, ...createdPins];

  DiscoveryState copyWith({
    List<Pin>? discoveredPins,
    List<Pin>? createdPins,
    bool? isDiscovering,
    String? error,
    Position? lastPosition,
    DateTime? lastDiscoveryTime,
  }) {
    return DiscoveryState(
      discoveredPins: discoveredPins ?? this.discoveredPins,
      createdPins: createdPins ?? this.createdPins,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      error: error,
      lastPosition: lastPosition ?? this.lastPosition,
      lastDiscoveryTime: lastDiscoveryTime ?? this.lastDiscoveryTime,
    );
  }
}

/// Discovery provider
final discoveryProvider = StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
  return DiscoveryNotifier(
    ref.read(apiClientProvider),
    ref.read(locationServiceProvider),
  );
});

class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  final ApiClient _apiClient;
  final LocationService _locationService;

  DiscoveryNotifier(this._apiClient, this._locationService)
      : super(DiscoveryState());

  /// Send heartbeat to backend and discover nearby pins
  Future<void> sendHeartbeat() async {
    state = state.copyWith(isDiscovering: true, error: null);

    try {
      bool locationReady = await _locationService.ensureLocationReady();
      if (!locationReady) {
        throw Exception('Location services not available');
      }

      Position position = await _locationService.getCurrentPosition();

      // Send to real backend — fully backend-dependent
      List<Pin> discoveredPins = await _apiClient.sendHeartbeat(
        lat: position.latitude,
        lon: position.longitude,
      );

      state = state.copyWith(
        discoveredPins: discoveredPins,
        isDiscovering: false,
        lastPosition: position,
        lastDiscoveryTime: DateTime.now(),
      );

      _locationService.updateLastPosition(position);

      print('✅ Heartbeat sent → ${discoveredPins.length} pins discovered');
    } catch (e) {
      state = state.copyWith(
        isDiscovering: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Manual discovery check (Discover button)
  /// Fully backend-dependent — no demo pins
  Future<void> manualDiscovery() async {
    state = state.copyWith(isDiscovering: true, error: null);

    try {
      Position position = await _locationService.getCurrentPosition();
      
      // Real API call — backend handles geohash → Redis → PostGIS filtering
      List<Pin> discoveredPins = await _apiClient.sendHeartbeat(
        lat: position.latitude,
        lon: position.longitude,
      );
      
      state = state.copyWith(
        isDiscovering: false,
        lastPosition: position,
        discoveredPins: discoveredPins,
        lastDiscoveryTime: DateTime.now(),
      );

      _locationService.updateLastPosition(position);
      
      print('📡 Discovery → ${discoveredPins.length} pins found at ${position.latitude}, ${position.longitude}');
    } catch (e) {
      state = state.copyWith(
        isDiscovering: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Add a user-created pin
  void addCreatedPin(Pin pin) {
    state = state.copyWith(
      createdPins: [...state.createdPins, pin],
    );
  }

  /// Get pins within range of user position (client-side filter for display)
  List<Pin> getPinsInRange({
    required Position userPosition,
    double maxDistanceMeters = 50.0,
  }) {
    final allPins = state.allPins;
    return allPins.where((pin) {
      final distance = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        pin.lat,
        pin.lon,
      );
      return distance <= maxDistanceMeters;
    }).toList();
  }

  /// Like a pin
  Future<void> likePin(String pinId) async {
    try {
      await _apiClient.likePin(pinId);
      // Refresh discovery after interaction
      if (state.lastPosition != null) {
        await manualDiscovery();
      }
    } catch (e) {
      print('Failed to like pin: $e');
      rethrow;
    }
  }

  /// Dislike a pin
  Future<void> dislikePin(String pinId) async {
    try {
      await _apiClient.dislikePin(pinId);
      if (state.lastPosition != null) {
        await manualDiscovery();
      }
    } catch (e) {
      print('Failed to dislike pin: $e');
      rethrow;
    }
  }

  /// Update position without heartbeat (for GPS tracking display)
  void updatePosition(Position position) {
    state = state.copyWith(lastPosition: position);
  }

  /// Get nearby pins from backend
  Future<void> getNearbyPins() async {
    state = state.copyWith(isDiscovering: true, error: null);

    try {
      bool locationReady = await _locationService.ensureLocationReady();
      if (!locationReady) {
        throw Exception('Location services not available');
      }

      Position position = await _locationService.getCurrentPosition();

      List<Pin> discoveredPins = await _apiClient.getNearbyPins(
        lat: position.latitude,
        lon: position.longitude,
      );

      state = state.copyWith(
        discoveredPins: discoveredPins,
        isDiscovering: false,
        lastPosition: position,
      );
    } catch (e) {
      state = state.copyWith(
        isDiscovering: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Clear discovered pins
  void clearDiscoveredPins() {
    state = state.copyWith(discoveredPins: []);
  }

  /// Add a pin to discovered list
  void addDiscoveredPin(Pin pin) {
    state = state.copyWith(
      discoveredPins: [...state.discoveredPins, pin],
    );
  }
}
