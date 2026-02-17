import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placetalk/screens/home/home_screen.dart';
import 'package:placetalk/screens/auth/login_screen.dart';
import 'package:placetalk/screens/pins/create_pin_screen.dart';
import 'package:placetalk/services/notification_service.dart';
import 'package:placetalk/services/proximity_tracker.dart';
import 'package:placetalk/providers/discovery_provider.dart';
import 'package:placetalk/providers/auth_provider.dart';
import 'package:placetalk/providers/locale_provider.dart';
import 'package:placetalk/l10n/app_localizations.dart';

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
    // Initialize notifications with action handler
    await ref.read(notificationServiceProvider).initializeWithActions(_handleNotificationAction);
    
    // Initialize proximity tracker for automatic notifications
    ref.read(proximityTrackingProvider);
    
    print('✅ App services initialized (notifications + proximity tracking)');
  }

  /// Handle notification action buttons (Good/Bad)
  void _handleNotificationAction(String? action, String? pinId) {
    if (action == null || pinId == null) return;

    print('🔔 Notification action: $action for pin $pinId');

    if (action == 'good') {
      ref.read(discoveryProvider.notifier).markPinAsGood(pinId);
    } else if (action == 'bad') {
      ref.read(discoveryProvider.notifier).markPinAsBad(pinId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    
    return MaterialApp(
      title: 'PlaceTalk',
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('en'), // English
        Locale('ja'), // Japanese
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF68BE8D), // Wakatake green
          brightness: Brightness.light,
        ),
        fontFamily: GoogleFonts.notoSansJp().fontFamily,
      ),
      home: const AuthCheck(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/create-pin': (context) => const CreatePinScreen(),
      },
    );
  }
}

// Authentication check widget
class AuthCheck extends ConsumerWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // Show login screen if not authenticated
    if (!authState.isAuthenticated) {
      return const LoginScreen();
    }

    // Show home screen if authenticated
    return const HomeScreen();
  }
}
