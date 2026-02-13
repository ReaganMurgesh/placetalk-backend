import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notification service provider
final notificationServiceProvider = Provider((ref) => NotificationService());

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Function(String?, String?)? _actionCallback;

  /// Initialize notification service with action handler
  Future<void> initializeWithActions(Function(String?, String?)? actionCallback) async {
    _actionCallback = actionCallback;
    await initialize();
  }

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel
    const channel = AndroidNotificationChannel(
      'placetalk_proximity',
      'Pin Proximity Alerts',
      description: 'Notifications when you are near a pin',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
    print('✅ Notification service initialized');
  }

  /// Handle notification tap and actions
  void _onNotificationTap(NotificationResponse response) {
    print('Notification response: action=${response.actionId}, payload=${response.payload}');
    
    if (response.actionId != null && _actionCallback != null) {
      // Handle action button (Good/Bad)
      _actionCallback!(response.actionId, response.payload);
    } else {      // Regular tap - navigate to pin detail
      print('Notification tapped: ${response.payload}');
      // TODO: Navigate to pin detail screen
    }
  }

  /// Show proximity alert for a pin
  Future<void> showProximityAlert({
    required String pinId,
    required String pinTitle,
    required double distanceMeters,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'placetalk_proximity',
      'Pin Proximity Alerts',
      channelDescription: 'Notifications when you are near a pin',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      pinId.hashCode, // Unique ID per pin
      '📍 Pin Nearby!',
      '$pinTitle is ${distanceMeters.toStringAsFixed(0)}m away',
      notificationDetails,
      payload: pinId,
    );

    print('📬 Proximity notification sent for: $pinTitle ($distanceMeters m)');
  }

  /// Cancel notification for a pin
  Future<void> cancelProximityAlert(String pinId) async {
    await _notifications.cancel(pinId.hashCode);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Show discovery notification with title and compass direction
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'placetalk_proximity',
      'Pin Proximity Alerts',
      channelDescription: 'Notifications when you discover a pin',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );

    print('📬 Discovery notification: $title - $body');
  }
}
