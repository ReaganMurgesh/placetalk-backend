import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:confetti/confetti.dart';
import 'package:placetalk/services/location_service.dart';
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

  final String _pinType = 'location';
  String _pinCategory = 'normal';
  bool _isLoading = false;
  Position? _currentPosition;
  
  // Safety & Privacy Checks
  bool _isPublicSpace = false;
  bool _respectsPrivacy = false;
  bool _followsGuidelines = false;
  bool _noPrivateProperty = false;
  
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
    
    setState(() => _isLoading = true);

    try {
      final locationService = ref.read(locationServiceProvider);
      
      // Get FRESH GPS coordinates (high accuracy) at the exact moment of pin creation
      print('🎯 CreatePinScreen: Getting FRESH GPS coordinates for pin creation...');
      final position = await locationService.getCurrentPosition();
      print('✅ CreatePinScreen: Fresh coordinates - Lat: ${position.latitude}, Lon: ${position.longitude}');
      
      setState(() => _isLoading = false);
      
      // Check if still mounted before using context
      if (!mounted) return;
      
      // SHOW GPS COORDINATES TO USER WITH ACCURACY INFO
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('📍 Confirm Pin Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gps_fixed, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text('GPS Accuracy: ${position.accuracy.toStringAsFixed(1)}m'),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📍 Latitude: ${position.latitude.toStringAsFixed(6)}'),
                    Text('📍 Longitude: ${position.longitude.toStringAsFixed(6)}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Pin will be created at this exact GPS location.', 
                style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create Pin'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) {
        setState(() => _isLoading = false);
        return;
      }
      
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
        lat: position.latitude,  // Use fresh coordinates
        lon: position.longitude, // Use fresh coordinates
        type: _pinType,
        pinCategory: _pinCategory,
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
                          : '📍 Pin created! Others can discover this for 72 hours.',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create pin: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                      onTap: () => setState(() => _pinCategory = 'normal'),
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
                      onTap: () => setState(() => _pinCategory = 'community'),
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
                ],
              ),

              const SizedBox(height: 24),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  hintText: 'e.g. Hidden cafe, Beautiful sunset spot',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.title),
                ),
                maxLength: 100,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter a title';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Directions
              TextFormField(
                controller: _directionsController,
                decoration: InputDecoration(
                  labelText: 'Directions *',
                  hintText: 'Behind the blue building, second door',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.directions),
                ),
                maxLines: 2,
                maxLength: 200,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter directions';
                  return null;
                },
            ),

            const SizedBox(height: 12),

            // Details
            TextFormField(
              controller: _detailsController,
              decoration: InputDecoration(
                labelText: 'Details (Optional)',
                hintText: 'Great coffee, quiet atmosphere...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 3,
              maxLength: 500,
            ),

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
                'Pin visible to users within 50m for 72 hours',
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
