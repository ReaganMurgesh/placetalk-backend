import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:placetalk/models/community.dart';
import 'package:placetalk/providers/auth_provider.dart';
import 'package:placetalk/providers/discovery_provider.dart';
import 'package:placetalk/services/socket_service.dart';

// Japanese-themed color palette for Community
class _CommunityColors {
  static const Color sakuraPink = Color(0xFFFFB7C5);
  static const Color softPink = Color(0xFFFFF0F5);
  static const Color bambooGreen = Color(0xFF7BA23F);
  static const Color sumi = Color(0xFF333333);
  static const Color washi = Color(0xFFFAF8F5);
}

final communitiesProvider = FutureProvider<List<Community>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final communitiesJson = await apiClient.getJoinedCommunities();
  return communitiesJson.map((json) => Community.fromJson(json as Map<String, dynamic>)).toList();
});

// Near communities for empty state (spec 3.5) — fetched when list is empty
final nearCommunitiesProvider = FutureProvider.family<List<Community>, (double, double)>(
  (ref, args) async {
    final apiClient = ref.watch(apiClientProvider);
    final json = await apiClient.getCommunitiesNear(args.$1, args.$2);
    return json.map((j) => Community.fromJson(j as Map<String, dynamic>)).toList();
  },
);


class CommunityListScreen extends ConsumerWidget {
  const CommunityListScreen({super.key});

  void _showCreateCommunityDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🌸', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Create Community'),
          ],
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Community Name',
            hintText: 'e.g. Osaka Street Art',
            filled: true,
            fillColor: const Color(0xFFFFF0F5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLength: 60,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _CommunityColors.sakuraPink),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final apiClient = ref.read(apiClientProvider);
                await apiClient.findOrCreateCommunity(name);
                ref.invalidate(communitiesProvider); // Refresh the list
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🌸 Community "$name" ready!'),
                      backgroundColor: _CommunityColors.sakuraPink,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communitiesAsync = ref.watch(communitiesProvider);

    return Scaffold(
      backgroundColor: _CommunityColors.washi,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCommunityDialog(context, ref),
        backgroundColor: _CommunityColors.sakuraPink,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('コミュニティ作成', style: TextStyle(color: Colors.white, fontSize: 13)),
      ),
      body: CustomScrollView(
        slivers: [
          // Decorative Japanese header
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: _CommunityColors.sakuraPink,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
              title: const Row(
                children: [
                  Text('コミュニティ', style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
                ],
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFFFF8FAB), Color(0xFFFFB7C5)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    top: 20,
                    child: Text('花', style: TextStyle(
                      fontSize: 80,
                      color: Colors.white.withOpacity(0.15),
                      fontWeight: FontWeight.bold,
                    )),
                  ),
                  Positioned(
                    right: 70,
                    top: 55,
                    child: Text('🌸', style: TextStyle(
                      fontSize: 36,
                      color: Colors.white.withOpacity(0.5),
                    )),
                  ),
                ],
              ),
            ),
          ),
          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: communitiesAsync.when(
              data: (communities) {
                // filter hidden communities to show them dimmed at the bottom
                final visible = communities.where((c) => !c.isHidden).toList();
                final hidden = communities.where((c) => c.isHidden).toList();
                final all = [...visible, ...hidden];

                if (all.isEmpty) {
                  // spec 3.5: suggest nearby communities as empty state
                  return SliverFillRemaining(
                    child: _NearMeEmptyState(),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _CommunityCard(
                        community: all[index],
                        onRefresh: () => ref.invalidate(communitiesProvider),
                      ),
                    ),
                    childCount: all.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _CommunityColors.sakuraPink)),
              ),
              error: (error, stack) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.refresh(communitiesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityCard extends ConsumerWidget {
  final Community community;
  final VoidCallback onRefresh;

  const _CommunityCard({required this.community, required this.onRefresh});

  // ── spec 3.2: type badge ────────────────────────────────────────────────
  Widget _typeBadge() {
    switch (community.communityType) {
      case CommunityType.inviteOnly:
        return _badge('🔑 Invite', const Color(0xFF5C6BC0));
      case CommunityType.paidRestricted:
        return _badge('🔒 Paid', Colors.deepPurple);
      case CommunityType.open:
        return _badge('🟢 Open', _CommunityColors.bambooGreen);
    }
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );

  // ── spec 3.4: long-press action sheet ──────────────────────────────────
  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            // Like / Unlike
            ListTile(
              leading: Icon(community.likedByMe ? Icons.favorite : Icons.favorite_border,
                  color: Colors.pinkAccent),
              title: Text(community.likedByMe ? 'Unlike (${community.likeCount})' : 'Like (${community.likeCount})'),
              onTap: () => Navigator.pop(context, 'like'),
            ),
            // Hide
            ListTile(
              leading: Icon(community.isHidden ? Icons.visibility : Icons.visibility_off,
                  color: Colors.orange),
              title: Text(community.isHidden ? 'Show again' : 'Hide this community'),
              onTap: () => Navigator.pop(context, 'hide'),
            ),
            // Report
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              title: const Text('Report'),
              onTap: () => Navigator.pop(context, 'report'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    final apiClient = ref.read(apiClientProvider);
    switch (action) {
      case 'like':
        try {
          if (community.likedByMe) {
            await apiClient.unlikeCommunity(community.id);
          } else {
            await apiClient.likeCommunity(community.id);
          }
          onRefresh();
        } catch (_) {}
        break;
      case 'hide':
        if (community.isHidden) {
          // Restore
          await apiClient.updateCommunityMemberSettings(community.id, isHidden: false, hideMapPins: false);
          onRefresh();
        } else {
          // Show dialog: hide list only vs. list + map
          await _showHideDialog(context, ref, apiClient);
        }
        break;
      case 'report':
        await _showReportDialog(context, apiClient);
        break;
    }
  }

  Future<void> _showHideDialog(BuildContext context, WidgetRef ref, dynamic apiClient) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Hide Community'),
        content: const Text('How would you like to hide this community?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, 'list'),
            child: const Text('List only'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, 'list_and_map'),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('List + Map Pins'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    await apiClient.updateCommunityMemberSettings(
      community.id,
      isHidden: true,
      hideMapPins: choice == 'list_and_map',
    );
    onRefresh();
  }

  Future<void> _showReportDialog(BuildContext context, dynamic apiClient) async {
    final reasons = ['Spam', 'Inappropriate content', 'Fake / Misleading', 'Other'];
    String? selected;
    await showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: const Text('Report Community'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((r) => RadioListTile<String>(
              title: Text(r),
              value: r,
              groupValue: selected,
              onChanged: (v) => setState(() => selected = v),
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
            FilledButton(
              onPressed: selected == null ? null : () async {
                Navigator.pop(dCtx);
                await apiClient.reportCommunity(community.id, selected!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted. Thank you.')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opacity = community.isHidden ? 0.4 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Card(
        elevation: 3,
        shadowColor: _CommunityColors.sakuraPink.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        color: Colors.white,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommunityPage(community: community),
              ),
            );
          },
          onLongPress: () => _showActions(context, ref),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_CommunityColors.sakuraPink, Color(0xFFFF8FAB)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: _CommunityColors.sakuraPink.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: community.imageUrl != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(14),
                          child: Image.network(community.imageUrl!, fit: BoxFit.cover))
                      : const Center(child: Text('🌸', style: TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + type badge
                      Row(children: [
                        Expanded(
                          child: Text(community.name,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _CommunityColors.sumi),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        _typeBadge(),
                      ]),
                      if (community.description != null) ...[
                        const SizedBox(height: 4),
                        Text(community.description!,
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 8),
                      // Bottom row: members, likes, joined badge
                      Row(children: [
                        if (community.memberCount != null) ...[
                          Icon(Icons.people_outline, size: 13, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Text('${community.memberCount}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          const SizedBox(width: 10),
                        ],
                        // Like chip
                        GestureDetector(
                          onTap: () async {
                            try {
                              final api = ref.read(apiClientProvider);
                              if (community.likedByMe) {
                                await api.unlikeCommunity(community.id);
                              } else {
                                await api.likeCommunity(community.id);
                              }
                              onRefresh();
                            } catch (_) {}
                          },
                          child: Row(children: [
                            Icon(community.likedByMe ? Icons.favorite : Icons.favorite_border,
                                size: 14, color: Colors.pinkAccent),
                            const SizedBox(width: 3),
                            Text('${community.likeCount}',
                                style: const TextStyle(fontSize: 11, color: Colors.pinkAccent)),
                          ]),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _CommunityColors.sakuraPink.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            community.isHidden ? '非表示 Hidden' : '参加済み • Joined',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFE75480), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _CommunityColors.sakuraPink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── spec 3.5: Near-me empty state widget ─────────────────────────────────────
class _NearMeEmptyState extends ConsumerWidget {
  const _NearMeEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Try to get user's current position to suggest nearby communities
    final discovery = ref.watch(discoveryProvider);
    final pos = discovery.lastPosition;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _CommunityColors.sakuraPink.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🌸', style: TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 20),
          const Text('まだコミュニティがありません',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _CommunityColors.sumi)),
          const SizedBox(height: 8),
          Text(
            'Tap ＋ to create one, or discover communities near you below.',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          if (pos != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Communities near you',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _CommunityColors.sumi)),
            ),
            const SizedBox(height: 12),
            ref.watch(nearCommunitiesProvider((pos.latitude, pos.longitude))).when(
              data: (nearby) {
                if (nearby.isEmpty) {
                  return Text('No nearby communities found. Be the first to create one! 🌸',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      textAlign: TextAlign.center);
                }
                return Column(
                  children: nearby.map((c) => _NearbyCommunitySuggestion(community: c)).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(color: _CommunityColors.sakuraPink),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

class _NearbyCommunitySuggestion extends ConsumerWidget {
  final Community community;
  const _NearbyCommunitySuggestion({required this.community});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _CommunityColors.sakuraPink.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(child: Text('🌸', style: TextStyle(fontSize: 20))),
        ),
        title: Text(community.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${community.memberCount ?? 0} members · ${community.likeCount} likes',
            style: const TextStyle(fontSize: 11)),
        trailing: FilledButton(
          onPressed: () async {
            try {
              await ref.read(apiClientProvider).joinCommunity(community.id);
              ref.invalidate(communitiesProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Joined ${community.name}! 🌸'),
                      backgroundColor: _CommunityColors.sakuraPink),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')));
              }
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: _CommunityColors.sakuraPink,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: const Text('Join', style: TextStyle(fontSize: 12, color: Colors.white)),
        ),
      ),
    );
  }
}


class CommunityPage extends ConsumerStatefulWidget {
  final Community community;

  const CommunityPage({required this.community, super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  List<CommunityMessage> _messages = [];
  bool _isLoading = true;
  bool _isMember = false; // Has user joined this community?
  bool _isJoining = false;
  final _messageController = TextEditingController();
  final _socketService = SocketService(); // Real-time chat

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _checkMembership();
    // Real-time socket connection
    _socketService.connect();
    _socketService.joinCommunity(widget.community.id, _onSocketMessage);
  }

  /// Called by the socket service when the server pushes a new community message.
  void _onSocketMessage(Map<String, dynamic> data) {
    if (!mounted) return;
    try {
      final message = CommunityMessage.fromJson(data);
      // Deduplicate — posting also triggers a reload via _loadMessages
      if (_messages.any((m) => m.id == message.id)) return;
      setState(() => _messages.add(message));
    } catch (e) {
      // Fallback: reload from server if parsing fails
      _loadMessages();
    }
  }

  Future<void> _checkMembership() async {
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;
      // Creator is always a member
      if (user.id == widget.community.createdBy) {
        setState(() => _isMember = true);
        return;
      }
      // Check if in joined communities list
      final apiClient = ref.read(apiClientProvider);
      final joined = await apiClient.getJoinedCommunities();
      final ids = joined.map((c) => c['id'] as String? ?? '').toSet();
      if (mounted) setState(() => _isMember = ids.contains(widget.community.id));
    } catch (_) {}
  }

  Future<void> _joinCommunity() async {
    setState(() => _isJoining = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.joinCommunity(widget.community.id);
      setState(() { _isMember = true; _isJoining = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🌸 コミュニティに参加しました！ Joined community!'),
              backgroundColor: Color(0xFFFFB7C5)),
        );
      }
    } catch (e) {
      setState(() => _isJoining = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e')),
        );
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final messagesJson = await apiClient.getCommunityMessages(widget.community.id);
      setState(() {
        _messages = messagesJson.map((json) => CommunityMessage.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e')),
        );
      }
    }
  }

  Future<void> _postMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.postCommunityMessage(widget.community.id, content: content);
      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post message: $e')),
        );
      }
    }
  }

  // ── spec 3.3: open 3-stage notification sheet ──────────────────────────
  void _showNotificationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NotificationSettingsSheet(community: widget.community),
    );
  }

  // ── spec 3.2: show invite sheet ─────────────────────────────────────────
  Future<void> _showInviteSheet() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.createCommunityInvite(widget.community.id);
      final code = res['code'] as String? ?? '';
      final link = res['inviteLink'] as String? ?? 'placetalk://invite/$code';
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Invite Link', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                child: SelectableText(link, style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Link'),
                    style: FilledButton.styleFrom(backgroundColor: _CommunityColors.sakuraPink),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite link copied!')));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      Navigator.pop(context);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final isCreator = user?.role == 'admin' || user?.id == widget.community.createdBy;
    final canPost = isCreator || _isMember;
    final isInviteType = widget.community.communityType == CommunityType.inviteOnly ||
        widget.community.communityType == CommunityType.paidRestricted;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _CommunityColors.washi,
        appBar: AppBar(
          backgroundColor: _CommunityColors.sakuraPink,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.community.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const Text('コミュニティ', style: TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
          // ── spec 3.3 + 3.2 action buttons ────────────────────────────────
          actions: [
            IconButton(
              icon: Icon(widget.community.notificationsOn
                  ? Icons.notifications_active
                  : Icons.notifications_none),
              tooltip: 'Notification settings',
              onPressed: _showNotificationSheet,
            ),
            if (isInviteType && (isCreator || _isMember))
              IconButton(
                icon: const Icon(Icons.link),
                tooltip: 'Invite',
                onPressed: _showInviteSheet,
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadMessages,
            ),
          ],
          // ── spec 3.1: tabbar ──────────────────────────────────────────────
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: '📌 Feed'),
              Tab(text: '💬 Chat'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ── Tab 0: Pin Feed (spec 3.1) ──────────────────────────────────
            _CommunityFeed(community: widget.community),
            // ── Tab 1: Chat ────────────────────────────────────────────────
            Column(
              children: [
                // Community banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _CommunityColors.sakuraPink.withOpacity(0.3),
                        _CommunityColors.softPink,
                      ],
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('🌸', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.community.description ?? 'Community board',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCreator)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _CommunityColors.bambooGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _CommunityColors.bambooGreen.withOpacity(0.5)),
                          ),
                          child: const Text('管理者 Admin',
                              style: TextStyle(fontSize: 11, color: _CommunityColors.bambooGreen, fontWeight: FontWeight.w600)),
                        ),
                      if (!isCreator && !_isMember)
                        GestureDetector(
                          onTap: _isJoining ? null : _joinCommunity,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: _CommunityColors.sakuraPink, borderRadius: BorderRadius.circular(10)),
                            child: _isJoining
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('参加 Join', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                ),
                // Messages list
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: _CommunityColors.sakuraPink))
                      : _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🌸', style: TextStyle(fontSize: 48)),
                                  const SizedBox(height: 16),
                                  Text('まだメッセージがありません',
                                      style: TextStyle(fontSize: 15, color: Colors.grey[500])),
                                  Text('No messages yet',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                                ],
                              ),
                            )
                          : ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              itemCount: _messages.length,
                              itemBuilder: (_, index) {
                                final msg = _messages[_messages.length - 1 - index];
                                return _MessageBubble(message: msg);
                              },
                            ),
                ),
                // Post input — members + creator
                if (canPost)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: _CommunityColors.sakuraPink.withOpacity(0.3))),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2))],
                    ),
                    child: Row(
                      children: [
                        const Text('🌸', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'コミュニティに投稿... Post to community',
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                              filled: true,
                              fillColor: _CommunityColors.softPink,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            maxLines: null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _postMessage,
                          child: Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [_CommunityColors.sakuraPink, Color(0xFFFF8FAB)]),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: _CommunityColors.sakuraPink.withOpacity(0.5), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _socketService.leaveCommunity(widget.community.id);
    _socketService.disconnect();
    _messageController.dispose();
    super.dispose();
  }
}

// ── spec 3.1: Pin Feed tab ────────────────────────────────────────────────────
class _CommunityFeed extends ConsumerStatefulWidget {
  final Community community;
  const _CommunityFeed({required this.community});

  @override
  ConsumerState<_CommunityFeed> createState() => _CommunityFeedState();
}

class _CommunityFeedState extends ConsumerState<_CommunityFeed> {
  List<CommunityFeedItem> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final raw = await ref.read(apiClientProvider).getCommunityFeed(widget.community.id);
      setState(() {
        _items = raw.map((j) => CommunityFeedItem.fromJson(j as Map<String, dynamic>)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: _CommunityColors.sakuraPink));
    if (_error != null) return Center(child: Text('Error: $_error', style: TextStyle(color: Colors.red[400])));
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📌', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 14),
            const Text('まだピンがありません', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _CommunityColors.sumi)),
            const SizedBox(height: 6),
            Text('No pins yet — create a Community Pin on the Map',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]), textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _CommunityColors.sakuraPink,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length,
        itemBuilder: (_, i) => _PinFeedCard(item: _items[i]),
      ),
    );
  }
}

// ── spec 3.1: X-style pin card (no images, no distance) ─────────────────────
class _PinFeedCard extends ConsumerWidget {
  final CommunityFeedItem item;
  const _PinFeedCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeStr = _relativeTime(item.feedUpdatedAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(color: _CommunityColors.sakuraPink.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: pin type chip + timestamp
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _CommunityColors.sakuraPink.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('📌 ${item.pinType}', style: const TextStyle(fontSize: 11, color: _CommunityColors.sakuraPink, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ]),
          const SizedBox(height: 8),
          // Title
          Text(item.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _CommunityColors.sumi)),
          // Directions snippet (2 lines max — no distance shown per spec 3.1)
          if (item.directions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.directions,
                style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.45),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          // Bottom row: likes | chat indicator | View on Map
          Row(children: [
            Icon(Icons.favorite_border, size: 14, color: Colors.pinkAccent),
            const SizedBox(width: 4),
            Text('${item.likeCount}', style: const TextStyle(fontSize: 12, color: Colors.pinkAccent)),
            if (item.chatEnabled) ...[
              const SizedBox(width: 12),
              Icon(Icons.chat_bubble_outline, size: 14, color: Colors.blueGrey[300]),
              const SizedBox(width: 4),
              Text('chat', style: TextStyle(fontSize: 11, color: Colors.blueGrey[300])),
            ],
            const Spacer(),
            // ── "View on Map" — flies camera to pin (spec 3.1) ─────────────
            GestureDetector(
              onTap: () {
                ref.read(mapFocusProvider.notifier).state = LatLng(item.lat, item.lon);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _CommunityColors.sakuraPink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _CommunityColors.sakuraPink.withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 13, color: _CommunityColors.sakuraPink),
                    SizedBox(width: 4),
                    Text('View on Map', style: TextStyle(fontSize: 11, color: _CommunityColors.sakuraPink, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }
}

// ── spec 3.3: 3-stage notification settings sheet ─────────────────────────────
class _NotificationSettingsSheet extends ConsumerStatefulWidget {
  final Community community;
  const _NotificationSettingsSheet({required this.community});

  @override
  ConsumerState<_NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends ConsumerState<_NotificationSettingsSheet> {
  late bool _notificationsOn;
  late bool _hometownNotify;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _notificationsOn = widget.community.notificationsOn;
    _hometownNotify = widget.community.hometownNotify;
  }

  Future<void> _save({bool? notificationsOn, bool? hometownNotify}) async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).updateCommunityMemberSettings(
        widget.community.id,
        notificationsOn: notificationsOn ?? _notificationsOn,
        hometownNotify: hometownNotify ?? _hometownNotify,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Notification Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _CommunityColors.sumi)),
              const SizedBox(height: 4),
              Text('Control when you receive notifications from this community.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 16),
              // ── Step 1: master toggle ──────────────────────────────────────
              Card(
                elevation: 0,
                color: _CommunityColors.softPink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  activeColor: _CommunityColors.sakuraPink,
                  title: const Text('🔔 Community Notifications',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Receive notifications from this community',
                      style: TextStyle(fontSize: 12)),
                  value: _notificationsOn,
                  onChanged: _saving ? null : (v) {
                    setState(() { _notificationsOn = v; if (!v) _hometownNotify = false; });
                    _save(notificationsOn: v, hometownNotify: v ? _hometownNotify : false);
                  },
                ),
              ),
              if (_notificationsOn) ...[
                const SizedBox(height: 12),
                // ── Step 2: always-on 10km proximity (info only) ─────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(children: [
                    const Text('📍', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'You will always be notified when a new pin is created within 10km of your location.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                    )),
                  ]),
                ),
                const SizedBox(height: 12),
                // ── Step 3: hometown toggle ───────────────────────────────────
                Card(
                  elevation: 0,
                  color: _CommunityColors.softPink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: SwitchListTile(
                    activeColor: _CommunityColors.bambooGreen,
                    title: const Text('🏠 Hometown Mode',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Notify even when you are far away (>10km)',
                        style: TextStyle(fontSize: 12)),
                    value: _hometownNotify,
                    onChanged: _saving ? null : (v) {
                      setState(() => _hometownNotify = v);
                      _save(hometownNotify: v);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _MessageBubble extends ConsumerWidget {
  final CommunityMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_CommunityColors.sakuraPink, Color(0xFFFF8FAB)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🌸', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          // Bubble + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time header
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
                const SizedBox(height: 4),
                // Message bubble
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _CommunityColors.sakuraPink.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: _CommunityColors.sakuraPink.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: const TextStyle(
                      fontSize: 15,
                      color: _CommunityColors.sumi,
                      height: 1.5,
                    ),
                  ),
                ),
                // Reactions row
                if (message.reactions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: message.reactions.entries.map((entry) {
                      final emoji = entry.key;
                      final users = entry.value;
                      final hasReacted = user != null && users.contains(user.id);

                      return GestureDetector(
                        onTap: () async {
                          try {
                            final apiClient = ref.read(apiClientProvider);
                            await apiClient.toggleReaction(message.id, emoji);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to toggle reaction: $e')),
                              );
                            }
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasReacted
                                ? _CommunityColors.sakuraPink.withOpacity(0.25)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: hasReacted
                                  ? _CommunityColors.sakuraPink
                                  : Colors.grey[300]!,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            '$emoji ${users.length}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: hasReacted ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'たった今 Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分前 ${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}時間前 ${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前 ${diff.inDays}d ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}
