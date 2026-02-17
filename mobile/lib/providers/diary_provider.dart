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
