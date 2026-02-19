import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:placetalk/models/diary.dart' hide Badge;
import 'package:placetalk/models/diary.dart' as diary show Badge;
import 'package:placetalk/theme/japanese_theme.dart' hide JapaneseColors;
import 'package:placetalk/providers/diary_provider.dart';
import 'package:placetalk/providers/auth_provider.dart';
import 'package:placetalk/services/navigation_service.dart';
import 'package:confetti/confetti.dart';

// ═══════════════════════════════════════════════════════════════
// 🌸 JAPANESE THEMED DIARY SCREEN
// Design inspired by traditional Japanese aesthetics with modern UI
// ═══════════════════════════════════════════════════════════════

// Japanese color palette for Diary (named to avoid conflicts)
class _DiaryColors {
  static const sakuraPink = Color(0xFFFFB7C5);       // 桜 Sakura pink
  static const deepSakura = Color(0xFFE8A0B0);       // Deep cherry blossom
  static const akeIro = Color(0xFFC41E3A);           // 朱色 Traditional red
  static const shirotsurubamiIro = Color(0xFFF8F4E6);// 白橡 Cream white
  static const aiIro = Color(0xFF1E4D8C);            // 藍色 Indigo
  static const sumireIro = Color(0xFF8B5CF6);        // 菫色 Violet
  static const matsubaIro = Color(0xFF1F5232);       // 松葉色 Pine green
  static const kinIro = Color(0xFFD4AF37);           // 金色 Gold
  static const sumiIro = Color(0xFF27292B);          // 墨色 Ink black
  static const kitsune = Color(0xFFFF8C42);          // 狐色 Fox orange
  static const wakatake = Color(0xFF68BE8D);         // 若竹 Young bamboo
  // Aliases for compatibility
  static const sakura = Color(0xFFFEF4F4);           // Cherry Blossom White
  static const sumi = Color(0xFF1C1C1C);             // Ink Black (alias)
  static const kogane = Color(0xFFE6B422);           // Gold (Kogane-iro)
}

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diaryStatsProvider);
    final currentUser = ref.watch(currentUserProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _DiaryColors.shirotsurubamiIro,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // 🌸 Japanese-style profile header
            SliverAppBar(
              expandedHeight: 280,
              floating: false,
              pinned: true,
              backgroundColor: _DiaryColors.sakuraPink,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFB7C5), // Sakura pink
                        Color(0xFFFFC0CB), // Light pink
                        Color(0xFFE8A0B0), // Deep sakura
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Sakura petals decoration (top right)
                      Positioned(
                        top: 40,
                        right: 20,
                        child: Opacity(
                          opacity: 0.3,
                          child: Text(
                            '桜',
                            style: TextStyle(
                              fontSize: 120,
                              color: Colors.white,
                              fontWeight: FontWeight.w200,
                            ),
                          ),
                        ),
                      ),
                      // Sakura petals decoration (bottom left)
                      Positioned(
                        bottom: 60,
                        left: -20,
                        child: Opacity(
                          opacity: 0.2,
                          child: Text(
                            '花',
                            style: TextStyle(
                              fontSize: 100,
                              color: Colors.white,
                              fontWeight: FontWeight.w200,
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Profile Avatar with sakura border
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.8),
                                      _DiaryColors.sakuraPink,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _DiaryColors.deepSakura.withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '🌸',
                                      style: TextStyle(fontSize: 36),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // User Name
                              currentUser.when(
                                data: (user) => Text(
                                  user?.name ?? 'Explorer',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: _DiaryColors.sumiIro,
                                    letterSpacing: 1,
                                  ),
                                ),
                                loading: () => const Text(
                                  '...',
                                  style: TextStyle(color: _DiaryColors.sumiIro),
                                ),
                                error: (_, __) => const Text(
                                  'Explorer',
                                  style: TextStyle(color: _DiaryColors.sumiIro),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Stats Row - Japanese style
                              statsAsync.when(
                                data: (stats) => Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _JapaneseStatItem(
                                      kanji: '発見',
                                      label: 'Found',
                                      value: stats.totalDiscoveries.toString(),
                                    ),
                                    _JapaneseStatItem(
                                      kanji: '創造',
                                      label: 'Made',
                                      value: stats.totalPinsCreated.toString(),
                                    ),
                                    _JapaneseStatItem(
                                      kanji: '章',
                                      label: 'Badges',
                                      value: stats.badges.length.toString(),
                                    ),
                                  ],
                                ),
                                loading: () => const CircularProgressIndicator(
                                  color: _DiaryColors.akeIro,
                                ),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.refresh, color: _DiaryColors.sumiIro, size: 20),
                  ),
                  onPressed: () {
                    ref.invalidate(diaryStatsProvider);
                    ref.invalidate(diaryTimelineProvider);
                    ref.invalidate(myPinsProvider);
                  },
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  color: _DiaryColors.shirotsurubamiIro,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: _DiaryColors.sakuraPink.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [_DiaryColors.sakuraPink, _DiaryColors.deepSakura],
                        ),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: _DiaryColors.sumiIro.withOpacity(0.6),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🚶', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 6),
                              Text('発見', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('📍', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 6),
                              Text('私のピン', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _ExploredTab(),
              _JapaneseMyPinsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// Japanese-style stat item
class _JapaneseStatItem extends StatelessWidget {
  final String kanji;
  final String label;
  final String value;

  const _JapaneseStatItem({
    required this.kanji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            kanji,
            style: const TextStyle(
              fontSize: 16,
              color: _DiaryColors.akeIro,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _DiaryColors.sumiIro,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: _DiaryColors.sumiIro.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom sliver delegate for tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget _child;

  _SliverAppBarDelegate(this._child);

  @override
  double get minExtent => 80;

  @override
  double get maxExtent => 80;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return _child;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
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
            color: _DiaryColors.shirotsurubamiIro,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: _DiaryColors.sakuraPink.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _DiaryColors.sakuraPink.withOpacity(0.5),
                      width: 3,
                    ),
                  ),
                  child: const Center(
                    child: Text('🚶', style: TextStyle(fontSize: 60)),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '旅を始めよう',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _DiaryColors.sumiIro,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start Your Journey',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: _DiaryColors.akeIro,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Walk near pins to discover hidden treasures',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14, 
                    color: _DiaryColors.sumiIro.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }
        
        return Container(
          color: _DiaryColors.shirotsurubamiIro,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: passedPins.length,
            itemBuilder: (context, index) {
              return _JapaneseTimelineCard(
                entry: passedPins[index],
                isFirst: index == 0,
                isLast: index == passedPins.length - 1,
              );
            },
          ),
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌸', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            CircularProgressIndicator(
              color: _DiaryColors.sakuraPink,
            ),
          ],
        ),
      ),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

// 🌸 Japanese-styled My Pins Tab
class _JapaneseMyPinsTab extends ConsumerWidget {
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
            color: _DiaryColors.shirotsurubamiIro,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: _DiaryColors.akeIro.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _DiaryColors.akeIro.withOpacity(0.5),
                      width: 3,
                    ),
                  ),
                  child: const Center(
                    child: Text('📍', style: TextStyle(fontSize: 60)),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '最初のピン',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _DiaryColors.sumiIro,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create Your First Pin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: _DiaryColors.akeIro,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Share special places with other explorers',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14, 
                    color: _DiaryColors.sumiIro.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }
        
        return Container(
          color: _DiaryColors.shirotsurubamiIro,
          child: RefreshIndicator(
            color: _DiaryColors.akeIro,
            onRefresh: () async {
              print('🔄 DiaryScreen: FORCE REFRESH - Invalidating myPinsProvider');
              ref.invalidate(myPinsProvider);
              ref.invalidate(diaryStatsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pins.length,
              itemBuilder: (context, index) {
                final pin = pins[index];
                return _JapanesePinCard(pin: pin);
              },
            ),
          ),
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌸', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            CircularProgressIndicator(
              color: _DiaryColors.akeIro,
            ),
          ],
        ),
      ),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

// 🎌 Japanese-styled pin card for "My Pins" tab
class _JapanesePinCard extends ConsumerWidget {
  final dynamic pin;

  const _JapanesePinCard({required this.pin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isCommunity = pin.pinCategory == 'community';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _DiaryColors.sakuraPink.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _DiaryColors.sakuraPink.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                // Japanese-styled icon container
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCommunity 
                          ? [_DiaryColors.kitsune.withOpacity(0.9), _DiaryColors.kitsune]
                          : [_DiaryColors.akeIro.withOpacity(0.9), _DiaryColors.akeIro],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isCommunity ? '🏯' : '📍',
                      style: const TextStyle(fontSize: 26),
                    ),
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
                          color: _DiaryColors.sumiIro,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isCommunity 
                              ? _DiaryColors.kitsune.withOpacity(0.1)
                              : _DiaryColors.sakuraPink.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCommunity 
                                ? _DiaryColors.kitsune.withOpacity(0.3)
                                : _DiaryColors.sakuraPink.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isCommunity ? '∞' : '✿',
                              style: TextStyle(
                                fontSize: 12,
                                color: isCommunity ? _DiaryColors.kitsune : _DiaryColors.akeIro,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isCommunity ? '永遠' : '活動中',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isCommunity ? _DiaryColors.kitsune : _DiaryColors.akeIro,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Divider with sakura pattern
            Row(
              children: [
                Expanded(child: Divider(color: _DiaryColors.sakuraPink.withOpacity(0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('✿', style: TextStyle(color: _DiaryColors.sakuraPink.withOpacity(0.5))),
                ),
                Expanded(child: Divider(color: _DiaryColors.sakuraPink.withOpacity(0.3))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _JapaneseStatChip(
                  emoji: '👍',
                  label: pin.likeCount.toString(),
                  color: _DiaryColors.wakatake,
                ),
                const SizedBox(width: 12),
                _JapaneseStatChip(
                  emoji: '👎',
                  label: pin.dislikeCount.toString(),
                  color: _DiaryColors.akeIro,
                ),
                const Spacer(),
                // Navigate button with Japanese styling
                ElevatedButton.icon(
                  onPressed: () async {
                    final success = await NavigationService.navigateToPin(
                      pinLat: pin.lat,
                      pinLon: pin.lon,
                      pinTitle: pin.title,
                    );
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Unable to open maps'),
                          backgroundColor: _DiaryColors.akeIro,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('案内'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _DiaryColors.akeIro,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    elevation: 3,
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

// Japanese stat chip
class _JapaneseStatChip extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;

  const _JapaneseStatChip({
    required this.emoji,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// 🎌 Japanese-styled timeline card for discoveries
class _JapaneseTimelineCard extends StatelessWidget {
  final dynamic entry;
  final bool isFirst;
  final bool isLast;

  const _JapaneseTimelineCard({
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
          // Japanese-styled timeline indicator
          Column(
            children: [
              if (!isFirst)
                Container(
                  width: 2,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _DiaryColors.sakuraPink.withOpacity(0.3),
                        _DiaryColors.sakuraPink,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_DiaryColors.sakuraPink, _DiaryColors.akeIro],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _DiaryColors.sakuraPink.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    entry.activityEmoji ?? '🌸',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _DiaryColors.sakuraPink,
                        _DiaryColors.sakuraPink.withOpacity(0.3),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content card with Japanese styling
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _DiaryColors.sakuraPink.withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _DiaryColors.sakuraPink.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _DiaryColors.akeIro.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getJapaneseActivityType(entry.activityType),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _DiaryColors.akeIro,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '✿',
                        style: TextStyle(
                          color: _DiaryColors.sakuraPink.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    entry.pinTitle ?? '発見',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _DiaryColors.sumiIro,
                    ),
                  ),
                  if (entry.createdAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(entry.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: _DiaryColors.sumiIro.withOpacity(0.5),
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

  String _getJapaneseActivityType(String? type) {
    switch (type?.toLowerCase()) {
      case 'discovered':
        return '発見';
      case 'liked':
        return '好き';
      case 'disliked':
        return '嫌い';
      case 'visited':
        return '訪問';
      default:
        return type?.toUpperCase() ?? '活動';
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}日前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}時間前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分前';
    } else {
      return '今';
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
          colors: [_DiaryColors.wakatake.withOpacity(0.1), _DiaryColors.sakura],
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
                      color: _DiaryColors.sumi,
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
          color: _DiaryColors.kogane.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _DiaryColors.kogane, width: 1.5),
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
                color: _DiaryColors.sumi,
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
                          color: _DiaryColors.sumi,
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
