import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:placetalk/models/community.dart';
import 'package:placetalk/providers/auth_provider.dart';
import 'package:placetalk/theme/japanese_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Japanese-themed color palette for Community
class _CommunityColors {
  static const Color sakuraPink = Color(0xFFFFB7C5);
  static const Color softPink = Color(0xFFFFF0F5);
  static const Color bambooGreen = Color(0xFF7BA23F);
  static const Color sumi = Color(0xFF333333);
  static const Color washi = Color(0xFFFAF8F5);
  static const Color goldAccent = Color(0xFFD4A373);
}

final communitiesProvider = FutureProvider<List<Community>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final communitiesJson = await apiClient.getJoinedCommunities();
  return communitiesJson.map((json) => Community.fromJson(json)).toList();
});

class CommunityListScreen extends ConsumerWidget {
  const CommunityListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communitiesAsync = ref.watch(communitiesProvider);

    return Scaffold(
      backgroundColor: _CommunityColors.washi,
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
                if (communities.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: _CommunityColors.sakuraPink.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('🌸', style: TextStyle(fontSize: 40)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'まだコミュニティがありません',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _CommunityColors.sumi,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join a community to start connecting',
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _CommunityCard(community: communities[index]),
                    ),
                    childCount: communities.length,
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

class _CommunityCard extends StatelessWidget {
  final Community community;

  const _CommunityCard({required this.community});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shadowColor: _CommunityColors.sakuraPink.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityPage(community: community),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Community icon with gradient background
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_CommunityColors.sakuraPink, Color(0xFFFF8FAB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _CommunityColors.sakuraPink.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: community.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(community.imageUrl!, fit: BoxFit.cover),
                      )
                    : const Center(child: Text('🌸', style: TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 16),
              // Community info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _CommunityColors.sumi,
                      ),
                    ),
                    if (community.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        community.description!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _CommunityColors.sakuraPink.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '参加済み • Joined',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFE75480),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _CommunityColors.sakuraPink),
            ],
          ),
        ),
      ),
    );
  }
}
            ],
          ),
        ),
      ),
    );
  }
}

// Import this in the CommunityPage
class CommunityPage extends ConsumerStatefulWidget {
  final Community community;

  const CommunityPage({required this.community, super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  List<CommunityMessage> _messages = [];
  bool _isLoading = true;
  bool _notificationsEnabled = false; // Default OFF
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notify_community_${widget.community.id}') ?? false;
    });
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    // Admin = System Admin OR Community Creator
    final isAdmin = user?.role == 'admin' || user?.id == widget.community.createdBy;

    return Scaffold(
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
        actions: [
          // Notification Toggle
          IconButton(
            icon: Icon(_notificationsEnabled ? Icons.notifications_active : Icons.notifications_none),
            color: Colors.white,
            tooltip: _notificationsEnabled ? 'Mute' : 'Notify',
            onPressed: () async {
              setState(() => _notificationsEnabled = !_notificationsEnabled);
              
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('notify_community_${widget.community.id}', _notificationsEnabled);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_notificationsEnabled ? '🔔 Notifications ON' : '🔕 Notifications OFF'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: _CommunityColors.sakuraPink,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // Community banner info
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isAdmin)
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
                        itemBuilder: (context, index) {
                          final message = _messages[_messages.length - 1 - index];
                          return _MessageBubble(message: message);
                        },
                      ),
          ),
          // Post message input (Visible to Admin only)
          if (isAdmin)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _CommunityColors.sakuraPink.withOpacity(0.3))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_CommunityColors.sakuraPink, Color(0xFFFF8FAB)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _CommunityColors.sakuraPink.withOpacity(0.5),
                            blurRadius: 6, offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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
