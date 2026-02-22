import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:placetalk/models/diary.dart';
import 'package:placetalk/models/pin.dart';
import 'package:placetalk/providers/auth_provider.dart';

// User Stats (Streaks, Badges)
final diaryStatsProvider = FutureProvider<UserStats>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final statsJson = await apiClient.getDiaryStats();
  return UserStats.fromJson(statsJson);
});

// User Timeline (Passed Pins / Visited Pins)
final diaryTimelineProvider = FutureProvider<List<TimelineEntry>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
// api_client returns Future<List<dynamic>>
  final timelineData = await apiClient.getDiaryTimeline();
  // Ensure we cast appropriately if timelineData is List<dynamic>
  return timelineData.map((json) => TimelineEntry.fromJson(json as Map<String, dynamic>)).toList();
});

// My Created Pins with debug logging
final myPinsProvider = FutureProvider<List<Pin>>((ref) async {
  print('🔍 MyPinsProvider: Fetching user pins...');
  final apiClient = ref.watch(apiClientProvider);
  final userAsync = ref.watch(currentUserProvider);
  
  return userAsync.when(
    data: (user) async {
      if (user == null) {
        print('❌ MyPinsProvider: No user logged in');
        return [];
      }
      
      print('👤 MyPinsProvider: User ID = ${user.id}');
      print('👤 MyPinsProvider: User email = ${user.email}');
      
      final pins = await apiClient.getMyPins();
      print('📍 MyPinsProvider: Received ${pins.length} pins from API');
      
      for (int i = 0; i < pins.length; i++) {
        final pin = pins[i];
        print('📍 Pin $i: ${pin.title} (created by: ${pin.createdBy})');
      }
      
      return pins;
    },
    loading: () => [],
    error: (error, stack) {
      print('❌ MyPinsProvider: Error - $error');
      return [];
    },
  );
});

// ---------------------------------------------------------------------------
// spec 4.1 Tab 1 — Passive Log (ghost / verified)
// ---------------------------------------------------------------------------

/// 'recent' or 'like_count'
final passiveLogSortProvider = StateProvider<String>((ref) => 'recent');

final diaryPassiveLogProvider = FutureProvider<List<PassiveLogEntry>>((ref) async {
  final sort = ref.watch(passiveLogSortProvider);
  final apiClient = ref.watch(apiClientProvider);
  final raw = await apiClient.getDiaryPassiveLog(sort: sort);
  return raw
      .map((j) => PassiveLogEntry.fromJson(j as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// spec 4.1 Tab 2 — My Pins with engagement metrics
// ---------------------------------------------------------------------------

final myPinsMetricsProvider = FutureProvider<List<DiaryPinMetrics>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final raw = await apiClient.getDiaryMyPinsMetrics();
  return raw
      .map((j) => DiaryPinMetrics.fromJson(j as Map<String, dynamic>))
      .toList();
});

/// Stores the [DateTime] when the last manual sync finished (for 30 s cooldown).
final syncCooldownProvider = StateProvider<DateTime?>((ref) => null);

// ---------------------------------------------------------------------------
// spec 4.2 — Full-text search
// ---------------------------------------------------------------------------

final diarySearchQueryProvider = StateProvider<String>((ref) => '');

final diarySearchProvider = FutureProvider<List<DiarySearchResult>>((ref) async {
  final query = ref.watch(diarySearchQueryProvider).trim();
  if (query.isEmpty) return [];
  final apiClient = ref.watch(apiClientProvider);
  final raw = await apiClient.searchDiary(query);
  return raw
      .map((j) => DiarySearchResult.fromJson(j as Map<String, dynamic>))
      .toList();
});
