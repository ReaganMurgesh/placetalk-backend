import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:async';
import 'dart:math';
import 'package:placetalk/providers/discovery_provider.dart';
import 'package:placetalk/services/location_service.dart';
import 'package:placetalk/services/notification_service.dart';
import 'package:placetalk/models/pin.dart';
import 'package:placetalk/providers/auth_provider.dart';
import 'package:placetalk/models/community.dart';
import 'package:placetalk/screens/social/community_screen.dart';
import 'package:placetalk/services/navigation_service.dart';
import 'package:placetalk/providers/diary_provider.dart';

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
  bool _isFetchingRoute = false;
  bool _arrivalHandled = false; // Guard: prevent double-logging on arrival

  // Periodic heartbeat timer (fires every 30s when standing still)
  Timer? _periodicHeartbeat;

  // --- Phase 1a: Two-stage detection & Ghost Pins ---
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
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _gpsSub?.cancel();
    _periodicHeartbeat?.cancel();
    _pulseCtrl.dispose();
    _bounceCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // COMPASS: Rotate the map with phone heading
  // ──────────────────────────────────────────────
  void _initCompass() {
    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading != null && mounted) {
        setState(() { _heading = event.heading!; });
        // Rotate map so it faces where you face
        try {
          _mapController.rotate(-_heading);
        } catch (_) {}
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
    try {
      _mapController.move(newPos, _mapController.camera.zoom);
    } catch (_) {}

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
      
      // Notify for each discovered pin
      for (final pin in pins) {
        final dir = _compassDir(
          pos.latitude, pos.longitude, pin.lat, pin.lon,
        );
        try {
          ref.read(notificationServiceProvider).showNotification(
            title: '📍 ${pin.title}',
            body: 'Go $dir! ${pin.distance?.toInt() ?? '?'}m away',
          );
        } catch (_) {}
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
      _isFetchingRoute = true;
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
        _isFetchingRoute = false;
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
          // ... Map ...
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition ?? const LatLng(0.0, 0.0), // Don't use hardcoded Tokyo coordinates
              initialZoom: _userPosition != null ? 18.0 : 2.0, // Zoom out if no GPS location
              minZoom: _userPosition != null ? 16.0 : 2.0,
              maxZoom: 19.0,
              initialRotation: -_heading,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _userPosition != null) {
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted && _userPosition != null) {
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

              // Phase 1c: Fog of War overlay
              if (_fogEnabled)
                _buildFogLayer(),
            ],
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
                        angle: 0,
                        child: const Icon(
                          Icons.navigation,
                          color: Color(0xFF6C63FF),
                          size: 16,
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
          
          // ... Layer 3 (Top Bar) ...
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: _buildTopBar(state),
          ),

          // STOP NAVIGATION BUTTON (New)
          if (_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: _stopNavigation,
                backgroundColor: Colors.redAccent,
                icon: const Icon(Icons.close, color: Colors.white),
                label: const Text('Stop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          
          // ... Layer 4 (Bottom Bar) ...
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(context, state),
          ),
          
          // ... Layer 5 (Zoom) ...
          Positioned(
            right: 16,
            bottom: 130,
            child: Column(
              children: [
                _circleBtn(Icons.add, () {
                  final z = (_mapController.camera.zoom + 0.5).clamp(16.0, 19.0);
                  if (_userPosition != null) _mapController.move(_userPosition!, z);
                }),
                const SizedBox(height: 8),
                _circleBtn(Icons.remove, () {
                  final z = (_mapController.camera.zoom - 0.5).clamp(16.0, 19.0);
                  if (_userPosition != null) _mapController.move(_userPosition!, z);
                }),
              ],
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
        final double iconSize = isDeprioritized ? 30.0 : (isCluster ? 44.0 : 38.0);
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
          child: Opacity(
            opacity: opacity,
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
                    child: Icon(
                      isCluster
                          ? Icons.layers
                          : isHidden
                              ? Icons.visibility_off
                              : (!isFullyUnlocked
                                  ? Icons.cloud // 🌫️ hex cloud for locked
                                  : (pin.pinCategory == 'community'
                                      ? Icons.groups
                                      : (pin.type == 'sensation'
                                          ? Icons.auto_awesome
                                          : Icons.place))),
                      color: Colors.white,
                      size: isDeprioritized ? 14 : (isCluster ? 24 : 20),
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
  // TOP BAR
  // ──────────────────────────────────────────────
  Widget _buildTopBar(DiscoveryState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)],
      ),
      child: Row(
        children: [
          // Pin count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.place, color: Color(0xFF4CAF50), size: 16),
                const SizedBox(width: 4),
                Text('${state.allPins.length}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF4CAF50)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Status text
          Expanded(
            child: Text(
              _statusText,
              style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13,
                color: _connectionOk ? Colors.grey[700] : Colors.orange[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Fog toggle
          GestureDetector(
            onTap: () => setState(() => _fogEnabled = !_fogEnabled),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _fogEnabled
                    ? Colors.indigo.withOpacity(0.12)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _fogEnabled ? Icons.cloud : Icons.wb_sunny,
                size: 16,
                color: _fogEnabled ? Colors.indigo[700] : Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Connection indicator
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _connectionOk ? const Color(0xFF4CAF50) : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // BOTTOM BAR
  // ──────────────────────────────────────────────
  Widget _buildBottomBar(BuildContext context, DiscoveryState state) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.7), Colors.black.withOpacity(0.9)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navBtn(Icons.format_list_bulleted, 'Pins', const Color(0xFF4CAF50), () => _showPinList()),
              _createBtn(context),
              _navBtn(
                Icons.radar, 'Discover', const Color(0xFF6C63FF),
                () => ref.read(discoveryProvider.notifier).manualDiscovery(),
                isLoading: state.isDiscovering,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, String label, Color color, VoidCallback onTap, {bool isLoading = false}) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 2),
            ),
            child: isLoading
                ? Padding(padding: const EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: color))
                : Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _createBtn(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final created = await Navigator.pushNamed(context, '/create-pin');
        if (created == true) {
          // Refresh — trigger discovery after creating a pin
          ref.read(discoveryProvider.notifier).manualDiscovery();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: const Color(0xFFFF6B6B).withOpacity(0.4), blurRadius: 12, spreadRadius: 2)],
            ),
            child: const Icon(Icons.add_location_alt, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 4),
          const Text('Create', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
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

            // ── Phase 1a: Locked banner (50–20m) ──
            if (!isFullyUnlocked)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
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
                        'Get within 20m to unlock full details!  (${dist.toInt()}m away)',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
            const SizedBox(height: 10),

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
             // Actions — only show interactive buttons when fully unlocked
             // Minimalist Actions: Like | Hide | Report
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // LIKE
                _actionBtn(
                  icon: Icons.thumb_up,
                  label: 'Like (${pin.likeCount})',
                  color: Colors.green,
                  onTap: () async {
                    try {
                      await ref.read(apiClientProvider).likePin(pin.id);
                      ref.read(discoveryProvider.notifier).incrementLikeLocally(pin.id);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('👍 Liked!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to like: ${e.toString()}'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
                // HIDE (Personal)
                _actionBtn(
                  icon: Icons.visibility_off,
                  label: 'Hide',
                  color: Colors.grey,
                  onTap: () async {
                    try {
                      await ref.read(apiClientProvider).hidePin(pin.id);
                      // Immediately remove from local state (optimistic)
                      ref.read(discoveryProvider.notifier).hidePinLocally(pin.id);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pin hidden'), duration: Duration(seconds: 2)),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to hide: ${e.toString()}'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
                // REPORT (Global)
                _actionBtn(
                  icon: Icons.flag,
                  label: 'Report',
                  color: Colors.redAccent,
                  onTap: () async {
                    try {
                      await ref.read(apiClientProvider).reportPin(pin.id);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reported — pin creator notified'), backgroundColor: Colors.redAccent, duration: Duration(seconds: 3)),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to report: ${e.toString()}'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            
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
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // PIN LIST
  // ──────────────────────────────────────────────
  void _showPinList() {
    // Combine discovered + created, deduplicated (same logic as map markers)
    final state = ref.read(discoveryProvider);
    final Set<String> seen = {};
    final List<Pin> allPins = [];
    for (final pin in [...state.discoveredPins, ...state.createdPins]) {
      if (!seen.contains(pin.id)) {
        seen.add(pin.id);
        allPins.add(pin);
      }
    }
    // Sort by distance
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
