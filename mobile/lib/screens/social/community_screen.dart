import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:placetalk/models/community.dart';
import 'package:placetalk/services/api_client.dart';
import 'package:placetalk/providers/auth_provider.dart';
import 'package:placetalk/theme/japanese_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      appBar: AppBar(
        title: const Text('Communities'),
        elevation: 1,
      ),
      body: communitiesAsync.when(
        data: (communities) {
          if (communities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No communities yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join a community to start',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: communities.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final community = communities[index];
              return _CommunityCard(community: community);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
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
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final Community community;

  const _CommunityCard({required this.community});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityPage(community: community),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Community icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: JapaneseColors.wakatake.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: community.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          community.imageUrl!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.groups, color: JapaneseColors.wakatake, size: 32),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (community.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        community.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
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
      appBar: AppBar(
        title: Text(widget.community.name),
        actions: [
          // Notification Toggle
          IconButton(
            icon: Icon(_notificationsEnabled ? Icons.notifications_active : Icons.notifications_off),
            color: _notificationsEnabled ? JapaneseColors.wakatake : Colors.grey,
            onPressed: () async {
              setState(() => _notificationsEnabled = !_notificationsEnabled);
              
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('notify_community_${widget.community.id}', _notificationsEnabled);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_notificationsEnabled ? '🔔 Notifications ON' : '🔕 Notifications OFF'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet'))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Post to community...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _postMessage,
                    color: JapaneseColors.wakatake,
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message content
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JapaneseColors.sakura,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Reactions
          if (message.reactions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: message.reactions.entries.map((entry) {
                final emoji = entry.key;
                final users = entry.value;
                final hasReacted = user != null && users.contains(user.id);

                return GestureDetector(
                  onTap: () async {
                    try {
                      final apiClient = ref.read(apiClientProvider);
                      await apiClient.toggleReaction(message.id, emoji);
                      // Refresh would happen here via state management
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to toggle reaction: $e')),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasReacted
                          ? JapaneseColors.wakatake.withOpacity(0.2)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasReacted ? JapaneseColors.wakatake : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '$emoji ${users.length}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}
