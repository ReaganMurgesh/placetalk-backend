import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:math';
import 'package:placetalk/providers/discovery_provider.dart';
import 'package:placetalk/services/location_service.dart';
import 'package:placetalk/services/notification_service.dart';
import 'package:placetalk/models/pin.dart';
import 'package:placetalk/providers/auth_provider.dart';
import 'package:placetalk/models/community.dart';
import 'package:placetalk/services/geocoding_service.dart';
import 'package:placetalk/screens/social/community_screen.dart';
import 'package:placetalk/screens/social/diary_screen.dart';
import 'package:placetalk/services/navigation_service.dart';
import 'package:placetalk/providers/diary_provider.dart';
import 'package:placetalk/services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ==========================================================
/// POKÉMON GO STYLE MAP
/// 
/// ARCHITECTURE (why the avatar doesn't move when you drag):
///
///   ┌─ Stack ───────────────────────────┐
///   │                                    │
///   │  Layer 1 (bottom): FlutterMap      │  ← MOVES when dragged
///   │    - Map tiles                     │
///   │    - Pin markers (on map)          │
///   │                                    │
///   │  Layer 2 (top): Center widget      │  ← FIXED at screen center
///   │    - 50m radius ring               │     NEVER moves on drag
///   │    - Walking avatar                │
///   │                                    │
///   │  Layer 3 (top): UI controls        │  ← Status bar, buttons
///   │                                    │
///   └────────────────────────────────────┘
///
/// The map camera is LOCKED to GPS position.
/// Compass heading rotates the map (bearing).
/// User CAN'T freely drag the map — it auto-re-centers on GPS.
/// ==========================================================
class PokemonGoMap extends ConsumerStatefulWidget {
  const PokemonGoMap({super.key});

  @override
  ConsumerState<PokemonGoMap> createState() => _PokemonGoMapState();
}

class _PokemonGoMapState extends ConsumerState<PokemonGoMap>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<Position>? _gpsSub;
  
  double _heading = 0.0;
  LatLng? _userPosition;
  bool _followUser = true; // when false, map stays where user/manual focus put it
  Position? _lastHeartbeatPos;
  String _statusText = 'Initializing GPS...';
  bool _connectionOk = true;
  
  // Animations
  late AnimationController _pulseCtrl;
  late AnimationController _bounceCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _bounceAnim;
  
  // Navigation State
  final NavigationService _navService = NavigationService();
  List<LatLng> _navigationPath = [];
  Pin? _navTargetPin;
  bool _isNavigating = false;
  bool _arrivalHandled = false; Two-stage detection & Ghost Pins ---
  final Set<String> _autoPoppedPins = {};
  final Set<String> _nearbyButNotOpened = {};
  final Set<String> _ghostRecorded = {};

  // --- Phase 1b: Hex cloud jitter seed cache ---
  // (computed lazily per pin, cached here so marker doesn't jitter on rebuild)
  final Map<String, LatLng> _jitterCache = {};

  // --- Phase 1c: Fog of War ---
  final List<LatLng> _fogClearedPoints = [];
  LatLng? _lastFogUpdate;
  bool _fogEnabled = true;
  Timer? _fogSaveTimer; // debounce for SharedPreferences writes

  // --- 150m Hex Cloud: place name cache per hex cell key ---
  final Map<String, String> _hexPlaceNames = {};

  // --- 1.4: Creator alert socket ---
  final SocketService _creatorAlertSocket = SocketService();

  // --- Place search overlay ---
  bool _searchMode = false;

  @override
  void initState() {
    super.initState();
    
    // Pulsing glow
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    
    // Walking bounce
    _bounceCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );
    
    _initCompass();
    _initGps();
    _loadFogFromPrefs(); // load persisted explored paths

    // 1.4: Creator footprint alerts via Socket.io
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).value;
      if (user != null && mounted) {
        _creatorAlertSocket.connect();
        // Small delay so socket handshake completes before joining room
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _creatorAlertSocket.listenForCreatorAlerts(
                user.id, _onCreatorAlert);
          }
        });
      }
    });

    // Periodic heartbeat every 30s — ensures other users' pins load even when standing still
    _periodicHeartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _userPosition != null) {
        ref.read(discoveryProvider.notifier).manualDiscovery().then((_) {
          if (mounted) {
            final pins = ref.read(discoveryProvider);
            final count = {...pins.discoveredPins.map((p) => p.id), ...pins.createdPins.map((p) => p.id)}.length;
            if (count > 0) {
              setState(() {
                _statusText = '\u{1F4CD} $count pin${count != 1 ? 's' : ''} nearby!';
              });
            }
          }
        }).catchError((_) {});
      }
    });

    // Retry startup load after 5s in case Render was cold-starting
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        ref.read(discoveryProvider.notifier).loadNearbyPins();
      }
    });

    // Load existing pins from backend on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryProvider.notifier).loadNearbyPins();
    });

    // spec 3.1 "View on Map": fly camera when community feed requests a focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listen(mapFocusProvider, (_, next) {
        if (next != null && mounted) {
          // When coming from Diary search / Ghost card / Community, focus map on that pin
          // and temporarily disable GPS auto-follow until user taps My Location.
          setState(() {
            _followUser = false;
          });
          _mapController.move(next, 17.0);
          ref.read(mapFocusProvider.notifier).state = null; // one-shot trigger
        }
      });
    });
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _gpsSub?.cancel();
    _periodicHeartbeat?.cancel();
    _fogSaveTimer?.cancel();
    _creatorAlertSocket.stopCreatorAlerts();
    _creatorAlertSocket.disconnect();
    _pulseCtrl.dispose();
    _bounceCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // 1.4: Handle incoming creator_alert socket event
  Future<void> _onCreatorAlert(Map<String, dynamic> data) async {
    final pinTitle = (data['pinTitle'] ?? '') as String;
    final lat = (data['lat'] as num?)?.toDouble();
    final lon = (data['lon'] as num?)?.toDouble();
    String placeName = '';
    if (lat != null && lon != null) {
      try {
        final addr = await GeocodingService.reverseGeocode(lat, lon);
        if (addr != null) {
          placeName = addr.city ?? addr.neighbourhood ?? addr.display;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    ref.read(notificationServiceProvider).showCreatorAlert(
      pinTitle: pinTitle,
      placeName: placeName,
    );
  }

  // ──────────────────────────────────────────────
  // COMPASS: Only rotate the direction arrow dot
  // (map stays north-up, like Google Maps)
  // ──────────────────────────────────────────────
  void _initCompass() {
    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading != null && mounted) {
        setState(() { _heading = event.heading!; });
        // Do NOT rotate the map — only the avatar arrow rotates (see _buildUserDot)
      }
    });
  }

  // ──────────────────────────────────────────────
  // GPS: Track real walking movement
  // ──────────────────────────────────────────────
  void _initGps() async {
    final locSvc = ref.read(locationServiceProvider);
    final ready = await locSvc.ensureLocationReady();
    if (!ready) {
      setState(() { _statusText = '❌ Location permission denied'; });
      return;
    }
    
    // Get initial position
    try {
      final pos = await locSvc.getCurrentPosition();
      _onNewPosition(pos);
      _triggerHeartbeat(pos);
    } catch (e) {
      print('❌ Initial GPS: $e');
    }
    
    // Stream: distanceFilter=5 → only fires after 5m REAL movement
    // This prevents the avatar from "jittering" while standing still
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    
    _gpsSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position pos) {
        if (!mounted) return;
        _onNewPosition(pos);
        
          // 15m threshold (Minimalist Rule) → heartbeat to backend
        if (_lastHeartbeatPos != null) {
          final moved = Geolocator.distanceBetween(
            _lastHeartbeatPos!.latitude, _lastHeartbeatPos!.longitude,
            pos.latitude, pos.longitude,
          );
          if (moved >= 15.0) {
            _triggerHeartbeat(pos);
          }
        }

        // Navigation Arrival Check (< 20m — matches full-unlock threshold)
        if (_isNavigating && _navTargetPin != null && !_arrivalHandled) {
          final distToTarget = Geolocator.distanceBetween(
            pos.latitude, pos.longitude,
            _navTargetPin!.lat, _navTargetPin!.lon,
          );
          if (distToTarget < 20.0) {
            _arrivalHandled = true; // Prevent re-entry
            _handleArrival(_navTargetPin!);
          }
        }

        // --- Phase 1a: Two-stage auto-popup & ghost pin tracking ---
        _checkTwoStageProximity(pos);
      },
      onError: (e) => print('❌ GPS error: $e'),
    );
  }

  // ──────────────────────────────────────────────
  // TWO-STAGE PROXIMITY CHECK
  // ──────────────────────────────────────────────
  void _checkTwoStageProximity(Position pos) {
    if (!mounted) return;
    final state = ref.read(discoveryProvider);
    final Set<String> seenIds = {};
    final allPins = [...state.discoveredPins, ...state.createdPins];
    for (final pin in allPins) {
      if (seenIds.contains(pin.id)) continue;
      seenIds.add(pin.id);

      final dist = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        pin.lat, pin.lon,
      );

      if (dist <= 20.0) {
        // Mark as "was near but not opened" for ghost pin logic
        _nearbyButNotOpened.add(pin.id);

        // Auto-popup if not done yet and not navigating to this pin
        if (!_autoPoppedPins.contains(pin.id)) {
          _autoPoppedPins.add(pin.id);
          // Remove from ghost candidate since we are about to open it
          _nearbyButNotOpened.remove(pin.id);
          HapticFeedback.vibrate();
          // Brief delay so the haptic fires first
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) _showPinSheet(pin, dist, isFullyUnlocked: true);
          });
        }
      } else if (dist > 30.0) {
        // User moved away — if they were near but never opened, record ghost
        if (_nearbyButNotOpened.contains(pin.id) && !_ghostRecorded.contains(pin.id)) {
          _ghostRecorded.add(pin.id);
          _nearbyButNotOpened.remove(pin.id);
          _recordGhostPin(pin);
        }
        // Allow re-popup if they come back another time
        if (dist > 50.0) {
          _autoPoppedPins.remove(pin.id);
        }
      }
    }
  }

  // Record a ghost pin — user passed within 20m but never opened the sheet
  Future<void> _recordGhostPin(Pin pin) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.logActivity(pin.id, 'ghost_pass', metadata: {'source': 'proximity'});
      ref.invalidate(diaryTimelineProvider);
      ref.invalidate(diaryStatsProvider);
      print('👻 Ghost pin recorded for "${pin.title}"');
    } catch (e) {
      print('⚠️ Ghost pin log failed: $e');
    }
  }

  void _onNewPosition(Position pos) {
    final newPos = LatLng(pos.latitude, pos.longitude);
    setState(() { _userPosition = newPos; });
    
    // Update provider
    ref.read(discoveryProvider.notifier).updatePosition(pos);
    
    // LOCK map camera to GPS position (Pokémon GO behavior)
    // Only when follow mode is enabled; when user jumped to a diary/search pin,
    // keep the map where they put it until they tap My Location.
    if (_followUser) {
      try {
        _mapController.move(newPos, _mapController.camera.zoom);
      } catch (_) {}
    }

    // Phase 1c: record cleared fog area every 8m of movement
    if (_fogEnabled) {
      if (_lastFogUpdate == null ||
          Geolocator.distanceBetween(
            _lastFogUpdate!.latitude, _lastFogUpdate!.longitude,
            pos.latitude, pos.longitude,
          ) > 8.0) {
        setState(() {
          _fogClearedPoints.add(newPos);
          _lastFogUpdate = newPos;
        });
        _debouncedSaveFog();
      }
    }
  }

  // ──────────────────────────────────────────────
  // HEARTBEAT → Backend Discovery
  // ──────────────────────────────────────────────
  Future<void> _triggerHeartbeat(Position pos) async {
    _lastHeartbeatPos = pos;
    
    try {
      await ref.read(discoveryProvider.notifier).sendHeartbeat();
      
      final pins = ref.read(discoveryProvider).discoveredPins;
      
      setState(() {
        _connectionOk = true;
        _statusText = pins.isEmpty 
            ? '🚶 Walking... keep exploring!'
            : '📍 ${pins.length} pin${pins.length > 1 ? 's' : ''} nearby!';
      });
      
      // 1.4: First-encounter sequential notifications (pop-pop-pop)
      if (pins.isNotEmpty) {
        ref
            .read(notificationServiceProvider)
            .showFirstEncounterNotifications(pins)
            .catchError((_) {});
      }
      
      print('💓 Heartbeat OK → ${pins.length} pins');
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionOk = false;
          _statusText = '⚠️ Connection Issue';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection Error: ${e.toString().split(']').last.trim()}'),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      print('❌ Heartbeat: $e');
    }
  }

  String _compassDir(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * pi / 180;
    final y = sin(dLon) * cos(lat2 * pi / 180);
    final x = cos(lat1 * pi / 180) * sin(lat2 * pi / 180) -
        sin(lat1 * pi / 180) * cos(lat2 * pi / 180) * cos(dLon);
    var b = atan2(y, x) * 180 / pi;
    b = (b + 360) % 360;
    const d = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return d[((b + 22.5) % 360 / 45).floor()];
  }

  // ──────────────────────────────────────────────
  // NAVIGATION LOGIC
  // ──────────────────────────────────────────────
  Future<void> _startNavigation(Pin pin) async {
    if (_userPosition == null) return;
    
    setState(() {
      _navTargetPin = pin;
    });
    
    // Fetch route from OSRM; fallback to straight line if unavailable
    List<LatLng> route = [];
    try {
      route = await _navService.getRoute(
        _userPosition!,
        LatLng(pin.lat, pin.lon),
      );
    } catch (_) {}

    // Fallback: straight line if route is empty
    if (route.isEmpty) {
      route = [_userPosition!, LatLng(pin.lat, pin.lon)];
    }
    
    if (mounted) {
      setState(() {
        _navigationPath = route;
        _isNavigating = true;
        _arrivalHandled = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗺️ Route set! Walk towards the pin!'), backgroundColor: Colors.cyan),
      );
    }
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _navigationPath = [];
      _navTargetPin = null;
      _arrivalHandled = false; // Reset guard for next navigation
    });
  }

  Future<void> _handleArrival(Pin pin) async {
    _stopNavigation();
    
    // Show Success Animation
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            const Text('You Arrived!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('You discovered "${pin.title}"!', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Text('Enjoy the place!', style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Awesome!'),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
    
    // Notify Backend (Log Accomplishment)
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.logActivity(pin.id, 'visited', metadata: {'source': 'navigation'});
      
      // REFRESH Diary Providers to update "Passed Pins"
      ref.invalidate(diaryTimelineProvider);
      ref.invalidate(diaryStatsProvider);
      
      print('✅ Visited "${pin.title}" logged!');
    } catch (e) {
      print('❌ Failed to log visit: $e');
    }
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryProvider);
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Stack(
        children: [
          // ... Map (2.5D perspective tilt) ...
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0005)
              ..rotateX(-0.18),
            child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition ?? const LatLng(0.0, 0.0), // Don't use hardcoded Tokyo coordinates
              initialZoom: _userPosition != null ? 18.0 : 2.0, // Zoom out if no GPS location
              minZoom: _userPosition != null ? 16.0 : 2.0,
              maxZoom: 19.0,
              initialRotation: 0,  // Map stays north-up; only the dot rotates
              onPositionChanged: (pos, hasGesture) {
                // After a manual gesture, if follow mode is ON, gently snap back to the user
                // position after a short delay. When follow mode is OFF (Diary/search focus),
                // leave the camera where the user put it.
                if (hasGesture && _userPosition != null && _followUser) {
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted && _userPosition != null && _followUser) {
                      _mapController.move(_userPosition!, _mapController.camera.zoom);
                    }
                  });
                }
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.pinchMove,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.placetalk.app',
                maxZoom: 19,
              ),

              // Phase 1c: Fog of War — covers base tiles
              if (_fogEnabled)
                _buildFogLayer(),

              // 150m Hex Cloud layer — floats above fog as treasure hints
              if (_userPosition != null)
                _buildHexCloudLayer(state),

              if (_navigationPath.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _navigationPath,
                      strokeWidth: 6.0,
                      color: Colors.cyanAccent.withOpacity(0.8),
                      borderColor: Colors.blueAccent,
                      borderStrokeWidth: 2.0,
                    ),
                  ],
                ),

              // Pin markers on actual map coordinates
              if (_userPosition != null)
                _buildPinMarkers(state),
            ],
            ),
          ),
          
          // ... Layer 2 (Avatar) ...
          Center(
            child: Container(
              width: screenSize.width * 0.6,
              height: screenSize.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C63FF).withOpacity(0.06),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.35),
                  width: 2,
                ),
              ),
            ),
          ),
          
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseAnim, _bounceAnim]),
              builder: (context, _) {
                return Transform.translate(
                  offset: Offset(0, _bounceAnim.value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.rotate(
                        // Rotate the navigation arrow to match phone compass heading
                        angle: _heading * (pi / 180),
                        child: const Icon(
                          Icons.navigation,
                          color: Color(0xFF6C63FF),
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF6C63FF), Color(0xFF3F3D9B)],
                          ),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(108, 99, 255, _pulseAnim.value * 0.6),
                              blurRadius: 16 + (_pulseAnim.value * 8),
                              spreadRadius: 3 + (_pulseAnim.value * 4),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_walk,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 5,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // TOP STRIP: ≡ Menu | Status | Fog | 🔍 Search
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            right: 12,
            child: _buildTopStrip(state),
          ),

          // Stop-navigation banner (below top strip)
          if (_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 12,
              right: 12,
              child: _buildStopNavBanner(),
            ),

          // RIGHT FABs: Rescan (upper) + Drop Pin (lower)
          Positioned(
            right: 14,
            bottom: MediaQuery.of(context).padding.bottom + 90,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _mapFab(Icons.my_location, const Color(0xFF6C63FF), () async {
                  if (_userPosition != null) {
                    setState(() {
                      _followUser = true; // re-enable GPS follow when user taps My Location
                    });
                    _mapController.move(_userPosition!, _mapController.camera.zoom);
                  }
                  await ref.read(discoveryProvider.notifier).manualDiscovery();
                }, tooltip: 'Rescan', isLoading: state.isDiscovering),
                const SizedBox(height: 10),
                _mapFab(Icons.add_location_alt, const Color(0xFFFF6B6B), () async {
                  final created = await Navigator.pushNamed(context, '/create-pin');
                  if (created == true) {
                    ref.read(discoveryProvider.notifier).manualDiscovery();
                  }
                }, tooltip: 'Drop Pin'),
                const SizedBox(height: 10),
                _circleBtn(Icons.add, () {
                  final z = (_mapController.camera.zoom + 0.5).clamp(16.0, 19.0);
                  if (_userPosition != null) _mapController.move(_userPosition!, z);
                }),
                const SizedBox(height: 6),
                _circleBtn(Icons.remove, () {
                  final z = (_mapController.camera.zoom - 0.5).clamp(16.0, 19.0);
                  if (_userPosition != null) _mapController.move(_userPosition!, z);
                }),
              ],
            ),
          ),

          // BOTTOM HANDLE — swipe up to show pins within 50m
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomHandle(state),
          ),

          // PLACE SEARCH OVERLAY — Google Maps-style inline autocomplete
          if (_searchMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: _MapSearchField(
                onSelect: (lat, lon, label) {
                  setState(() {
                    _searchMode = false;
                    _followUser = false;
                  });
                  _mapController.move(LatLng(lat, lon), 16.0);
                  setState(() => _statusText = '📍 $label');
                },
                onClose: () => setState(() => _searchMode = false),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Phase 1b: Hex-cloud jitter helpers
  // ─────────────────────────────────────────────
  double _hashAngle(String id) {
    int h = 0;
    for (int i = 0; i < id.length; i++) h = (h * 31 + id.codeUnitAt(i)) & 0xFFFFFF;
    return (h % 360) * pi / 180;
  }

  double _hashMeters(String id) {
    int h = 0;
    for (int i = 0; i < id.length; i++) h = (h * 17 + id.codeUnitAt(i) + 3) & 0xFFFFFF;
    return 10.0 + (h % 14).toDouble(); // 10–24m offset
  }

  /// Returns a stable jittered LatLng for locked pins (obscures exact spot)
  LatLng _jitteredPosition(Pin pin) {
    return _jitterCache.putIfAbsent(pin.id, () {
      final a = _hashAngle(pin.id);
      final d = _hashMeters(pin.id) / 111320.0; // metres → degrees
      return LatLng(pin.lat + sin(a) * d, pin.lon + cos(a) * d);
    });
  }

  /// Groups pins within 6m of each other into clusters
  List<_PinCluster> _clusterPins(List<Pin> pins) {
    final clusters = <_PinCluster>[];
    final assigned = <String>{};
    for (final pin in pins) {
      if (assigned.contains(pin.id)) continue;
      final members = [pin];
      assigned.add(pin.id);
      for (final other in pins) {
        if (assigned.contains(other.id)) continue;
        if (Geolocator.distanceBetween(pin.lat, pin.lon, other.lat, other.lon) < 6.0) {
          members.add(other);
          assigned.add(other.id);
        }
      }
      clusters.add(_PinCluster(representative: pin, members: members));
    }
    return clusters;
  }

  Widget _buildPinMarkers(DiscoveryState state) {
    if (_userPosition == null) return const SizedBox();

    // Deduplicate all candidate pins
    final Set<String> pinIds = {};
    final List<Pin> allCandidatePins = [];
    for (final pin in [...state.discoveredPins, ...state.createdPins]) {
      if (!pinIds.contains(pin.id)) {
        pinIds.add(pin.id);
        allCandidatePins.add(pin);
      }
    }

    // 50m outer boundary
    final nearbyPins = allCandidatePins.where((pin) {
      final dist = Geolocator.distanceBetween(
        _userPosition!.latitude, _userPosition!.longitude,
        pin.lat, pin.lon,
      );
      return dist <= 50.0;
    }).toList();

    if (nearbyPins.isEmpty) return const SizedBox();

    // EXPLORE MODE: hide non-target pins during navigation
    var displayPins = nearbyPins;
    if (_isNavigating && _navTargetPin != null) {
      displayPins = nearbyPins.where((p) => p.id == _navTargetPin!.id).toList();
    }

    // ── Phase 1b: cluster nearby pins ──
    final clusters = _clusterPins(displayPins);
    final currentUser = ref.read(currentUserProvider).value;

    return MarkerLayer(
      markers: clusters.map((cluster) {
        final pin = cluster.representative;
        final isCluster = cluster.isCluster;

        final dist = Geolocator.distanceBetween(
          _userPosition!.latitude, _userPosition!.longitude,
          pin.lat, pin.lon,
        );

        // Phase 1a unlock stages
        final isFullyUnlocked = dist <= 20.0;
        final isOwnPin = currentUser != null && pin.createdBy == currentUser.id;
        final isHidden = pin.isHidden ?? false;
        final isDeprioritized = pin.isDeprioritized ?? false;

        // Color logic
        Color color = isCluster
            ? const Color(0xFF6C63FF)
            : isOwnPin
                ? const Color(0xFF2196F3)
                : pin.pinCategory == 'community'
                    ? const Color(0xFFFF9800)
                    : (pin.type == 'sensation'
                        ? const Color(0xFF9C27B0)
                        : const Color(0xFF4CAF50));
        if (!isFullyUnlocked && !isOwnPin && !isCluster) color = Colors.blueGrey[600]!;
        if (isDeprioritized) color = Colors.blueGrey;

        final double opacity = isHidden ? 0.3 : (isDeprioritized ? 0.5 : 1.0);
        final double markerW = isDeprioritized ? 40.0 : (isCluster ? 70.0 : (isFullyUnlocked ? 60.0 : 52.0));

        // Badge label
        String badgeLabel;
        if (isCluster) {
          badgeLabel = '×${cluster.members.length}';
        } else if (isHidden) {
          badgeLabel = 'Hidden';
        } else if (!isFullyUnlocked) {
          final shortTitle = pin.title.length > 10 ? '${pin.title.substring(0, 10)}…' : pin.title;
          badgeLabel = shortTitle;
        } else {
          badgeLabel = '${dist.toInt()}m';
        }

        // ── Phase 1b: jitter locked non-own pins to hide exact spot ──
        final displayPoint = (!isFullyUnlocked && !isOwnPin && !isCluster)
            ? _jitteredPosition(pin)
            : LatLng(pin.lat, pin.lon);

        // ── Phase 1b: hex-cloud BorderRadius for locked pins ──
        final BorderRadius markerRadius = isCluster
            ? BorderRadius.circular(12)
            : (!isFullyUnlocked && !isOwnPin)
                ? const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(18),
                  )
                : BorderRadius.circular(50);

        return Marker(
          point: displayPoint,
          width: markerW,
          height: markerW + 20,
          child: TweenAnimationBuilder<double>(
            key: ValueKey('fade_${pin.id}_$isFullyUnlocked'),
            tween: Tween(begin: 0.0, end: opacity),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(opacity: v, child: child!),
            child: GestureDetector(
              onTap: () {
                if (isCluster) {
                  _showClusterSheet(cluster);
                } else {
                  _showPinSheet(pin, dist, isFullyUnlocked: isFullyUnlocked);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isDeprioritized)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isFullyUnlocked || isCluster) ? color : Colors.grey[600],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeLabel,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Container(
                    width: isDeprioritized ? 24 : (isCluster ? 44 : 38),
                    height: isDeprioritized ? 24 : (isCluster ? 44 : 38),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: markerRadius,
                      border: Border.all(
                        color: (isFullyUnlocked || isOwnPin || isCluster)
                            ? Colors.white
                            : Colors.white54,
                        width: isDeprioritized ? 1.5 : 3,
                      ),
                      boxShadow: (isFullyUnlocked || isCluster) && !isHidden && !isDeprioritized
                          ? [BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )]
                          : null,
                    ),
                    child: isCluster
                        ? Icon(Icons.layers, color: Colors.white, size: isDeprioritized ? 14 : 24)
                        : Center(
                            child: Text(
                              isHidden
                                  ? '🙈'
                                  : !isFullyUnlocked
                                      ? '🔒'
                                      : pin.pinCategory == 'community'
                                          ? '🏮'
                                          : pin.type == 'sensation'
                                              ? '🌸'
                                              : '📍',
                              style: TextStyle(fontSize: isDeprioritized ? 10 : 16),
                              textAlign: TextAlign.center,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Show a sheet listing all pins in a cluster
  void _showClusterSheet(_PinCluster cluster) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.layers, color: Color(0xFF6C63FF), size: 24),
              const SizedBox(width: 10),
              Text('${cluster.members.length} Pins at this spot',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            ...cluster.members.map((pin) {
              final d = _userPosition == null
                  ? 0.0
                  : Geolocator.distanceBetween(
                      _userPosition!.latitude, _userPosition!.longitude,
                      pin.lat, pin.lon);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
                  child: Icon(
                    pin.pinCategory == 'community' ? Icons.groups : Icons.place,
                    color: const Color(0xFF6C63FF), size: 18),
                ),
                title: Text(pin.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${d.toInt()}m away'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPinSheet(pin, d, isFullyUnlocked: d <= 20.0);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Phase 1c: Fog of War layer
  // ──────────────────────────────────────────────
  Widget _buildFogLayer() {
    return Builder(
      builder: (ctx) {
        MapCamera? camera;
        try {
          camera = MapCamera.of(ctx);
        } catch (_) {
          return const SizedBox();
        }
        return IgnorePointer(
          child: CustomPaint(
            painter: _FogOfWarPainter(
              camera: camera,
              clearedPoints: List.unmodifiable(_fogClearedPoints),
              userPosition: _userPosition,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  // 150m Hex Cloud Layer
  // ──────────────────────────────────────────────

  static const double _hexR = 150.0; // meters — circumradius

  static Offset _latLonToM(LatLng origin, LatLng point) {
    const mpd = 111320.0;
    final mpdLon = mpd * cos(origin.latitude * pi / 180);
    return Offset(
      (point.longitude - origin.longitude) * mpdLon,
      (point.latitude  - origin.latitude)  * mpd,
    );
  }

  static LatLng _mToLatLon(LatLng origin, Offset m) {
    const mpd = 111320.0;
    final mpdLon = mpd * cos(origin.latitude * pi / 180);
    return LatLng(
      origin.latitude  + m.dy / mpd,
      origin.longitude + m.dx / mpdLon,
    );
  }

  static (int, int) _hexAxial(Offset m) {
    final fq = (2.0 / 3.0 * m.dx) / _hexR;
    final fr = (-1.0 / 3.0 * m.dx + sqrt(3) / 3.0 * m.dy) / _hexR;
    return _hexRound(fq, fr);
  }

  static (int, int) _hexRound(double fq, double fr) {
    final fs = -fq - fr;
    var rq = fq.round();
    var rr = fr.round();
    final rs = fs.round();
    final dq = (rq - fq).abs();
    final dr = (rr - fr).abs();
    final ds = (rs - fs).abs();
    if (dq > dr && dq > ds) {
      rq = -rr - rs;
    } else if (dr > ds) {
      rr = -rq - rs;
    }
    return (rq, rr);
  }

  static Offset _hexCenterM(int q, int r) => Offset(
    _hexR * (3.0 / 2.0 * q),
    _hexR * (sqrt(3) / 2.0 * q + sqrt(3) * r),
  );

  static List<Offset> _hexCornersM(Offset center) => List.generate(
    6,
    (i) => Offset(
      center.dx + _hexR * cos(pi / 3.0 * i),
      center.dy + _hexR * sin(pi / 3.0 * i),
    ),
  );

  Widget _buildHexCloudLayer(DiscoveryState state) {
    if (_userPosition == null) return const SizedBox();
    final origin = _userPosition!;
    final currentUser = ref.read(currentUserProvider).value;
    final polygons = <Polygon>[];
    final labelMarkers = <Marker>[];
    final Set<String> seenHexes = {};
    final Set<String> allIds = {};
    final allPins = <Pin>[];
    for (final p in [...state.discoveredPins, ...state.createdPins]) {
      if (allIds.add(p.id)) allPins.add(p);
    }

    for (final pin in allPins) {
      final dist = Geolocator.distanceBetween(
          origin.latitude, origin.longitude, pin.lat, pin.lon);
      if (dist > 200.0) continue;
      final isOwn = currentUser != null && pin.createdBy == currentUser.id;
      if (isOwn || dist <= 20.0) continue;

      final localM = _latLonToM(origin, LatLng(pin.lat, pin.lon));
      final (q, r) = _hexAxial(localM);
      final hexKey = '$q,$r';
      if (!seenHexes.add(hexKey)) continue;

      final centerM = _hexCenterM(q, r);
      final corners = _hexCornersM(centerM)
          .map((m) => _mToLatLon(origin, m))
          .toList();
      final centerLatLng = _mToLatLon(origin, centerM);

      final cloudColor = pin.pinCategory == 'community'
          ? const Color(0xFFFF9800)
          : pin.type == 'sensation'
              ? const Color(0xFF9C27B0)
              : const Color(0xFF5C9BD6);

      polygons.add(Polygon(
        points: corners,
        color: cloudColor.withOpacity(0.22),
        borderColor: cloudColor.withOpacity(0.65),
        borderStrokeWidth: 1.8,
        isFilled: true,
      ));

      if (!_hexPlaceNames.containsKey(hexKey)) {
        _hexPlaceNames[hexKey] = '';
        GeocodingService.reverseGeocode(
                centerLatLng.latitude, centerLatLng.longitude)
            .then((addr) {
          if (mounted && addr != null && addr.display.isNotEmpty) {
            setState(() => _hexPlaceNames[hexKey] = addr.display);
          }
        });
      }

      final placeName = _hexPlaceNames[hexKey] ?? '';
      if (placeName.isNotEmpty) {
        labelMarkers.add(Marker(
          point: centerLatLng,
          width: 130,
          height: 36,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.82),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                placeName,
                style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: cloudColor,
                    height: 1.2),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ));
      }
    }

    if (polygons.isEmpty) return const SizedBox();
    return Stack(children: [
      PolygonLayer(polygons: polygons),
      if (labelMarkers.isNotEmpty) MarkerLayer(markers: labelMarkers),
    ]);
  }

  // ──────────────────────────────────────────────
  // Fog of War persistence
  // ──────────────────────────────────────────────

  Future<void> _loadFogFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('fog_points_v1');
      if (raw != null && raw.isNotEmpty && mounted) {
        final points = raw.map((s) {
          final p = s.split(',');
          return LatLng(double.parse(p[0]), double.parse(p[1]));
        }).toList();
        setState(() => _fogClearedPoints.addAll(points));
      }
    } catch (e) {
      debugPrint('⚠️ Fog load failed: $e');
    }
  }

  void _debouncedSaveFog() {
    _fogSaveTimer?.cancel();
    _fogSaveTimer = Timer(const Duration(seconds: 4), _saveFogToPrefs);
  }

  Future<void> _saveFogToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'fog_points_v1',
        _fogClearedPoints
            .map((p) => '${p.latitude},${p.longitude}')
            .toList(),
      );
    } catch (e) {
      debugPrint('⚠️ Fog save failed: $e');
    }
  }

  // ──────────────────────────────────────────────
  // 1.3 FULL EXPLORATION UI — TOP STRIP
  // ──────────────────────────────────────────────

  Widget _buildTopStrip(DiscoveryState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ≡ Menu
        _topBtn(Icons.menu, () => _showMenuSheet()),
        const SizedBox(width: 8),
        // Status pill (expands)
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.94),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _connectionOk ? const Color(0xFF4CAF50) : Colors.orange,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12,
                      color: _connectionOk ? Colors.grey[800] : Colors.orange[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _fogEnabled = !_fogEnabled),
                  child: Icon(
                    _fogEnabled ? Icons.cloud : Icons.wb_sunny,
                    size: 17,
                    color: _fogEnabled ? Colors.indigo[400] : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 🔍 Search
        _topBtn(Icons.search, () => setState(() => _searchMode = true)),
      ],
    );
  }

  Widget _topBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }

  Widget _buildStopNavBanner() {
    return GestureDetector(
      onTap: _stopNavigation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 8)],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.close, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text('Navigating — tap to Stop',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _mapFab(IconData icon, Color color, VoidCallback onTap,
      {String? tooltip, bool isLoading = false}) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: color.withOpacity(0.38), blurRadius: 10, spreadRadius: 1)],
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  // 1.3 BOTTOM HANDLE — swipe up for 50m pin list
  // ──────────────────────────────────────────────

  Widget _buildBottomHandle(DiscoveryState state) {
    int nearbyCount = 0;
    if (_userPosition != null) {
      for (final pin in state.allPins) {
        final d = Geolocator.distanceBetween(
            _userPosition!.latitude, _userPosition!.longitude, pin.lat, pin.lon);
        if (d <= 50.0) nearbyCount++;
      }
    }
    return GestureDetector(
      onTap: _showPinList,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 12,
                offset: const Offset(0, -3))
          ],
        ),
        child: Row(
          children: [
            Center(
              child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.place, color: Color(0xFF4CAF50), size: 15),
            const SizedBox(width: 4),
            Text(
              nearbyCount == 0
                  ? 'No pins in range — keep walking!'
                  : '$nearbyCount pin${nearbyCount > 1 ? 's' : ''} within 50m',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
            ),
            const Spacer(),
            Icon(Icons.keyboard_arrow_up, color: Colors.grey[500], size: 20),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 1.3 MENU SHEET
  // ──────────────────────────────────────────────

  void _showMenuSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFF9800),
                  child: Icon(Icons.groups, color: Colors.white)),
              title: const Text('Communities',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Chat in community spaces'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CommunityListScreen()));
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0xFF6C63FF),
                  child: Icon(Icons.auto_stories, color: Colors.white)),
              title:
                  const Text('Diary', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Your explored history'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DiaryScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // PIN DETAIL SHEET
  // ──────────────────────────────────────────────
  void _showPinSheet(Pin pin, double dist, {bool isFullyUnlocked = false}) {
    // Mark as opened — remove from ghost candidate
    _nearbyButNotOpened.remove(pin.id);

    final dir = _userPosition != null
        ? _compassDir(_userPosition!.latitude, _userPosition!.longitude, pin.lat, pin.lon)
        : '';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            // ── 1.2: Locked banner (50–20m) ──
            if (!isFullyUnlocked)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Get within 20m to unlock full details! (${dist.toInt()}m away)',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // ── 1.2: Community preview shown even when locked ──
            if (!isFullyUnlocked && pin.pinCategory == 'community')
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.groups, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Community: ${pin.title}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Walk within 20m to join the chat 💬',
                            style: TextStyle(
                                fontSize: 11, color: Colors.deepOrange),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Title
            Row(children: [
              Icon(
                pin.pinCategory == 'community' ? Icons.groups : (pin.type == 'location' ? Icons.place : Icons.auto_awesome),
                color: pin.pinCategory == 'community' ? Colors.orange : (pin.type == 'location' ? Colors.green : Colors.purple), 
                size: 26
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(pin.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 10),
            // Distance + direction
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('🧭 ${dist.toInt()}m $dir',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6C63FF)),
              ),
            ),
            const SizedBox(height: 6),
            // Address from LocationIQ reverse geocoding
            FutureBuilder<GeocodedAddress?>(
              future: GeocodingService.reverseGeocode(pin.lat, pin.lon),
              builder: (_, snap) {
                if (snap.hasData && snap.data != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.location_city_outlined, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            snap.data!.display,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 6),

            // Directions hint — always shown (50–20m shows as teaser)
            Text(
              isFullyUnlocked
                  ? pin.directions
                  : (pin.directions.length > 40
                      ? '${pin.directions.substring(0, 40)}… (get closer to read more)'
                      : pin.directions),
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),

            // Full details only when unlocked
            if (isFullyUnlocked && pin.details != null) ...[
              const SizedBox(height: 6),
              Text(pin.details!, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
            const SizedBox(height: 16),
            // Actions — animated Like / Hide / Report
            _PinActionRow(pin: pin, sheetCtx: ctx, mapContext: context),
            
            const SizedBox(height: 12),
            
            // "Let's Explore" Navigation Button — only when unlocked
            if (isFullyUnlocked)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isNavigating && _navTargetPin?.id == pin.id 
                    ? _stopNavigation 
                    : () {
                        Navigator.pop(ctx);
                        _startNavigation(pin);
                      },
                icon: Icon(_isNavigating && _navTargetPin?.id == pin.id ? Icons.stop : Icons.directions_walk, color: Colors.white),
                label: Text(
                  _isNavigating && _navTargetPin?.id == pin.id ? 'Stop Navigation' : "Let's Explore",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isNavigating && _navTargetPin?.id == pin.id ? Colors.red : Colors.cyan,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
            // Community Join Button (Only for Community Pins when unlocked)
            if (isFullyUnlocked && pin.pinCategory == 'community') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Show loading feedback
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Connecting to community...'), duration: Duration(milliseconds: 1000)),
                    );
                    
                    try {
                      final apiClient = ref.read(apiClientProvider);
                      // Find or Create Community based on Pin Title
                      final communityJson = await apiClient.findOrCreateCommunity(pin.title);
                      final community = Community.fromJson(communityJson);
                      
                      if (ctx.mounted) {
                        Navigator.pop(ctx); // Close sheet
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(builder: (_) => CommunityPage(community: community)),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Failed to join: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.groups, color: Colors.white),
                  label: const Text('Enter Community Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange, // Use direct color or JapaneseColors.kogane
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            // ── spec 2.4: Owner Edit / Delete controls ──────────────────
            Builder(builder: (bCtx) {
              final currentUser = ref.read(currentUserProvider).value;
              if (currentUser == null || pin.createdBy != currentUser.id) {
                return const SizedBox.shrink();
              }
              final bool withinRange = dist <= 50.0;
              final bool canModify = withinRange || currentUser.isB2bPartner;
              if (!canModify) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Move within 50 m to edit or delete this pin',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return Column(children: [
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEditPinSheet(pin);
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDeletePin(ctx, pin),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
              ]);
            }),
          ],
        ),
      ),
    );
  }

  // ── spec 2.4: Edit pin bottom sheet ──────────────────────────────────
  void _showEditPinSheet(Pin pin) {
    final titleCtrl = TextEditingController(text: pin.title);
    final dirCtrl = TextEditingController(text: pin.directions);
    final detailsCtrl = TextEditingController(text: pin.details ?? '');
    final linkCtrl = TextEditingController(text: pin.externalLink ?? '');
    bool chatEnabled = pin.chatEnabled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx2, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Pin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  maxLength: 10,
                  decoration: const InputDecoration(labelText: 'Title (max 10 chars)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dirCtrl,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Directions (50–100 chars)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsCtrl,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Details (max 500 chars)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkCtrl,
                  decoration: const InputDecoration(labelText: 'External Link (optional)', border: OutlineInputBorder()),
                ),
                if (pin.pinCategory == 'community') ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Enable Chat'),
                    value: chatEnabled,
                    onChanged: (v) => setSheetState(() => chatEnabled = v),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      final dirs = dirCtrl.text.trim();
                      if (title.isEmpty || dirs.length < 50) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Title required; directions must be 50+ chars')),
                        );
                        return;
                      }
                      try {
                        Navigator.pop(sheetCtx);
                        await ref.read(apiClientProvider).updatePin(
                          pin.id,
                          title: title,
                          directions: dirs,
                          details: detailsCtrl.text.trim().isEmpty ? null : detailsCtrl.text.trim(),
                          externalLink: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
                          chatEnabled: chatEnabled,
                          userLat: _userPosition!.latitude,
                          userLon: _userPosition!.longitude,
                        );
                        ref.invalidate(discoveryProvider);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pin updated'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── spec 2.4: Confirm delete dialog ──────────────────────────────────
  Future<void> _confirmDeletePin(BuildContext ctx, Pin pin) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Pin?'),
        content: Text('Are you sure you want to delete "${pin.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      Navigator.pop(ctx); // close pin sheet
      await ref.read(apiClientProvider).deletePin(
        pin.id,
        userLat: _userPosition!.latitude,
        userLon: _userPosition!.longitude,
      );
      ref.invalidate(discoveryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pin deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  // ──────────────────────────────────────────────
  // PIN LIST
  // ──────────────────────────────────────────────
  void _showPinList() {
    // Pins within 50m only, deduplicated and sorted by distance
    final state = ref.read(discoveryProvider);
    final Set<String> seen = {};
    final List<Pin> allPins = [];
    for (final pin in [...state.discoveredPins, ...state.createdPins]) {
      if (!seen.contains(pin.id)) {
        seen.add(pin.id);
        if (_userPosition != null) {
          final d = Geolocator.distanceBetween(
              _userPosition!.latitude, _userPosition!.longitude, pin.lat, pin.lon);
          if (d <= 50.0) allPins.add(pin);
        } else {
          allPins.add(pin);
        }
      }
    }
    if (_userPosition != null) {
      allPins.sort((a, b) {
        final da = Geolocator.distanceBetween(_userPosition!.latitude, _userPosition!.longitude, a.lat, a.lon);
        final db = Geolocator.distanceBetween(_userPosition!.latitude, _userPosition!.longitude, b.lat, b.lon);
        return da.compareTo(db);
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (ctx, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                Text('Pins (${allPins.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
            ),
            Expanded(
              child: allPins.isEmpty
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.explore_off, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No pins yet. Create one or walk to discover!', style: TextStyle(color: Colors.grey)),
                    ]))
                  : ListView.builder(
                      controller: sc,
                      itemCount: allPins.length,
                      itemBuilder: (ctx, i) {
                        final pin = allPins[i];
                        final dist = _userPosition != null
                            ? Geolocator.distanceBetween(
                                _userPosition!.latitude, _userPosition!.longitude, pin.lat, pin.lon)
                            : 0.0;
                        final currentUser = ref.read(currentUserProvider).value;
                        final isOwn = currentUser != null && pin.createdBy == currentUser.id;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isOwn
                                ? Colors.blue.withOpacity(0.1)
                                : (pin.type == 'location' ? Colors.green.withOpacity(0.1) : Colors.purple.withOpacity(0.1)),
                            child: Icon(
                              isOwn ? Icons.person_pin_circle : (pin.type == 'location' ? Icons.place : Icons.auto_awesome),
                              color: isOwn ? Colors.blue : (pin.type == 'location' ? Colors.green : Colors.purple),
                            ),
                          ),
                          title: Text(pin.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${dist.toInt()}m away • ${pin.likeCount} likes${isOwn ? " • Mine" : ""}'),
                          trailing: dist <= 50.0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFF4CAF50), borderRadius: BorderRadius.circular(12)),
                                  child: const Text('InRange', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                )
                              : null,
                          onTap: () { Navigator.pop(ctx); _showPinSheet(pin, dist); },
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
      ),
      child: IconButton(icon: Icon(icon, color: Colors.black87), onPressed: onTap),
    );
  }
}

// ─────────────────────────────────────────────────
// _PinActionRow — manages Like / Hide / Report state
// ─────────────────────────────────────────────────
class _PinActionRow extends ConsumerStatefulWidget {
  final Pin pin;
  final BuildContext sheetCtx;
  final BuildContext mapContext;
  const _PinActionRow({required this.pin, required this.sheetCtx, required this.mapContext});

  @override
  ConsumerState<_PinActionRow> createState() => _PinActionRowState();
}

class _PinActionRowState extends ConsumerState<_PinActionRow> {
  late int _likeCount;
  bool _isLiked = false;
  bool _isHidden = false;
  bool _isReported = false;
  bool _likeLoading = false;
  bool _hideLoading = false;
  bool _reportLoading = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.pin.likeCount;
  }

  String _err(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
      if (data is String && data.isNotEmpty) return data;
    }
    return e.toString();
  }

  Future<void> _handleLike() async {
    if (_likeLoading) return;
    final wasLiked = _isLiked;
    final prevCount = _likeCount;
    setState(() {
      _likeLoading = true;
      _isLiked = !wasLiked;
      _likeCount = wasLiked ? prevCount - 1 : prevCount + 1;
    });
    try {
      await ref.read(discoveryProvider.notifier).likePin(widget.pin.id);
      ref.invalidate(diaryStatsProvider);
      ref.invalidate(diaryPassiveLogProvider);
      ref.invalidate(myPinsMetricsProvider);
    } catch (e) {
      if (mounted) {
        setState(() { _isLiked = wasLiked; _likeCount = prevCount; });
        ScaffoldMessenger.of(widget.mapContext).showSnackBar(
          SnackBar(content: Text('Like failed: ${_err(e)}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  Future<void> _handleHide() async {
    if (_hideLoading) return;
    final wasHidden = _isHidden;
    setState(() { _hideLoading = true; _isHidden = !wasHidden; });
    try {
      await ref.read(discoveryProvider.notifier).hidePin(widget.pin.id);
      ref.invalidate(diaryPassiveLogProvider);
      ref.invalidate(myPinsMetricsProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _isHidden = wasHidden);
        ScaffoldMessenger.of(widget.mapContext).showSnackBar(
          SnackBar(content: Text('Hide failed: ${_err(e)}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _hideLoading = false);
    }
  }

  Future<void> _handleReport() async {
    if (_reportLoading) return;
    final wasReported = _isReported;
    setState(() { _reportLoading = true; _isReported = !wasReported; });
    try {
      await ref.read(discoveryProvider.notifier).reportPin(widget.pin.id);
      ref.invalidate(diaryPassiveLogProvider);
      ref.invalidate(myPinsMetricsProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _isReported = wasReported);
        ScaffoldMessenger.of(widget.mapContext).showSnackBar(
          SnackBar(content: Text('Report failed: ${_err(e)}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _InteractiveActionBtn(
          icon: Icons.thumb_up_rounded,
          label: 'Like',
          count: _likeCount,
          color: Colors.green,
          active: _isLiked,
          loading: _likeLoading,
          showFloatingPlus: true,
          onTap: _handleLike,
        ),
        _InteractiveActionBtn(
          icon: Icons.visibility_off_rounded,
          label: 'Hide',
          color: Colors.blueGrey,
          active: _isHidden,
          loading: _hideLoading,
          onTap: _handleHide,
        ),
        _InteractiveActionBtn(
          icon: Icons.flag_rounded,
          label: 'Report',
          color: Colors.redAccent,
          active: _isReported,
          loading: _reportLoading,
          onTap: _handleReport,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// _InteractiveActionBtn — bounce + glow + floating +1
// ─────────────────────────────────────────────────
class _InteractiveActionBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final int? count;
  final Color color;
  final bool active;
  final bool loading;
  final bool showFloatingPlus;
  final VoidCallback onTap;

  const _InteractiveActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.loading,
    required this.onTap,
    this.count,
    this.showFloatingPlus = false,
  });

  @override
  State<_InteractiveActionBtn> createState() => _InteractiveActionBtnState();
}

class _InteractiveActionBtnState extends State<_InteractiveActionBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _showPlus = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.85), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_InteractiveActionBtn old) {
    super.didUpdateWidget(old);
    if (!old.active && widget.active) {
      _ctrl.forward(from: 0);
      if (widget.showFloatingPlus) {
        setState(() => _showPlus = true);
        Future.delayed(const Duration(milliseconds: 750), () {
          if (mounted) setState(() => _showPlus = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final label = widget.count != null ? '${widget.label} (${widget.count})' : widget.label;
    return GestureDetector(
      onTap: widget.loading ? null : widget.onTap,
      child: SizedBox(
        width: 88,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.active ? c : c.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: c, width: 2),
                      boxShadow: widget.active
                          ? [BoxShadow(color: c.withOpacity(0.45), blurRadius: 14, spreadRadius: 2)]
                          : [],
                    ),
                    child: widget.loading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: widget.active ? Colors.white : c,
                            ),
                          )
                        : Icon(widget.icon,
                            color: widget.active ? Colors.white : c, size: 24),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: widget.active ? c : Colors.grey[600]!,
                    fontWeight: widget.active ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ],
            ),
            // Floating +1
            if (_showPlus)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 750),
                builder: (_, t, __) {
                  final opacity = (t < 0.65 ? 1.0 : (1.0 - (t - 0.65) / 0.35)).clamp(0.0, 1.0);
                  return Positioned(
                    top: -32 * t,
                    child: Opacity(
                      opacity: opacity,
                      child: Text('+1',
                          style: TextStyle(
                              color: c, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// _MapSearchField — Google Maps-style place search
// Type → debounce 380ms → Nominatim autocomplete suggestions
// ─────────────────────────────────────────────────
class _MapSearchField extends StatefulWidget {
  final void Function(double lat, double lon, String label) onSelect;
  final VoidCallback onClose;
  const _MapSearchField({required this.onSelect, required this.onClose});

  @override
  State<_MapSearchField> createState() => _MapSearchFieldState();
}

class _MapSearchFieldState extends State<_MapSearchField> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = false;
  Timer? _debounce;

  // Icon per Nominatim type/class
  IconData _iconFor(String type) {
    switch (type) {
      case 'train_station':
      case 'station':
      case 'subway_entrance':
        return Icons.train_rounded;
      case 'airport':
        return Icons.flight_rounded;
      case 'hotel':
      case 'hostel':
        return Icons.hotel_rounded;
      case 'restaurant':
      case 'cafe':
      case 'food_court':
        return Icons.restaurant_rounded;
      case 'park':
      case 'garden':
      case 'forest':
        return Icons.park_rounded;
      case 'hospital':
      case 'clinic':
        return Icons.local_hospital_rounded;
      case 'school':
      case 'university':
      case 'college':
        return Icons.school_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  void _onChanged(String val) {
    _debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() { _suggestions = []; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 380), () async {
      final results = await GeocodingService.searchSuggestions(val);
      if (mounted) setState(() { _suggestions = results; _loading = false; });
    });
  }

  @override
  void initState() {
    super.initState();
    // Auto-focus after frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Search bar row ─────────────────────────────────────────
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              GestureDetector(
                onTap: widget.onClose,
                child: const Icon(Icons.arrow_back_rounded, color: Colors.black54, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  decoration: const InputDecoration(
                    hintText: 'Search places — Asakusa, Tokyo…',
                    hintStyle: TextStyle(fontSize: 14, color: Colors.black38),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: (val) async {
                    if (val.trim().isEmpty) return;
                    // Submit picks the first suggestion if available
                    if (_suggestions.isNotEmpty) {
                      final s = _suggestions.first;
                      widget.onSelect(s['lat'] as double, s['lon'] as double,
                          s['title'] as String);
                    }
                  },
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF))),
                )
              else if (_ctrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    setState(() => _suggestions = []);
                    _focus.requestFocus();
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: Icon(Icons.close_rounded, color: Colors.black45, size: 20),
                  ),
                ),
            ],
          ),
        ),

        // ── Suggestions dropdown ───────────────────────────────────
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: _suggestions.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                final isLast = i == _suggestions.length - 1;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onSelect(
                      s['lat'] as double, s['lon'] as double, s['title'] as String),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_iconFor(s['type'] as String),
                                  color: const Color(0xFF6C63FF), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['title'] as String,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if ((s['subtitle'] as String).isNotEmpty)
                                    Text(
                                      s['subtitle'] as String,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black45),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.north_west_rounded,
                                color: Colors.black26, size: 14),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Divider(
                            height: 1,
                            indent: 64,
                            endIndent: 16,
                            color: Colors.grey[100]),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // ── Empty state ────────────────────────────────────────────
        if (!_loading && _ctrl.text.trim().length >= 2 && _suggestions.isEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
            ),
            child: Center(
              child: Text(
                'No places found for "${_ctrl.text}"',
                style: const TextStyle(fontSize: 13, color: Colors.black45),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// Phase 1b helper: pin cluster model
// ─────────────────────────────────────────────────
class _PinCluster {
  final Pin representative;
  final List<Pin> members;
  _PinCluster({required this.representative, required this.members});
  bool get isCluster => members.length > 1;
}

// ─────────────────────────────────────────────────
// Phase 1c: Fog of War custom painter
// ─────────────────────────────────────────────────
class _FogOfWarPainter extends CustomPainter {
  final MapCamera camera;
  final List<LatLng> clearedPoints;
  final LatLng? userPosition;

  const _FogOfWarPainter({
    required this.camera,
    required this.clearedPoints,
    required this.userPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Save layer so BlendMode.clear punches real holes in the fog
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Draw the dark fog over the entire canvas
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withOpacity(0.68),
    );

    // Punch circular holes for every explored point
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    const exploredRadius = 85.0; // pixels

    for (final pt in clearedPoints) {
      final sp = camera.latLngToScreenPoint(pt);
      canvas.drawCircle(Offset(sp.x.toDouble(), sp.y.toDouble()), exploredRadius, clearPaint);
    }

    // Always clear a larger circle around the current user position
    if (userPosition != null) {
      final sp = camera.latLngToScreenPoint(userPosition!);
      canvas.drawCircle(
          Offset(sp.x.toDouble(), sp.y.toDouble()), exploredRadius * 1.5, clearPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_FogOfWarPainter old) =>
      old.clearedPoints.length != clearedPoints.length ||
      old.userPosition != userPosition ||
      old.camera != camera;
}
