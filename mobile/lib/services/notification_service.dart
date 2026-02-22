import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:placetalk/models/pin.dart';
import 'package:placetalk/services/geocoding_service.dart';

/// 1.4 Notification System
/// - First-encounter only (SharedPreferences-backed)
/// - Good → 7-day cooldown; Bad → permanent mute
/// - Sequential “pop-pop-pop” at 0.8 s
/// - Format: “[Title] @ [Place Name]” via LocationIQ
/// - Creator footprint channel (no action buttons)
final notificationServiceProvider = Provider((ref) => NotificationService());

class NotificationService {
  static const _kProxCh = 'placetalk_proximity';
  static const _kCreatorCh = 'placetalk_creator';
  static const _cooldown = Duration(days: 7);

  final _notif = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // SharedPreferences key helpers
  static String _seenKey(String id) => 'notif_seen_$id'; // ISO timestamp
  static String _goodKey(String id) => 'notif_good_$id'; // ISO timestamp of Good press
  static String _muteKey(String id) => 'notif_mute_$id'; // true = permanently muted

  Future<void> initialize() async {
    if (_initialized) return;
    await _notif.initialize(
      const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: _onResponse,
    );
    await _ensureChannel(_kProxCh, 'Pin Discovery Alerts',
        'Notifications when you first encounter a nearby pin', Importance.high);
    await _ensureChannel(_kCreatorCh, 'Creator Footprints',
        'Someone discovered one of your pins!', Importance.defaultImportance);
    _initialized = true;
    debugPrint('✅ NotificationService initialized');
  }

  Future<void> _ensureChannel(
      String id, String name, String desc, Importance imp) async {
    final ch = AndroidNotificationChannel(id, name,
        description: desc, importance: imp);
    await _notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(ch);
  }

  void _onResponse(NotificationResponse r) {
    final pinId = r.payload;
    if (pinId == null) return;
    if (r.actionId == 'good') _handleGood(pinId);
    if (r.actionId == 'bad') _handleBad(pinId);
  }

  // ── Eligibility ──────────────────────────────────────────

  Future<bool> isEligible(String pinId) async {
    final prefs = await SharedPreferences.getInstance();
    // Permanently muted → never
    if (prefs.getBool(_muteKey(pinId)) == true) return false;
    // Never seen before → eligible
    final seenTs = prefs.getString(_seenKey(pinId));
    if (seenTs == null) return true;
    // "Good" was pressed AND cooldown has expired → eligible again
    final goodTs = prefs.getString(_goodKey(pinId));
    if (goodTs != null) {
      final goodAt = DateTime.tryParse(goodTs);
      if (goodAt != null && DateTime.now().difference(goodAt) >= _cooldown) {
        return true;
      }
    }
    return false;
  }

  Future<void> _recordSeen(String pinId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenKey(pinId), DateTime.now().toIso8601String());
  }

  Future<void> _handleGood(String pinId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_goodKey(pinId), DateTime.now().toIso8601String());
    debugPrint('👍 Good → pin $pinId: 7-day cooldown set');
  }

  Future<void> _handleBad(String pinId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteKey(pinId), true);
    debugPrint('🔇 Bad → pin $pinId: permanently muted');
  }

  /// Unmute a pin — called from pin detail sheet if user wants to re-enable
  Future<void> unmute(String pinId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_muteKey(pinId));
    await prefs.remove(_goodKey(pinId));
    await prefs.remove(_seenKey(pinId));
    debugPrint('🔓 Unmuted pin $pinId');
  }

  // ── Sequential First-Encounter Notifications ─────────────────────

  /// Called from the map heartbeat.
  /// Filters to first-encounter pins only, reverse-geocodes each,
  /// and fires them sequentially with 0.8 s delay.
  Future<void> showFirstEncounterNotifications(List<Pin> pins) async {
    await initialize();
    final eligible = <Pin>[];
    for (final pin in pins) {
      if (await isEligible(pin.id)) eligible.add(pin);
    }
    if (eligible.isEmpty) return;
    debugPrint('🎰 Sequential notifs: ${eligible.length} first-encounter pin(s)');

    const androidDetails = AndroidNotificationDetails(
      _kProxCh,
      'Pin Discovery Alerts',
      channelDescription: 'Notifications when you first encounter a nearby pin',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('good', 'Good 👍',
            showsUserInterface: false, cancelNotification: true),
        AndroidNotificationAction('bad', 'Bad 🔇',
            showsUserInterface: false, cancelNotification: true),
      ],
    );

    for (int i = 0; i < eligible.length; i++) {
      final pin = eligible[i];
      // "[Title] @ [Place Name]" format
      String body = '';
      try {
        final addr =
            await GeocodingService.reverseGeocode(pin.lat, pin.lon);
        if (addr != null && addr.display.isNotEmpty) {
          body = '@ ${addr.display}';
        }
      } catch (_) {}

      await _notif.show(
        pin.id.hashCode ^ i,
        pin.title,
        body,
        const NotificationDetails(android: androidDetails),
        payload: pin.id,
      );
      await _recordSeen(pin.id);
      debugPrint('✅ ${i + 1}/${eligible.length}: ${pin.title} $body');

      if (i < eligible.length - 1) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
  }

  // ── Creator Footprint Notification ─────────────────────────────

  /// Shown when someone discovers the current user’s pin.
  /// Fired via Socket.io creator_alert event.
  Future<void> showCreatorAlert({
    required String pinTitle,
    required String placeName,
  }) async {
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      _kCreatorCh,
      'Creator Footprints',
      channelDescription: 'Someone discovered one of your pins!',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    final body = placeName.isNotEmpty
        ? '"$pinTitle" was discovered in $placeName'
        : '"$pinTitle" was just discovered nearby';
    await _notif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '👣 A new explorer found your pin!',
      body,
      const NotificationDetails(android: androidDetails),
    );
    debugPrint('👣 Creator alert: $pinTitle in $placeName');
  }

  // ── Legacy shim (backward-compat for scattered callers) ─────────────

  /// Kept so existing call-sites don’t break during migration.
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _kProxCh, 'Pin Discovery Alerts',
        channelDescription: 'Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _notif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  Future<void> cancelAll() async => _notif.cancelAll();
}
