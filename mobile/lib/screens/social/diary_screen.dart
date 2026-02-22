import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:placetalk/providers/diary_provider.dart';
import 'package:placetalk/providers/auth_provider.dart';
import 'package:placetalk/providers/discovery_provider.dart';
import 'package:placetalk/services/navigation_service.dart';

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
  static const sumiIro = Color(0xFF27292B);          // 墨色 Ink black
  static const kitsune = Color(0xFFFF8C42);          // 狐色 Fox orange
  static const wakatake = Color(0xFF68BE8D);         // 若竹 Young bamboo
}

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diaryStatsProvider);
    final currentUser = ref.watch(currentUserProvider);
    // Phase 1d: profile snapshot uses timeline to compute ghost + today counts
    final timelineAsync = ref.watch(diaryTimelineProvider);
    final today = DateTime.now();
    final ghostCount = timelineAsync.whenData(
      (tl) => tl.where((e) => e.activityType == 'ghost_pass').length).value ?? 0;
    final todayDiscoveries = timelineAsync.whenData(
      (tl) => tl.where((e) {
        final ct = e.createdAt;
        return ct.year == today.year && ct.month == today.month && ct.day == today.day &&
            (e.activityType == 'discovered' || e.activityType == 'visited');
      }).length).value ?? 0;
    final todayGhosts = timelineAsync.whenData(
      (tl) => tl.where((e) {
        final ct = e.createdAt;
        return ct.year == today.year && ct.month == today.month && ct.day == today.day &&
            e.activityType == 'ghost_pass';
      }).length).value ?? 0;

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
                              // Stats Row - Japanese style (Phase 1d: 4 stats)
                              statsAsync.when(
                                data: (stats) => Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
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
                                    _JapaneseStatItem(
                                      kanji: '幽',
                                      label: 'Ghosts',
                                      value: ghostCount.toString(),
                                    ),
                                  ],
                                ),
                                loading: () => const CircularProgressIndicator(
                                  color: _DiaryColors.akeIro,
                                ),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 12),
                              // Phase 1d: Today's Exploration Snapshot
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('📅', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Today — $todayDiscoveries found  👻 $todayGhosts ghosted',
                                      style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w600,
                                        color: _DiaryColors.sumiIro,
                                      ),
                                    ),
                                  ],
                                ),
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
                // spec 4.2 — full-text search
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.search, color: _DiaryColors.sumiIro, size: 20),
                  ),
                  onPressed: () => showSearch(
                    context: context,
                    delegate: _DiarySearchDelegate(ref),
                  ),
                ),
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
                    ref.invalidate(diaryPassiveLogProvider);
                    ref.invalidate(myPinsMetricsProvider);
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

class _ExploredTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(passiveLogSortProvider);
    final logAsync = ref.watch(diaryPassiveLogProvider);

    return logAsync.when(
      data: (entries) {
        return Container(
          color: _DiaryColors.shirotsurubamiIro,
          child: Column(
            children: [
              // ── Sort pills ────────────────────────────────────────────
              Container(
                color: _DiaryColors.shirotsurubamiIro,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _SortPill(
                      label: '📅 Date',
                      active: sort == 'recent',
                      onTap: () => ref.read(passiveLogSortProvider.notifier).state = 'recent',
                    ),
                    const SizedBox(width: 10),
                    _SortPill(
                      label: '❤️ Likes',
                      active: sort == 'like_count',
                      onTap: () => ref.read(passiveLogSortProvider.notifier).state = 'like_count',
                    ),
                  ],
                ),
              ),
              // ── List ─────────────────────────────────────────────────
              if (entries.isEmpty)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
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
                            fontSize: 24, fontWeight: FontWeight.w700,
                            color: _DiaryColors.sumiIro, letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Start Your Journey',
                          style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500,
                            color: _DiaryColors.akeIro,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Walk within 20 m of a pin to ghost-log it here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: _DiaryColors.sumiIro.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      return _GhostVerifiedCard(entry: entries[index]);
                    },
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌸', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            CircularProgressIndicator(color: _DiaryColors.sakuraPink),
          ],
        ),
      ),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

// ── Sort Pill ────────────────────────────────────────────────────────────────
class _SortPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SortPill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _DiaryColors.akeIro : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? _DiaryColors.akeIro : _DiaryColors.sakuraPink.withOpacity(0.5),
          ),
          boxShadow: active
              ? [BoxShadow(color: _DiaryColors.akeIro.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : _DiaryColors.sumiIro,
          ),
        ),
      ),
    );
  }
}

// ── Ghost / Verified Card ─────────────────────────────────────────────────────
class _GhostVerifiedCard extends ConsumerWidget {
  final PassiveLogEntry entry;

  const _GhostVerifiedCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGhost = !entry.isVerified;

    return GestureDetector(
      onTap: () {
        // spec 4.1: fly map camera to this pin then pop back
        ref.read(mapFocusProvider.notifier).state = LatLng(entry.pinLat, entry.pinLon);
        Navigator.of(context).popUntil((r) => r.isFirst);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGhost
                ? Colors.grey.withOpacity(0.3)
                : _DiaryColors.wakatake.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isGhost ? Colors.grey : _DiaryColors.wakatake).withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isGhost
                      ? Colors.grey.withOpacity(0.12)
                      : _DiaryColors.wakatake.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    isGhost ? '👻' : '✅',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.pinTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _DiaryColors.sumiIro,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isGhost
                                ? Colors.grey.withOpacity(0.12)
                                : _DiaryColors.wakatake.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isGhost ? 'Ghost' : 'Verified',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isGhost ? Colors.grey[600] : _DiaryColors.wakatake,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '❤️ ${entry.pinLikeCount}',
                          style: TextStyle(fontSize: 12, color: _DiaryColors.sumiIro.withOpacity(0.6)),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatTime(entry.passedAt),
                          style: TextStyle(fontSize: 12, color: _DiaryColors.sumiIro.withOpacity(0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (isGhost) ...[
                          FilledButton.icon(
                            onPressed: () async {
                              try {
                                await ref.read(apiClientProvider).verifyGhostPin(entry.pinId);
                                ref.invalidate(diaryPassiveLogProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Verified! Pin liked.'),
                                      backgroundColor: Color(0xFF68BE8D),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.favorite_border, size: 16),
                            label: const Text('Verify'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _DiaryColors.akeIro,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        OutlinedButton.icon(
                          onPressed: () {
                            ref.read(mapFocusProvider.notifier).state =
                                LatLng(entry.pinLat, entry.pinLon);
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          },
                          icon: const Icon(Icons.map_rounded, size: 16),
                          label: const Text('View on Map'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _DiaryColors.wakatake,
                            side: const BorderSide(color: _DiaryColors.wakatake),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// 🌸 Japanese-styled My Pins Tab
class _JapaneseMyPinsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myPinsAsync = ref.watch(myPinsMetricsProvider);
    final lastSync = ref.watch(syncCooldownProvider);
    final syncAge = lastSync != null ? DateTime.now().difference(lastSync).inSeconds : 999;
    final cooldownActive = syncAge < 30;
    final secondsLeft = cooldownActive ? 30 - syncAge : 0;

    return myPinsAsync.when(
      data: (pins) {
        return Container(
          color: _DiaryColors.shirotsurubamiIro,
          child: Column(
            children: [
              // ── Sync header ───────────────────────────────────────────
              Container(
                color: _DiaryColors.shirotsurubamiIro,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      '私のピン  (${pins.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _DiaryColors.sumiIro,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: cooldownActive
                          ? null
                          : () {
                              ref.invalidate(myPinsMetricsProvider);
                              ref.invalidate(diaryStatsProvider);
                              ref.read(syncCooldownProvider.notifier).state = DateTime.now();
                            },
                      icon: const Icon(Icons.sync, size: 18),
                      label: Text(
                        cooldownActive ? '🔄 ${secondsLeft}s' : '🔄 Sync',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: cooldownActive
                            ? _DiaryColors.sumiIro.withOpacity(0.4)
                            : _DiaryColors.akeIro,
                      ),
                    ),
                  ],
                ),
              ),
              if (pins.isEmpty)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
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
                            fontSize: 24, fontWeight: FontWeight.w700,
                            color: _DiaryColors.sumiIro, letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create Your First Pin',
                          style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500,
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
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: pins.length,
                    itemBuilder: (context, index) {
                      return _JapanesePinCard(pin: pins[index]);
                    },
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌸', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            CircularProgressIndicator(color: _DiaryColors.akeIro),
          ],
        ),
      ),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

// 🎌 Japanese-styled pin card for "My Pins" tab
class _JapanesePinCard extends ConsumerWidget {
  final DiaryPinMetrics pin;

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
                // Icon container
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
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
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
                          fontSize: 18, fontWeight: FontWeight.bold,
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
                                fontSize: 12, fontWeight: FontWeight.w600,
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
            // Divider
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
            const SizedBox(height: 12),
            // ── Engagement metric chips (spec 4.1 Tab 2) ──────────────
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _JapaneseStatChip(emoji: '👍', label: pin.likeCount.toString(), color: _DiaryColors.wakatake),
                _JapaneseStatChip(emoji: '👣', label: pin.passThrough.toString(), color: _DiaryColors.aiIro),
                _JapaneseStatChip(emoji: '🙈', label: pin.hideCount.toString(), color: _DiaryColors.kitsune),
                _JapaneseStatChip(emoji: '🚩', label: pin.reportCount.toString(), color: Colors.red.shade400),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons: View on In-App Map  +  External Directions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // External directions (secondary)
                OutlinedButton.icon(
                  onPressed: () async {
                    final success = await NavigationService.navigateToPin(
                      pinLat: pin.lat,
                      pinLon: pin.lon,
                      pinTitle: pin.title,
                    );
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No maps app found')),
                      );
                    }
                  },
                  icon: const Icon(Icons.directions, size: 16),
                  label: const Text('案内', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _DiaryColors.aiIro,
                    side: const BorderSide(color: _DiaryColors.aiIro),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                ),
                const SizedBox(width: 10),
                // In-app map (primary)
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(mapFocusProvider.notifier).state =
                        LatLng(pin.lat, pin.lon);
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  icon: const Icon(Icons.map_rounded, size: 16),
                  label: const Text('Map', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _DiaryColors.akeIro,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    elevation: 2,
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

// ════════════════════════════════════════════════════════════════════════════
// spec 4.2 — Diary Full-Text Search Delegate
// ════════════════════════════════════════════════════════════════════════════
class _DiarySearchDelegate extends SearchDelegate<DiarySearchResult?> {
  final WidgetRef _ref;
  _DiarySearchDelegate(this._ref);

  @override
  String get searchFieldLabel => 'Search diary…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: _DiaryColors.sakuraPink,
        foregroundColor: _DiaryColors.sumiIro,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: _DiaryColors.sumiIro),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              query = '';
              _ref.read(diarySearchQueryProvider.notifier).state = '';
            },
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildSuggestions(BuildContext context) {
    _ref.read(diarySearchQueryProvider.notifier).state = query;
    return _buildResults(context);
  }

  @override
  Widget buildResults(BuildContext context) {
    _ref.read(diarySearchQueryProvider.notifier).state = query;
    return _buildResults(context);
  }

  Widget _buildResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Type to search your diary',
              style: TextStyle(
                fontSize: 16, color: _DiaryColors.sumiIro.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    // Use a Consumer to watch the search provider
    return Consumer(
      builder: (context, ref, _) {
        final searchAsync = ref.watch(diarySearchProvider);
        return searchAsync.when(
          data: (results) {
            if (results.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('😶', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      'No results for "$query"',
                      style: const TextStyle(fontSize: 16, color: _DiaryColors.sumiIro),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              itemBuilder: (context, index) =>
                  _SearchResultCard(result: results[index], delegate: this, searchRef: ref),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: _DiaryColors.akeIro),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
      },
    );
  }
}

// ── Search result card ────────────────────────────────────────────────────────
class _SearchResultCard extends StatelessWidget {
  final DiarySearchResult result;
  final _DiarySearchDelegate delegate;
  final WidgetRef searchRef;

  const _SearchResultCard({
    required this.result,
    required this.delegate,
    required this.searchRef,
  });

  @override
  Widget build(BuildContext context) {
    final isGhost = result.activityType == 'ghost_pass' && !result.isVerified;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _DiaryColors.sakuraPink.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: _DiaryColors.sakuraPink.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Text(
              isGhost ? '👻' : '✅',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.pinTitle,
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold,
                      color: _DiaryColors.sumiIro,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    result.pinDirections.isNotEmpty
                        ? result.pinDirections
                        : result.pinCategory,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12, color: _DiaryColors.sumiIro.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                searchRef.read(mapFocusProvider.notifier).state =
                    LatLng(result.pinLat, result.pinLon);
                delegate.close(context, result);
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              style: TextButton.styleFrom(foregroundColor: _DiaryColors.akeIro),
              child: const Text('View\non Map', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}
