import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:confetti/confetti.dart';
import 'package:dio/dio.dart';
import 'package:placetalk/services/location_service.dart';
import 'package:placetalk/services/geocoding_service.dart';
import 'package:placetalk/providers/discovery_provider.dart';
import 'package:placetalk/providers/auth_provider.dart';

class CreatePinScreen extends ConsumerStatefulWidget {
  const CreatePinScreen({super.key});

  @override
  ConsumerState<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends ConsumerState<CreatePinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _directionsController = TextEditingController();
  final _detailsController = TextEditingController();
  final _rulesController = TextEditingController();
  final _externalLinkController = TextEditingController(); // spec 2.2

  final String _pinType = 'location';
  String _pinCategory = 'normal';
  bool _chatEnabled = false; // spec 2.2: community pins only
  bool _isPrivate = false;   // spec 2.3: Paid/restricted pin
  bool _isLoading = false;
  Position? _currentPosition;
  
  // Safety & Privacy Checks
  bool _isPublicSpace = false;
  bool _respectsPrivacy = false;
  bool _followsGuidelines = false;
  bool _noPrivateProperty = false;

  // --- Phase 1a: GPS fine-tuning ---
  // User-adjusted pin position from the fine-tune map (overrides raw GPS on create)
  LatLng? _fineTunedLatLng;

  // Address label from LocationIQ reverse geocoding
  String? _addressLabel;
  
  // Confetti controller
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _directionsController.dispose();
    _detailsController.dispose();
    _rulesController.dispose();
    _confettiController.dispose();
    _externalLinkController.dispose();
    super.dispose();
  }

  bool _canCreatePin() {
    return _isPublicSpace && 
           _respectsPrivacy && 
           _followsGuidelines && 
           _noPrivateProperty &&
           _currentPosition != null;
  }

  Future<void> _getCurrentLocation() async {
    try {
      print('🎯 CreatePinScreen: Getting current location...');
      final locationService = ref.read(locationServiceProvider);
      final position = await locationService.getCurrentPosition();
      
      print('✅ CreatePinScreen: Received position - Lat: ${position.latitude}, Lon: ${position.longitude}');
      
      setState(() {
        _currentPosition = position;
      });

      // Reverse geocode in background — show address once resolved
      GeocodingService.reverseGeocode(position.latitude, position.longitude).then((addr) {
        if (addr != null && mounted) setState(() => _addressLabel = addr.display);
      });
    } catch (e) {
      print('❌ CreatePinScreen: Location error - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPS Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _createPin() async {
    if (!_formKey.currentState!.validate()) return;

    // Spec 2.1: Coordinates locked at screen open — do NOT fetch fresh GPS
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Still acquiring GPS — please wait a moment.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Show fine-tune dialog with the LOCKED position (spec 2.1)
      setState(() => _isLoading = false);
      if (!mounted) return;

      final confirmed = await _showGpsFineTuneDialog(_currentPosition!);
      if (confirmed != true) {
        setState(() => _isLoading = false);
        return;
      }

      // Use fine-tuned position if set, otherwise the locked GPS position (spec 2.1)
      final double finalLat = _fineTunedLatLng?.latitude ?? _currentPosition!.latitude;
      final double finalLon = _fineTunedLatLng?.longitude ?? _currentPosition!.longitude;
      
      setState(() => _isLoading = true);
      
      final apiClient = ref.read(apiClientProvider);
      
      // Call REAL backend API — saves to PostGIS + Redis
      
      // Prepare details with rules
      String? finalDetails = _detailsController.text.trim();
      if (_rulesController.text.trim().isNotEmpty) {
        finalDetails = finalDetails.isNotEmpty == true 
            ? '$finalDetails\n\n📋 Rules: ${_rulesController.text.trim()}'
            : '📋 Rules: ${_rulesController.text.trim()}';
      }
      
      final pin = await apiClient.createPin(
        title: _titleController.text.trim(),
        directions: _directionsController.text.trim(),
        details: finalDetails,
        lat: finalLat,
        lon: finalLon,
        type: _pinType,
        pinCategory: _pinCategory,
        externalLink: _externalLinkController.text.trim().isEmpty
            ? null
            : _externalLinkController.text.trim(),
        chatEnabled: _pinCategory == 'community' ? _chatEnabled : false,
        isPrivate: _isPrivate,
      );

      // For community pins: auto-create/join the community chat room
      if (_pinCategory == 'community') {
        try {
          // findOrCreateCommunity also auto-joins the creator
          await apiClient.findOrCreateCommunity(_titleController.text.trim());
        } catch (e) {
          // Non-fatal — pin is already created, community creation is best-effort
          print('⚠️ Community auto-create failed: $e');
        }
      }

      // Add to local state too
      ref.read(discoveryProvider.notifier).addCreatedPin(pin);

      if (mounted) {
        // Play confetti celebration!
        _confettiController.play();
        
        // Show success dialog with confetti
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Stack(
            alignment: Alignment.topCenter,
            children: [
              AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Row(
                  children: [
                    Text('🎉', style: TextStyle(fontSize: 32)),
                    SizedBox(width: 12),
                    Text('Pin Created!'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '"${pin.title}"',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _pinCategory == 'community' 
                          ? '🏛️ Community pin created! Others can discover this forever.'
                          : '📍 Pin created! Others can discover this for 1 year.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Awesome!'),
                  ),
                ],
              ),
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                maxBlastForce: 20,
                minBlastForce: 8,
                emissionFrequency: 0.05,
                numberOfParticles: 30,
                gravity: 0.2,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.yellow,
                ],
              ),
            ],
          ),
        );
        
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String msg;
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map) {
            msg = data['error']?.toString() ?? data['message']?.toString() ?? 'Server error ${e.response?.statusCode}';
          } else {
            msg = 'Network error (${e.type.name})';
          }
        } else {
          msg = e.toString();
        }
        final isQuota = msg.contains('429') || msg.toLowerCase().contains('daily limit') || msg.toLowerCase().contains('per day');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isQuota
                ? '💫 Daily limit reached \u2014 you can drop up to 3 pins per day.'
                : 'Pin creation failed: $msg'),
            backgroundColor: isQuota ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─────────────────────────────────────────────
  // GPS Fine-Tune Dialog (Phase 1a)
  // ─────────────────────────────────────────────
  Future<bool?> _showGpsFineTuneDialog(Position gpsPosition) async {
    final gpsLatLng = LatLng(gpsPosition.latitude, gpsPosition.longitude);
    LatLng pinLatLng = gpsLatLng;
    // Max 5m offset in degrees (1m ≈ 0.000009 deg at equator)
    const maxDeltaDeg = 0.000045; // ~5m

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.tune, color: Color(0xFF6C63FF)),
              SizedBox(width: 8),
              Expanded(child: Text('Fine-tune Pin Location', overflow: TextOverflow.ellipsis)),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: gpsLatLng,
                      initialZoom: 20.0,
                      maxZoom: 21.0,
                      minZoom: 19.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom | InteractiveFlag.pinchMove,
                      ),
                      onTap: (_, latlng) {
                        // Clamp to ±5m around true GPS
                        final dLat = (latlng.latitude - gpsLatLng.latitude)
                            .clamp(-maxDeltaDeg, maxDeltaDeg);
                        final dLon = (latlng.longitude - gpsLatLng.longitude)
                            .clamp(-maxDeltaDeg, maxDeltaDeg);
                        final clamped = LatLng(
                          gpsLatLng.latitude + dLat,
                          gpsLatLng.longitude + dLon,
                        );
                        setS(() => pinLatLng = clamped);
                        // Propagate up so _createPin reads it
                        setState(() => _fineTunedLatLng = clamped);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                        userAgentPackageName: 'com.placetalk.app',
                      ),
                      MarkerLayer(
                        markers: [
                          // True GPS reference (blue dot)
                          Marker(
                            point: gpsLatLng,
                            width: 16,
                            height: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.5),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.blue, width: 2),
                              ),
                            ),
                          ),
                          // Adjusted pin (red)
                          Marker(
                            point: pinLatLng,
                            width: 36,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: const Icon(Icons.location_on,
                                color: Colors.red, size: 36),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Hint overlay
                Positioned(
                  bottom: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Tap map to adjust (max 5m from GPS 🔵)',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _fineTunedLatLng = null);
                Navigator.pop(ctx, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check, size: 18, color: Colors.white),
              label: const Text('Confirm', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FF),
      appBar: AppBar(
        title: const Text('Create Pin', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // GPS Status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _currentPosition != null
                        ? [const Color(0xFF4CAF50).withOpacity(0.1), const Color(0xFF4CAF50).withOpacity(0.05)]
                        : [Colors.orange.withOpacity(0.1), Colors.orange.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _currentPosition != null
                        ? const Color(0xFF4CAF50).withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _currentPosition != null ? Icons.gps_fixed : Icons.gps_not_fixed,
                      color: _currentPosition != null ? const Color(0xFF4CAF50) : Colors.orange,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _currentPosition != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('GPS Ready', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                Text(
                                  '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                if (_addressLabel != null) ...[  
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_city, size: 12, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          _addressLabel!,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            )
                          : const Row(
                              children: [
                                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 8),
                                Text('Getting GPS location...'),
                              ],
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Pin Category Selector
              const Text('Pin Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { _pinCategory = 'normal'; _isPrivate = false; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _pinCategory == 'normal' ? const Color(0xFF4CAF50).withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _pinCategory == 'normal' ? const Color(0xFF4CAF50) : Colors.grey[300]!,
                            width: _pinCategory == 'normal' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.place, color: _pinCategory == 'normal' ? const Color(0xFF4CAF50) : Colors.grey, size: 28),
                            const SizedBox(height: 4),
                            Text('Normal', style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _pinCategory == 'normal' ? const Color(0xFF4CAF50) : Colors.grey,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { _pinCategory = 'community'; _isPrivate = false; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _pinCategory == 'community' ? const Color(0xFFFF9800).withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _pinCategory == 'community' ? const Color(0xFFFF9800) : Colors.grey[300]!,
                            width: _pinCategory == 'community' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.groups, color: _pinCategory == 'community' ? const Color(0xFFFF9800) : Colors.grey, size: 28),
                            const SizedBox(height: 4),
                            Text('Community', style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _pinCategory == 'community' ? const Color(0xFFFF9800) : Colors.grey,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // spec 2.3: Paid/Restricted pin
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _pinCategory = 'paid';
                        _isPrivate = true;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _pinCategory == 'paid' ? Colors.deepPurple.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _pinCategory == 'paid' ? Colors.deepPurple : Colors.grey[300]!,
                            width: _pinCategory == 'paid' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.lock, color: _pinCategory == 'paid' ? Colors.deepPurple : Colors.grey, size: 28),
                            const SizedBox(height: 4),
                            Text('Paid 🔒', style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _pinCategory == 'paid' ? Colors.deepPurple : Colors.grey,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_pinCategory == 'paid') ...[  
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepPurple[200]!),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.deepPurple),
                    SizedBox(width: 6),
                    Expanded(child: Text(
                      'Paid/restricted pin — only visible to you and invited users. For closed events & B2B use.',
                      style: TextStyle(fontSize: 12, color: Colors.deepPurple),
                    )),
                  ]),
                ),
              ],

              const SizedBox(height: 24),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title * (max 10 chars)',
                  hintText: 'e.g. Cafe, Sunset',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.title),
                  counterText: '',
                ),
                maxLength: 10,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter a title';
                  if (value.trim().length > 10) return 'Title must be 10 characters or less';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Directions
              TextFormField(
                controller: _directionsController,
                decoration: InputDecoration(
                  labelText: 'Directions Hint * (how to find this place)',
                  hintText: 'Past the blue roof, second door on left...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.directions),
                  helperText: 'Visible within 50 m. Describe how to find this spot (5–300 chars).',
                ),
                maxLines: 2,
                maxLength: 300,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter directions';
                  if (value.trim().length < 5) return 'Too short — describe how to find this place';
                  return null;
                },
            ),

            const SizedBox(height: 12),

            // Details
            TextFormField(
              controller: _detailsController,
              decoration: InputDecoration(
                labelText: 'Details (optional)',
                hintText: 'Great coffee, quiet atmosphere...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.description),
                helperText: 'Unlocked within 20 m. Up to 500 characters.',
              ),
              maxLines: 3,
              maxLength: 500,
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.length > 500) return 'Details must be 500 characters or less';
                return null;
              },
            ),

            const SizedBox(height: 12),

            // External Link
            TextFormField(
              controller: _externalLinkController,
              decoration: InputDecoration(
                labelText: 'External Link (optional URL)',
                hintText: 'https://example.com',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.link),
                helperText: 'Shown as a button below the pin details.',
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isNotEmpty && !v.startsWith('http')) return 'Must start with http:// or https://';
                return null;
              },
            ),

            const SizedBox(height: 12),

            // Chat ON/OFF (community pins only)
            if (_pinCategory == 'community') ...[  
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.chat_bubble_outline, color: Color(0xFFFF9800)),
                  title: const Text('Community Chat', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Enable Q&A comment section for this pin'),
                  value: _chatEnabled,
                  onChanged: (v) => setState(() => _chatEnabled = v),
                  activeColor: const Color(0xFFFF9800),
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 16),

            // Rules & Guidelines (NEW)
            TextFormField(
              controller: _rulesController,
              decoration: InputDecoration(
                labelText: 'Rules & Guidelines for this Area',
                hintText: 'e.g., "Quiet zone - please speak softly", "Clean up after yourself"...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.rule, color: Colors.deepPurple),
              ),
              maxLines: 2,
              maxLength: 200,
            ),

            const SizedBox(height: 24),

            // 🏗️ PUBLIC SAFETY CHECKLIST
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Text('Privacy & Safety Checklist', 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red[700])),
                      const Spacer(),
                      // Show progress count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _canCreatePin() ? Colors.green : Colors.red[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${[_isPublicSpace, _respectsPrivacy, _followsGuidelines, _noPrivateProperty].where((b) => b).length}/4',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _canCreatePin() ? Colors.white : Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Please confirm before creating your pin:', 
                    style: TextStyle(color: Colors.red[600])),
                  const SizedBox(height: 12),
                  
                  CheckboxListTile(
                    title: const Text('This is a PUBLIC space (not private property)', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Parks, cafes, streets, etc. - NOT someone\'s home', style: TextStyle(fontSize: 12)),
                    value: _isPublicSpace,
                    onChanged: (value) => setState(() => _isPublicSpace = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.green,
                  ),
                  
                  CheckboxListTile(
                    title: const Text('I respect privacy and local customs', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Won\'t disturb residents or private businesses', style: TextStyle(fontSize: 12)),
                    value: _respectsPrivacy,
                    onChanged: (value) => setState(() => _respectsPrivacy = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.green,
                  ),
                  
                  CheckboxListTile(
                    title: const Text('I follow community guidelines', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('This pin follows PlaceTalk\'s community standards', style: TextStyle(fontSize: 12)),
                    value: _followsGuidelines,
                    onChanged: (value) => setState(() => _followsGuidelines = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.green,
                  ),
                  
                  CheckboxListTile(
                    title: const Text('No private homes or restricted areas', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('I will not pin private residences or secure facilities', style: TextStyle(fontSize: 12)),
                    value: _noPrivateProperty,
                    onChanged: (value) => setState(() => _noPrivateProperty = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.green,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Helper text showing WHY button is disabled
            if (!_canCreatePin() && !_isLoading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentPosition == null
                              ? 'Waiting for GPS... Walk outside for better signal.'
                              : 'Tick all ${[_isPublicSpace, _respectsPrivacy, _followsGuidelines, _noPrivateProperty].where((b) => !b).length} remaining checkbox(es) above to enable the button.',
                          style: TextStyle(fontSize: 13, color: Colors.orange[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Create Button
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: _canCreatePin() ? 
                  const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3F3D9B)]) :
                  LinearGradient(colors: [Colors.grey[400]!, Colors.grey[500]!]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: _canCreatePin() ? [
                  BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                ] : null,
              ),
              child: ElevatedButton.icon(
                onPressed: (_isLoading || !_canCreatePin()) ? null : _createPin,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.add_location, color: _canCreatePin() ? Colors.white : Colors.grey[600]),
                label: Text(
                  _isLoading ? 'Creating...' : 'Drop Pin Here 📍',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, 
                    color: _canCreatePin() ? Colors.white : Colors.grey[600]),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
              const SizedBox(height: 12),
              Text(
                _pinCategory == 'community'
                    ? '🏛️ Community pin — permanent, links to a community chat room'
                    : 'Pin visible to users within 50m for 1 year',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
