import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:placetalk/providers/discovery_provider.dart';
import 'package:placetalk/services/notification_service.dart';
import 'package:placetalk/services/location_service.dart';

/// Proximity tracking service provider
final proximityTrackingProvider =
    StateNotifierProvider<ProximityTracker, ProximityState>((ref) {
  return ProximityTracker(
    ref.read(notificationServiceProvider),
    ref.read(locationServiceProvider),
    ref,
  );
});

class ProximityState {
  final Set<String> notifiedPinIds;
  final int checkCount;
  final Position? lastPosition;

  ProximityState({
    this.notifiedPinIds = const {},
    this.checkCount = 0,
    this.lastPosition,
  });

  ProximityState copyWith({
    Set<String>? notifiedPinIds,
    int? checkCount,
    Position? lastPosition,
  }) {
    return ProximityState(
      notifiedPinIds: notifiedPinIds ?? this.notifiedPinIds,
      checkCount: checkCount ?? this.checkCount,
      lastPosition: lastPosition ?? this.lastPosition,
    );
  }
}

class ProximityTracker extends StateNotifier<ProximityState> {
  final NotificationService _notificationService;
  final LocationService _locationService;
  final Ref _ref;
  StreamSubscription<Position>? _positionStream;

  ProximityTracker(this._notificationService, this._locationService, this._ref)
      : super(ProximityState()) {
    _startRealTimeTracking();
  }

  /// Start real-time GPS tracking and proximity checks
  void _startRealTimeTracking() async {
    try {
      // Get continuous position updates
      _positionStream = _locationService.getPositionStream().listen(
        (position) {
          state = state.copyWith(lastPosition: position);
          _checkProximity(position);
        },
        onError: (error) {
          print('❌ GPS stream error: $error');
        },
      );
      
      print('✅ Real-time proximity tracking started');
    } catch (e) {
      print('❌ Failed to start proximity tracking: $e');
    }
  }

  /// Check proximity to all discovered pins on EVERY GPS update
  Future<void> _checkProximity(Position userPosition) async {
    try {
      final discoveryState = _ref.read(discoveryProvider);
      final pins = discoveryState.discoveredPins;

      if (pins.isEmpty) return;

      for (final pin in pins) {
        final distance = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          pin.lat,
          pin.lon,
        );

        // If within 50m and not already notified
        if (distance <= 50 && !state.notifiedPinIds.contains(pin.id)) {
          await _notificationService.showProximityAlert(
            pinId: pin.id,
            pinTitle: pin.title,
            distanceMeters: distance,
          );

          // Mark as notified
          state = state.copyWith(
            notifiedPinIds: {...state.notifiedPinIds, pin.id},
            checkCount: state.checkCount + 1,
          );

          print('🔔 Proximity alert sent: ${pin.title} at ${distance.toStringAsFixed(0)}m');
        }

        // If moved away (>100m), clear notification state
        if (distance > 100 && state.notifiedPinIds.contains(pin.id)) {
          state = state.copyWith(
            notifiedPinIds: state.notifiedPinIds.where((id) => id != pin.id).toSet(),
          );
          print('🔕 Moved away from: ${pin.title}');
        }
      }
    } catch (e) {
      print('❌ Proximity check error: $e');
    }
  }

  /// Force an immediate proximity check
  Future<void> checkNow() async {
    if (state.lastPosition != null) {
      await _checkProximity(state.lastPosition!);
    }
  }

  /// Reset all notification states
  void reset() {
    state = ProximityState();
    _notificationService.cancelAll();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
}
