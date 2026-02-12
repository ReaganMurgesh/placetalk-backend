import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:placetalk/models/pin.dart';

class DiscoveredPinsScreen extends ConsumerWidget {
  const DiscoveredPinsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This will be connected to discovery provider later
    final List<Pin> pins = []; // Placeholder

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discovered Pins'),
      ),
      body: pins.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.explore_off,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pins discovered yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Walk around to discover serendipitous moments!',
                    style: TextStyle(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pins.length,
              itemBuilder: (context, index) {
                final pin = pins[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: pin.isLocationPin
                          ? Colors.blue
                          : Colors.purple,
                      child: Icon(
                        pin.isLocationPin
                            ? Icons.location_on
                            : Icons.auto_awesome,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(pin.title),
                    subtitle: Text(pin.directions),
                    trailing: Text(pin.distanceText),
                    onTap: () {
                      // Show pin details
                    },
                  ),
                );
              },
            ),
    );
  }
}
