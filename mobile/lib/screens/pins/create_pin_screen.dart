import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:placetalk/services/location_service.dart';
import 'package:placetalk/services/api_client.dart';
import 'package:placetalk/models/pin.dart';
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

  String _pinType = 'location';
  String _pinCategory = 'normal';
  bool _isLoading = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _directionsController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationService = ref.read(locationServiceProvider);
      final position = await locationService.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e'), backgroundColor: Colors.red),
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
      final position = await locationService.getCurrentPosition();
      
      setState(() => _isLoading = false);
      
      // SHOW GPS COORDINATES TO USER
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('📍 GPS Coordinates'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Latitude: ${position.latitude.toStringAsFixed(6)}'),
              Text('Longitude: ${position.longitude.toStringAsFixed(6)}'),
              const SizedBox(height: 16),
              const Text('Create pin at this location?', style: TextStyle(fontWeight: FontWeight.bold)),
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
      final pin = await apiClient.createPin(
        title: _titleController.text.trim(),
        directions: _directionsController.text.trim(),
        details: _detailsController.text.trim().isNotEmpty 
            ? _detailsController.text.trim() 
            : null,
        lat: position.latitude,  // Use fresh coordinates
        lon: position.longitude, // Use fresh coordinates
        type: _pinType,
        pinCategory: _pinCategory,
      );

      // Add to local state too
      ref.read(discoveryProvider.notifier).addCreatedPin(pin);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Pin "${pin.title}" created and saved to server!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
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

              // Pin Type Selector
              const Text('Pin Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _pinType = 'location'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _pinType == 'location' ? const Color(0xFF4CAF50).withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _pinType == 'location' ? const Color(0xFF4CAF50) : Colors.grey[300]!,
                            width: _pinType == 'location' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.place, color: _pinType == 'location' ? const Color(0xFF4CAF50) : Colors.grey, size: 28),
                            const SizedBox(height: 4),
                            Text('Location', style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _pinType == 'location' ? const Color(0xFF4CAF50) : Colors.grey,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _pinType = 'sensation'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _pinType == 'sensation' ? const Color(0xFF9C27B0).withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _pinType == 'sensation' ? const Color(0xFF9C27B0) : Colors.grey[300]!,
                            width: _pinType == 'sensation' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.auto_awesome, color: _pinType == 'sensation' ? const Color(0xFF9C27B0) : Colors.grey, size: 28),
                            const SizedBox(height: 4),
                            Text('Sensation', style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _pinType == 'sensation' ? const Color(0xFF9C27B0) : Colors.grey,
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

              const SizedBox(height: 32),

              // Create Button
              Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3F3D9B)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createPin,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_location, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Creating...' : 'Drop Pin Here 📍',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
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
