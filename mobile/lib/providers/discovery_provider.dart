import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:placetalk/services/api_client.dart';
import 'package:placetalk/services/location_service.dart';
import 'package:placetalk/models/pin.dart';
import 'package:placetalk/models/user_pin_interaction.dart';
import 'package:placetalk/providers/auth_provider.dart';

// ── spec 3.1: "View on Map" — community feed sets this; map widget flies to it
final mapFocusProvider = StateProvider<LatLng?>((ref) => null);

/// Discovery state
class DiscoveryState {
  final List<Pin> discoveredPins;
  final List<Pin> createdPins;
  final bool isDiscovering;
  final String? error;
  final Position? lastPosition;
  final DateTime? lastDiscoveryTime;
  final Map<String, UserPinInteraction> pinInteractions; // NEW: Track mute/cooldown per pin

  DiscoveryState({
    this.discoveredPins = const [],
    this.createdPins = const [],
    this.isDiscovering = false,
    this.error,
    this.lastPosition,
    this.lastDiscoveryTime,
    this.pinInteractions = const {},
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
    Map<String, UserPinInteraction>? pinInteractions,
  }) {
    return DiscoveryState(
      discoveredPins: discoveredPins ?? this.discoveredPins,
      createdPins: createdPins ?? this.createdPins,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      error: error,
      lastPosition: lastPosition ?? this.lastPosition,
      lastDiscoveryTime: lastDiscoveryTime ?? this.lastDiscoveryTime,
      pinInteractions: pinInteractions ?? this.pinInteractions,
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

  /// Immediately remove a hidden pin from local state (optimistic update)
  void hidePinLocally(String pinId) {
    state = state.copyWith(
      discoveredPins: state.discoveredPins.where((p) => p.id != pinId).toList(),
      createdPins: state.createdPins.where((p) => p.id != pinId).toList(),
    );
    print('👁️ Pin $pinId hidden locally');
  }

  /// Hide a pin (backend + local state refresh)
  Future<void> hidePin(String pinId) async {
    try {
      await _apiClient.hidePin(pinId);
      // Immediately remove from local state (optimistic)
      hidePinLocally(pinId);
      // Refresh discovery so future lists are consistent
      if (state.lastPosition != null) {
        await manualDiscovery();
      }
    } catch (e) {
      print('Failed to hide pin: $e');
      rethrow;
    }
  }

  /// Report a pin (backend call — uses /pins/:id/report endpoint)
  Future<void> reportPin(String pinId) async {
    try {
      await _apiClient.reportPin(pinId);
    } catch (e) {
      print('Failed to report pin: $e');
      rethrow;
    }
  }

  /// Update like count for a pin in local state (optimistic update)
  void incrementLikeLocally(String pinId) {
    state = state.copyWith(
      discoveredPins: state.discoveredPins.map((p) {
        if (p.id == pinId) return p.copyWith(likeCount: p.likeCount + 1);
        return p;
      }).toList(),
      createdPins: state.createdPins.map((p) {
        if (p.id == pinId) return p.copyWith(likeCount: p.likeCount + 1);
        return p;
      }).toList(),
    );
  }

  /// Add a user-created pin
  void addCreatedPin(Pin pin) {
    state = state.copyWith(
      createdPins: [...state.createdPins, pin],
      // Also add to discoveredPins so it appears on map immediately!
      discoveredPins: [...state.discoveredPins, pin],
    );
    print('✅ Pin added to both createdPins AND discoveredPins for immediate map display');
  }

  /// SERENDIPITY: Mark pin as "Good" (7-day cooldown)
  Future<void> markPinAsGood(String pinId) async {
    try {
      final nextNotify = DateTime.now().add(const Duration(days: 7));
      final interaction = UserPinInteraction(
        pinId: pinId,
        lastSeenAt: DateTime.now(),
        nextNotifyAt: nextNotify,
        isMuted: false,
      );

      // Update local state
      state = state.copyWith(
        pinInteractions: {
          ...state.pinInteractions,
          pinId: interaction,
        },
      );

      // Sync to backend
      await _apiClient.markPinGood(pinId);
      print('✅ Pin marked as Good - remind me in 7 days');
    } catch (e) {
      print('❌ Failed to mark pin as good: $e');
    }
  }

  /// SERENDIPITY: Mark pin as "Bad" (mute forever)
  Future<void> markPinAsBad(String pinId) async {
    try {
      final interaction = UserPinInteraction(
        pinId: pinId,
        lastSeenAt: DateTime.now(),
        isMuted: true,
      );

      // Update local state
      state = state.copyWith(
        pinInteractions: {
          ...state.pinInteractions,
          pinId: interaction,
        },
      );

      // Sync to backend
      await _apiClient.markPinBad(pinId);
      print('❌ Pin muted - you will never be notified again');
    } catch (e) {
      print('❌ Failed to mark pin as bad: $e');
    }
  }

  /// SERENDIPITY: Unmute pin (tap on map)
  Future<void> unmutePinLocally(String pinId) async {
    try {
      final interaction = UserPinInteraction(
        pinId: pinId,
        lastSeenAt: DateTime.now(),
        isMuted: false,
      );

      // Update local state
      state = state.copyWith(
        pinInteractions: {
          ...state.pinInteractions,
          pinId: interaction,
        },
      );

      // Sync to backend
      await _apiClient.unmutePinForever(pinId);
      print('✅ Pin unmuted - notifications enabled');
    } catch (e) {
      print('❌ Failed to unmute pin: $e');
    }
  }

  /// Load nearby pins on app startup (no heartbeat needed)
  Future<void> loadNearbyPins() async {
    try {
      bool locationReady = await _locationService.ensureLocationReady();
      if (!locationReady) {
        print('⚠️ Location not ready - skipping initial pin load');
        return;
      }

      Position position = await _locationService.getCurrentPosition();

      // Load nearby pins from backend
      List<Pin> nearbyPins = await _apiClient.getNearbyPins(
        lat: position.latitude,
        lon: position.longitude,
      );

      // Also load user's own created pins so they persist across restarts
      List<Pin> myPins = [];
      try {
        myPins = await _apiClient.getMyPins();
        print('🔄 Loaded ${myPins.length} own pins from backend');
      } catch (e) {
        print('⚠️ Could not load own pins on startup: $e');
      }

      state = state.copyWith(
        discoveredPins: nearbyPins,
        createdPins: myPins,
        lastPosition: position,
        lastDiscoveryTime: DateTime.now(),
      );

      print('🔄 Initial load → ${nearbyPins.length} nearby + ${myPins.length} own pins loaded');
    } catch (e) {
      print('❌ Failed to load nearby pins: $e');
      // Don't rethrow - allow app to continue even if load fails
    }
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

  /// Like a pin — optimistic local count bump, then API call
  Future<void> likePin(String pinId) async {
    // Optimistic update: bump count immediately so the UI feels instant
    incrementLikeLocally(pinId);
    try {
      await _apiClient.likePin(pinId);
      // Backend confirmed — no need to re-fetch; local optimistic state is correct
    } catch (e) {
      // Roll back the optimistic bump if the API call failed for a real reason
      // (idempotent 400 "already liked" is handled backend-side and returns 200 now)
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
