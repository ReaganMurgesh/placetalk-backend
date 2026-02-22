// Community type constants for spec 3.2
enum CommunityType { open, inviteOnly, paidRestricted }

extension CommunityTypeExt on CommunityType {
  String get value {
    switch (this) {
      case CommunityType.open: return 'open';
      case CommunityType.inviteOnly: return 'invite_only';
      case CommunityType.paidRestricted: return 'paid_restricted';
    }
  }

  String get label {
    switch (this) {
      case CommunityType.open: return 'Open';
      case CommunityType.inviteOnly: return 'Invite Only';
      case CommunityType.paidRestricted: return 'Paid / Restricted';
    }
  }

  static CommunityType fromString(String? s) {
    switch (s) {
      case 'invite_only': return CommunityType.inviteOnly;
      case 'paid_restricted': return CommunityType.paidRestricted;
      default: return CommunityType.open;
    }
  }
}

class Community {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String createdBy;
  final CommunityType communityType;  // spec 3.2
  final int likeCount;                // spec 3.4
  final DateTime createdAt;
  // Viewer-specific fields
  final bool likedByMe;
  final bool isMember;
  final int? memberCount;
  // Per-member settings (spec 3.3 + 3.4)
  final bool notificationsOn;
  final bool hometownNotify;
  final bool isHidden;
  final bool hideMapPins;

  Community({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.createdBy,
    this.communityType = CommunityType.open,
    this.likeCount = 0,
    required this.createdAt,
    this.likedByMe = false,
    this.isMember = false,
    this.memberCount,
    this.notificationsOn = false,
    this.hometownNotify = false,
    this.isHidden = false,
    this.hideMapPins = false,
  });

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      createdBy: json['createdBy'] as String,
      communityType: CommunityTypeExt.fromString(json['communityType'] as String?),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      likedByMe: (json['likedByMe'] as bool?) ?? false,
      isMember: (json['isMember'] as bool?) ?? false,
      memberCount: (json['memberCount'] as num?)?.toInt(),
      notificationsOn: (json['notificationsOn'] as bool?) ?? false,
      hometownNotify: (json['hometownNotify'] as bool?) ?? false,
      isHidden: (json['isHidden'] as bool?) ?? false,
      hideMapPins: (json['hideMapPins'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'communityType': communityType.value,
      'likeCount': likeCount,
      'createdAt': createdAt.toIso8601String(),
      'likedByMe': likedByMe,
      'isMember': isMember,
      'memberCount': memberCount,
      'notificationsOn': notificationsOn,
      'hometownNotify': hometownNotify,
      'isHidden': isHidden,
      'hideMapPins': hideMapPins,
    };
  }

  Community copyWith({
    bool? likedByMe,
    int? likeCount,
    bool? isMember,
    bool? notificationsOn,
    bool? hometownNotify,
    bool? isHidden,
    bool? hideMapPins,
  }) {
    return Community(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl,
      createdBy: createdBy,
      communityType: communityType,
      likeCount: likeCount ?? this.likeCount,
      createdAt: createdAt,
      likedByMe: likedByMe ?? this.likedByMe,
      isMember: isMember ?? this.isMember,
      memberCount: memberCount,
      notificationsOn: notificationsOn ?? this.notificationsOn,
      hometownNotify: hometownNotify ?? this.hometownNotify,
      isHidden: isHidden ?? this.isHidden,
      hideMapPins: hideMapPins ?? this.hideMapPins,
    );
  }
}

// spec 3.1 — Feed item: a pin visible inside a community's feed
class CommunityFeedItem {
  final String pinId;
  final String title;
  final String directions;
  final String pinType;
  final String pinCategory;
  final String createdBy;
  final double lat;
  final double lon;
  final int likeCount;
  final String? externalLink;
  final bool chatEnabled;
  final DateTime createdAt;
  final DateTime? chatLastAt;
  final DateTime feedUpdatedAt;

  CommunityFeedItem({
    required this.pinId,
    required this.title,
    required this.directions,
    required this.pinType,
    required this.pinCategory,
    required this.createdBy,
    required this.lat,
    required this.lon,
    required this.likeCount,
    this.externalLink,
    required this.chatEnabled,
    required this.createdAt,
    this.chatLastAt,
    required this.feedUpdatedAt,
  });

  factory CommunityFeedItem.fromJson(Map<String, dynamic> json) {
    double parseD(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return CommunityFeedItem(
      pinId: json['pinId'] as String,
      title: json['title'] as String,
      directions: json['directions'] as String,
      pinType: json['pinType'] as String? ?? 'location',
      pinCategory: json['pinCategory'] as String? ?? 'community',
      createdBy: json['createdBy'] as String,
      lat: parseD(json['lat']),
      lon: parseD(json['lon']),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      externalLink: json['externalLink'] as String?,
      chatEnabled: (json['chatEnabled'] as bool?) ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      chatLastAt: json['chatLastAt'] != null ? DateTime.parse(json['chatLastAt'] as String) : null,
      feedUpdatedAt: DateTime.parse(json['feedUpdatedAt'] as String),
    );
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
