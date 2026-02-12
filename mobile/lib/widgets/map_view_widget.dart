import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:placetalk/providers/discovery_provider.dart';

class MapViewWidget extends ConsumerStatefulWidget {
  const MapViewWidget({super.key});

  @override
  ConsumerState<MapViewWidget> createState() => _MapViewWidgetState();
}

class _MapViewWidgetState extends ConsumerState<MapViewWidget> {
  final MapController _mapController = MapController();
  Position? _lastKnownPosition;

  @override
  void didUpdateWidget(MapViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateMapCenter();
  }

  void _updateMapCenter() {
    final discoveryState = ref.read(discoveryProvider);
    final newPosition = discoveryState.lastPosition;
    
    // Auto-center map when GPS position changes
    if (newPosition != null && 
        (_lastKnownPosition == null || 
         _hasMovedSignificantly(_lastKnownPosition!, newPosition))) {
      _lastKnownPosition = newPosition;
      
      // Move map to new position smoothly
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(
            LatLng(newPosition.latitude, newPosition.longitude),
            _mapController.camera.zoom,
          );
        }
      });
    }
  }

  bool _hasMovedSignificantly(Position old, Position newPos) {
    const threshold = 5.0; // 5 meters
    final distance = Geolocator.distanceBetween(
      old.latitude,
      old.longitude,
      newPos.latitude,
      newPos.longitude,
    );
    return distance > threshold;
  }

  @override
  Widget build(BuildContext context) {
    final discoveryState = ref.watch(discoveryProvider);
    final lastPosition = discoveryState.lastPosition;
    final allPins = discoveryState.allPins; // Discovered + Created pins

    // Default center
    final center = lastPosition != null
        ? LatLng(lastPosition.latitude, lastPosition.longitude)
        : const LatLng(33.0, 130.0);
    
    print('🗺️ Map: ${allPins.length} pins (discovered: ${discoveryState.discoveredPins.length}, created: ${discoveryState.createdPins.length}), GPS: ${lastPosition != null}');

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 17.0,
              minZoom: 5.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // OSM Tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.placetalk.app',
              ),

              // 50m Circle - ACCURATE GEOSPATIAL RADIUS (doesn't change with zoom)
              if (lastPosition != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(lastPosition.latitude, lastPosition.longitude),
                      // Calculate radius in meters (true 50m on ground)
                      // At equator: 1 degree ≈ 111km, so 50m ≈ 0.00045 degrees
                      // Adjust for latitude using cosine
                      useRadiusInMeter: true,
                      radius: 50, // 50 meters actual distance
                      color: Colors.blue.withOpacity(0.15),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // Pin markers
                  ...allPins.map((pin) {
                    final isPurple = pin.type == 'serendipity';
                    print('📍 Pin: ${pin.title} at ${pin.lat},${pin.lon}');
                    return Marker(
                      point: LatLng(pin.lat, pin.lon),
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => _showPinDetails(pin),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isPurple ? Colors.purple : Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            isPurple ? Icons.auto_awesome : Icons.place,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    );
                  }),

                  // User marker
                  if (lastPosition != null)
                    Marker(
                      point: LatLng(lastPosition.latitude, lastPosition.longitude),
                      width: 70,
                      height: 70,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.6),
                                blurRadius: 15,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // GPS overlay
          if (lastPosition != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'GPS Location',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const Spacer(),
                        if (allPins.isNotEmpty)
                          Text(
                            '${allPins.length} pins',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${lastPosition.latitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'Lon: ${lastPosition.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Controls
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'recenter',
                  backgroundColor: Colors.blue,
                  onPressed: () {
                    if (lastPosition != null) {
                      _mapController.move(
                        LatLng(lastPosition.latitude, lastPosition.longitude),
                        17.0,
                      );
                    }
                  },
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPinDetails(dynamic pin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              pin.type == 'serendipity' ? Icons.auto_awesome : Icons.place,
              color: pin.type == 'serendipity' ? Colors.purple : Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(pin.title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Directions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(pin.directions),
            const SizedBox(height: 12),
            if (pin.details != null) ...[
              const Text(
                'Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(pin.details),
              const SizedBox(height: 12),
            ],
            Text(
              'Type: ${pin.type} • ${pin.pinCategory}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
