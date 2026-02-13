import 'package:flutter/material.dart';
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
    
    // Load existing pins from backend on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryProvider.notifier).loadNearbyPins();
    });
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _gpsSub?.cancel();
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
        
        // 20m threshold → heartbeat to backend
        if (_lastHeartbeatPos != null) {
          final moved = Geolocator.distanceBetween(
            _lastHeartbeatPos!.latitude, _lastHeartbeatPos!.longitude,
            pos.latitude, pos.longitude,
          );
          if (moved >= 20.0) {
            _triggerHeartbeat(pos);
          }
        }
      },
      onError: (e) => print('❌ GPS error: $e'),
    );
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
  // BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryProvider);
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Stack(
        children: [
          // ═══════════════════════════════════════════
          // LAYER 1: THE MAP (bottom layer — can be dragged)
          // The map is LOCKED to GPS position. Compass rotates it.
          // Pin markers live here on the actual map coordinates.
          // ═══════════════════════════════════════════
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition ?? const LatLng(35.6762, 139.6503),
              initialZoom: 18.0,
              minZoom: 16.0,
              maxZoom: 19.0,
              initialRotation: -_heading,
              // When user touches the map, auto-recenter after 2s
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _userPosition != null) {
                  // Let user look around briefly, then snap back
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted && _userPosition != null) {
                      _mapController.move(_userPosition!, _mapController.camera.zoom);
                    }
                  });
                }
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.pinchMove,
                // DISABLE drag and rotate — Pokémon GO locks the camera
              ),
            ),
            children: [
              // High-saturation tiles
              TileLayer(
                urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.placetalk.app',
                maxZoom: 19,
              ),
              
              // Pin markers on actual map coordinates
              if (_userPosition != null)
                _buildPinMarkers(state),
            ],
          ),
          
          // ═══════════════════════════════════════════
          // LAYER 2: AVATAR + RADIUS RING (fixed overlay)
          // These are exactly at screen center. They NEVER
          // move when you interact with the map.
          // ═══════════════════════════════════════════
          
          // 50m radius ring
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
          
          // Walking Avatar
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseAnim, _bounceAnim]),
              builder: (context, _) {
                return Transform.translate(
                  offset: Offset(0, _bounceAnim.value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Direction arrow
                      Transform.rotate(
                        angle: 0,
                        child: const Icon(
                          Icons.navigation,
                          color: Color(0xFF6C63FF),
                          size: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Avatar circle
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
                      // Ground shadow
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
          
          // ═══════════════════════════════════════════
          // LAYER 3: TOP STATUS BAR
          // ═══════════════════════════════════════════
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: _buildTopBar(state),
          ),
          
          // ═══════════════════════════════════════════
          // LAYER 4: BOTTOM ACTION BAR (Pins, Create, Discover)
          // ═══════════════════════════════════════════
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(context, state),
          ),
          
          // ═══════════════════════════════════════════
          // LAYER 5: ZOOM CONTROLS
          // ═══════════════════════════════════════════
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

  // ──────────────────────────────────────────────
  // PIN MARKERS (on the actual map layer)
  // ──────────────────────────────────────────────
  Widget _buildPinMarkers(DiscoveryState state) {
    if (_userPosition == null) return const SizedBox();
    
    // Use discoveredPins from heartbeat/loadNearbyPins
    final discoveredPins = state.discoveredPins;
    
    if (discoveredPins.isEmpty) return const SizedBox();
    
    final nearbyPins = discoveredPins.where((pin) {
      final dist = Geolocator.distanceBetween(
        _userPosition!.latitude, _userPosition!.longitude,
        pin.lat, pin.lon,
      );
      return dist <= 50; // Show within 50m on map
    }).toList();

    return MarkerLayer(
      markers: nearbyPins.map((pin) {
        final dist = Geolocator.distanceBetween(
          _userPosition!.latitude, _userPosition!.longitude,
          pin.lat, pin.lon,
        );
        final isInRange = dist <= 50;
        final color = pin.type == 'sensation' 
            ? const Color(0xFF9C27B0) 
            : const Color(0xFF4CAF50);

        return Marker(
          point: LatLng(pin.lat, pin.lon),
          width: 60,
          height: 80,
          child: GestureDetector(
            onTap: () => _showPinSheet(pin, dist),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Distance badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isInRange ? color : Colors.grey[400],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${dist.toInt()}m',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 2),
                // Pin icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isInRange ? color : Colors.grey[400],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: isInRange
                        ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)]
                        : null,
                  ),
                  child: Icon(
                    pin.type == 'sensation' ? Icons.auto_awesome : Icons.place,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
  void _showPinSheet(Pin pin, double dist) {
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
            // Title
            Row(children: [
              Icon(pin.type == 'location' ? Icons.place : Icons.auto_awesome,
                color: pin.type == 'location' ? Colors.green : Colors.purple, size: 26),
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
            Text(pin.directions, style: const TextStyle(fontSize: 15, height: 1.4)),
            if (pin.details != null) ...[
              const SizedBox(height: 6),
              Text(pin.details!, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
            const SizedBox(height: 16),
            // Like/Dislike
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(discoveryProvider.notifier).likePin(pin.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.thumb_up, color: Color(0xFF4CAF50)),
                label: Text('Like (${pin.likeCount})', style: const TextStyle(color: Color(0xFF4CAF50))),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF4CAF50)), padding: const EdgeInsets.symmetric(vertical: 12)),
              )),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(discoveryProvider.notifier).dislikePin(pin.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.thumb_down, color: Colors.red),
                label: Text('Dislike (${pin.dislikeCount})', style: const TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12)),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // PIN LIST
  // ──────────────────────────────────────────────
  void _showPinList() {
    final discoveredPins = ref.read(discoveryProvider).discoveredPins;
    
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
                Text('Discovered Pins (${discoveredPins.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
            ),
            Expanded(
              child: discoveredPins.isEmpty
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.explore_off, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No pins discovered yet. Walk around to find pins!', style: TextStyle(color: Colors.grey)),
                    ]))
                  : ListView.builder(
                      controller: sc,
                      itemCount: discoveredPins.length,
                      itemBuilder: (ctx, i) {
                        final pin = discoveredPins[i];
                        final dist = _userPosition != null
                            ? Geolocator.distanceBetween(
                                _userPosition!.latitude, _userPosition!.longitude, pin.lat, pin.lon)
                            : 0.0;
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: pin.type == 'location' ? Colors.green.withOpacity(0.1) : Colors.purple.withOpacity(0.1),
                            child: Icon(pin.type == 'location' ? Icons.place : Icons.auto_awesome,
                              color: pin.type == 'location' ? Colors.green : Colors.purple),
                          ),
                          title: Text(pin.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${dist.toInt()}m away • ${pin.likeCount} likes'),
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
}
