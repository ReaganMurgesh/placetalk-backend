import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:placetalk/services/location_service.dart';
import 'package:placetalk/services/api_client.dart';
import 'package:placetalk/providers/auth_provider.dart';

/// Background GPS tracking state
class TrackingState {
  final bool isTracking;
  final Position? currentPosition;
  final DateTime? lastHeartbeat;
  final int discoveryCount;

  TrackingState({
    this.isTracking = false,
    this.currentPosition,
    this.lastHeartbeat,
    this.discoveryCount = 0,
  });

  TrackingState copyWith({
    bool? isTracking,
    Position? currentPosition,
    DateTime? lastHeartbeat,
    int? discoveryCount,
  }) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      currentPosition: currentPosition ?? this.currentPosition,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      discoveryCount: discoveryCount ?? this.discoveryCount,
    );
  }
}

/// Background tracking provider
final backgroundTrackingProvider =
    StateNotifierProvider<BackgroundTrackingNotifier, TrackingState>((ref) {
  return BackgroundTrackingNotifier(
    ref.read(locationServiceProvider),
    ref.read(apiClientProvider),
  );
});

class BackgroundTrackingNotifier extends StateNotifier<TrackingState> {
  final LocationService _locationService;
  final ApiClient _apiClient;
  StreamSubscription<Position>? _positionStream;

  BackgroundTrackingNotifier(this._locationService, this._apiClient)
      : super(TrackingState());

  /// Start background GPS tracking
  Future<void> startTracking() async {
    // Ensure location is ready
    bool ready = await _locationService.ensureLocationReady();
    if (!ready) {
      throw Exception('Location services not available');
    }

    // Get position stream
    _positionStream = _locationService.getPositionStream().listen(
      (Position position) async {
        // Update current position
        state = state.copyWith(currentPosition: position);

        // Check if moved significantly (20m threshold)
        bool hasMoved = await _locationService.hasMovedSignificantly(position);

        if (hasMoved) {
          // Send heartbeat
          await _sendHeartbeat(position);
        }
      },
      onError: (error) {
        print('GPS tracking error: $error');
      },
    );

    state = state.copyWith(isTracking: true);
  }

  /// Stop background GPS tracking
  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    state = state.copyWith(isTracking: false);
  }

  /// Send heartbeat to backend
  Future<void> _sendHeartbeat(Position position) async {
    try {
      final discoveredPins = await _apiClient.sendHeartbeat(
        lat: position.latitude,
        lon: position.longitude,
      );

      state = state.copyWith(
        lastHeartbeat: DateTime.now(),
        discoveryCount: state.discoveryCount + discoveredPins.length,
      );

      // TODO: Show notification if pins discovered
      if (discoveredPins.isNotEmpty) {
        print('Discovered ${discoveredPins.length} pins!');
        // _showDiscoveryNotification(discoveredPins);
      }
    } catch (e) {
      print('Heartbeat failed: $e');
    }
  }

  /// Manual heartbeat (for testing)
  Future<void> sendManualHeartbeat() async {
    if (state.currentPosition != null) {
      await _sendHeartbeat(state.currentPosition!);
    }
  }
}
