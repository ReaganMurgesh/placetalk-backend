import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:placetalk/models/diary.dart' hide Badge;
import 'package:placetalk/models/diary.dart' as diary show Badge;
import 'package:placetalk/services/api_client.dart';
import 'package:placetalk/providers/auth_provider.dart';
import 'package:placetalk/theme/japanese_theme.dart';

final diaryStatsProvider = FutureProvider<UserStats>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final statsJson = await apiClient.getDiaryStats();
  return UserStats.fromJson(statsJson);
});

final myPinsProvider = FutureProvider<List<Pin>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return apiClient.getMyPins();
});

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diaryStatsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Serendipity Diary'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(diaryStatsProvider);
                ref.invalidate(diaryTimelineProvider);
                ref.invalidate(myPinsProvider);
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: JapaneseColors.toriiRed,
            labelColor: JapaneseColors.toriiRed,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.history), text: 'Passed Pins'),
              Tab(icon: Icon(Icons.place), text: 'My Pins'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Stats header (Always visible)
            statsAsync.when(
              data: (stats) => _StatsHeader(stats: stats),
              loading:() => const LinearProgressIndicator(),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading stats', style: TextStyle(color: Colors.red)),
              ),
            ),
            const Divider(height: 1),
            // Tab Views
            Expanded(
              child: TabBarView(
                children: [
                  _ExploredTab(),
                  _MyPinsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploredTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(diaryTimelineProvider);

    return timelineAsync.when(
      data: (timeline) {
        if (timeline.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.explore_outlined, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No adventures yet.', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: timeline.length,
          itemBuilder: (context, index) {
            return _TimelineCard(
              entry: timeline[index],
              isFirst: index == 0,
              isLast: index == timeline.length - 1,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _MyPinsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myPinsAsync = ref.watch(myPinsProvider);

    return myPinsAsync.when(
      data: (pins) {
        if (pins.isEmpty) {
          return const Center(child: Text('You haven\'t created any pins yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pins.length,
          itemBuilder: (context, index) {
            final pin = pins[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: pin.pinCategory == 'community' ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    pin.pinCategory == 'community' ? Icons.groups : Icons.place,
                    color: pin.pinCategory == 'community' ? Colors.orange : Colors.green,
                  ),
                ),
                title: Text(pin.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Likes: ${pin.likeCount} • Dislikes: ${pin.dislikeCount}'),
                trailing: pin.pinCategory == 'community' 
                    ? const Chip(label: Text('Infinite'), backgroundColor: Colors.orangeAccent, labelStyle: TextStyle(fontSize: 10))
                    : const Chip(label: Text('Active'), backgroundColor: Colors.greenAccent, labelStyle: TextStyle(fontSize: 10)),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final UserStats stats;

  const _StatsHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [JapaneseColors.wakatake.withOpacity(0.1), JapaneseColors.sakura],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Streak counter
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '🔥',
                style: TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stats.currentStreak} Day Streak',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: JapaneseColors.sumi,
                    ),
                  ),
                  Text(
                    'Longest: ${stats.longestStreak} days',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Activity count
          Text(
            '${stats.totalActivities} total activities',
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          // Badges
          if (stats.badges.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: stats.badges.map((badge) => _BadgeChip(badge: badge)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final diary.Badge badge;

  const _BadgeChip({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: JapaneseColors.kogane.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: JapaneseColors.kogane, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              badge.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: JapaneseColors.sumi,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final TimelineEntry entry;
  final bool isFirst;
  final bool isLast;

  const _TimelineCard({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final attributeColor = getPinAttributeColor(entry.pinAttribute);

    return TimelineTile(
      isFirst: isFirst,
      isLast: isLast,
      alignment: TimelineAlign.manual,
      lineXY: 0.15,
      indicatorStyle: IndicatorStyle(
        width: 40,
        height: 40,
        indicator: Container(
          decoration: BoxDecoration(
            color: attributeColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: attributeColor.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              entry.activityEmoji,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
      beforeLineStyle: LineStyle(
        color: Colors.grey[300]!,
        thickness: 2,
      ),
      endChild: Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 24),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.activityLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: JapaneseColors.sumi,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: attributeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        entry.pinAttribute ?? 'pin',
                        style: TextStyle(
                          fontSize: 12,
                          color: attributeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.pinTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(entry.createdAt),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
