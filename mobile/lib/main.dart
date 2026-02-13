import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placetalk/screens/home/home_screen.dart';
import 'package:placetalk/screens/pins/create_pin_screen.dart';
import 'package:placetalk/services/notification_service.dart';
import 'package:placetalk/services/proximity_tracker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    const ProviderScope(
      child: PlaceTalkApp(),
    ),
  );
}

class PlaceTalkApp extends ConsumerStatefulWidget {
  const PlaceTalkApp({super.key});

  @override
  ConsumerState<PlaceTalkApp> createState() => _PlaceTalkAppState();
}

class _PlaceTalkAppState extends ConsumerState<PlaceTalkApp> {
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await ref.read(notificationServiceProvider).initialize();
    // Initialize proximity tracker for automatic notifications
    ref.read(proximityTrackingProvider);
    print('✅ App services initialized (notifications + proximity tracking)');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlaceTalk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const HomeScreen(),
      routes: {
        '/create-pin': (context) => const CreatePinScreen(),
      },
    );
  }
}
