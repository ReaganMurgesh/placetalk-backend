class Community {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String createdBy;
  final DateTime createdAt;

  Community({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.createdBy,
    required this.createdAt,
  });

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      createdBy: json['createdBy'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class CommunityMessage {
  final String id;
  final String communityId;
  final String userId;
  final String content;
  final String? imageUrl;
  final Map<String, List<String>> reactions; // {"👍": ["user1", "user2"]}
  final DateTime createdAt;

  CommunityMessage({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.content,
    this.imageUrl,
    required this.reactions,
    required this.createdAt,
  });

  factory CommunityMessage.fromJson(Map<String, dynamic> json) {
    // Parse reactions from JSONB
    final reactionsJson = json['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = reactionsJson.map(
      (key, value) => MapEntry(key, List<String>.from(value as List)),
    );

    return CommunityMessage(
      id: json['id'],
      communityId: json['communityId'],
      userId: json['userId'],
      content: json['content'],
      imageUrl: json['imageUrl'],
      reactions: reactions,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'communityId': communityId,
      'userId': userId,
      'content': content,
      'imageUrl': imageUrl,
      'reactions': reactions,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Get total reaction count
  int get totalReactions {
    return reactions.values.fold(0, (sum, users) => sum + users.length);
  }

  /// Check if user has reacted with specific emoji
  bool hasUserReacted(String userId, String emoji) {
    return reactions[emoji]?.contains(userId) ?? false;
  }
}
