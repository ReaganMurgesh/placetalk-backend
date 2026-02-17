import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:placetalk/models/diary.dart' hide Badge;
import 'package:placetalk/models/diary.dart' as diary show Badge;
import 'package:placetalk/theme/japanese_theme.dart';
import 'package:placetalk/providers/diary_provider.dart';
import 'package:placetalk/providers/auth_provider.dart';
import 'package:placetalk/services/navigation_service.dart';
import 'package:confetti/confetti.dart';

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diaryStatsProvider);
    final currentUser = ref.watch(currentUserProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: CustomScrollView(
          slivers: [
            // Profile-like header
            SliverAppBar(
              expandedHeight: 280,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF667eea),
                        Color(0xFF764ba2),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Profile Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: Color(0xFF667eea),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // User Name
                        currentUser.when(
                          data: (user) => Text(
                            user?.name ?? 'Explorer',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          loading: () => const Text(
                            'Loading...',
                            style: TextStyle(color: Colors.white70),
                          ),
                          error: (_, __) => const Text(
                            'Explorer',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Serendipity Journal',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Stats Row
                        statsAsync.when(
                          data: (stats) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _StatItem(
                                icon: Icons.explore,
                                label: 'Discovered',
                                value: stats.totalDiscoveries.toString(),
                              ),
                              _StatItem(
                                icon: Icons.place,
                                label: 'Created',
                                value: stats.totalPinsCreated.toString(),
                              ),
                              _StatItem(
                                icon: Icons.star,
                                label: 'Badges',
                                value: stats.badges.length.toString(),
                              ),
                            ],
                          ),
                          loading: () => const CircularProgressIndicator(color: Colors.white),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    ref.invalidate(diaryStatsProvider);
                    ref.invalidate(diaryTimelineProvider);
                    ref.invalidate(myPinsProvider);
                  },
                ),
              ],
            ),
            // Tab Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: const Color(0xFF667eea),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 20),
                            SizedBox(width: 8),
                            Text('Discoveries'),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.place, size: 20),
                            SizedBox(width: 8),
                            Text('My Pins'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tab Content
            SliverFillRemaining(
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

// Statistics item widget for profile header
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

// Custom sliver delegate for tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _ExploredTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(diaryTimelineProvider);

    return timelineAsync.when(
      data: (timeline) {
        // Filter out "Created" pins (they belong in My Pins)
        final passedPins = timeline.where((e) => e.activityType != 'created').toList();

        if (passedPins.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.explore_outlined, 
                    size: 60, 
                    color: Colors.grey[400]
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Start Your Journey',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Discover pins around you to begin your serendipity adventure',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16, 
                    color: Colors.grey[600]
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: passedPins.length,
          itemBuilder: (context, index) {
            return _ModernTimelineCard(
              entry: passedPins[index],
              isFirst: index == 0,
              isLast: index == passedPins.length - 1,
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
        print('📱 DiaryScreen: Displaying ${pins.length} pins in My Pins tab');
        for (int i = 0; i < pins.length; i++) {
          final pin = pins[i];
          print('📱 Pin $i: "${pin.title}" (created_by: ${pin.createdBy})');
        }
        
        if (pins.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_location_alt_outlined,
                    size: 60,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Create Your First Pin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share interesting places you discover with other explorers',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }
        
        return RefreshIndicator(
          onRefresh: () async {
            print('🔄 DiaryScreen: FORCE REFRESH - Invalidating myPinsProvider');
            ref.invalidate(myPinsProvider);
            ref.invalidate(diaryStatsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pins.length + 1, // +1 for debug info
            itemBuilder: (context, index) {
              if (index == 0) {
                // Debug header
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DEBUG INFO:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Total pins shown: ${pins.length}'),
                      Text('Pull down to refresh data'),
                      if (pins.isNotEmpty)
                        Text('First pin: "${pins[0].title}" by ${pins[0].createdBy}'),
                    ],
                  ),
                );
              }
              
              final pin = pins[index - 1];
              return _ModernPinCard(pin: pin);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

// Modern pin card for "My Pins" tab with navigation
class _ModernPinCard extends ConsumerWidget {
  final dynamic pin;

  const _ModernPinCard({required this.pin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: pin.pinCategory == 'community' 
                          ? [Colors.orange.withOpacity(0.8), Colors.deepOrange.withOpacity(0.8)]
                          : [const Color(0xFF667eea), const Color(0xFF764ba2)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    pin.pinCategory == 'community' ? Icons.groups : Icons.place,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pin.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: pin.pinCategory == 'community' 
                              ? Colors.orange.withOpacity(0.1)
                              : const Color(0xFF667eea).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          pin.pinCategory == 'community' ? 'Infinite' : 'Active',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pin.pinCategory == 'community' 
                                ? Colors.orange[800]
                                : const Color(0xFF667eea),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatChip(
                  icon: Icons.thumb_up_outlined,
                  label: pin.likeCount.toString(),
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.thumb_down_outlined,
                  label: pin.dislikeCount.toString(),
                  color: Colors.red,
                ),
                const Spacer(),
                // Navigate button
                ElevatedButton.icon(
                  onPressed: () async {
                    final success = await NavigationService.navigateToPin(
                      pinLat: pin.lat,
                      pinLon: pin.lon,
                      pinTitle: pin.title,
                    );
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unable to open maps app'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Navigate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Modern timeline card for discoveries
class _ModernTimelineCard extends StatelessWidget {
  final dynamic entry;
  final bool isFirst;
  final bool isLast;

  const _ModernTimelineCard({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              if (!isFirst)
                Container(
                  width: 2,
                  height: 20,
                  color: Colors.grey[300],
                ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    entry.activityEmoji ?? '📍',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 60,
                  color: Colors.grey[300],
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.activityType?.toUpperCase() ?? 'ACTIVITY',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF667eea),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.pinTitle ?? 'Discovery',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  if (entry.timestamp != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(entry.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inDays > 0) {
      return '${diff.inDays} days ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hours ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}

// Small stat chip widget
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
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
          // Simple welcome message focused on serendipity
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '📖',
                style: TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Serendipity Journal',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: JapaneseColors.sumi,
                    ),
                  ),
                  Text(
                    'Private memories & discoveries',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          // Badges only - remove counts and streaks for privacy
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
