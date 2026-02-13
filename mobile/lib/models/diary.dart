class TimelineEntry {
  final String id;
  final String userId;
  final String pinId;
  final String activityType; // 'visited', 'liked', 'commented', 'created'
  final DateTime createdAt;
  
  // Pin details
  final String pinTitle;
  final String? pinAttribute;
  final double pinLat;
  final double pinLon;

  TimelineEntry({
    required this.id,
    required this.userId,
    required this.pinId,
    required this.activityType,
    required this.createdAt,
    required this.pinTitle,
    this.pinAttribute,
    required this.pinLat,
    required this.pinLon,
  });

  factory TimelineEntry.fromJson(Map<String, dynamic> json) {
    return TimelineEntry(
      id: json['id'],
      userId: json['userId'],
      pinId: json['pinId'],
      activityType: json['activityType'],
      createdAt: DateTime.parse(json['createdAt']),
      pinTitle: json['pinTitle'],
      pinAttribute: json['pinAttribute'],
      pinLat: json['pinLat'].toDouble(),
      pinLon: json['pinLon'].toDouble(),
    );
  }

  String get activityEmoji {
    switch (activityType) {
      case 'visited':
        return '👣';
      case 'liked':
        return '❤️';
      case 'commented':
        return '💬';
      case 'created':
        return '✨';
      default:
        return '📍';
    }
  }

  String get activityLabel {
    switch (activityType) {
      case 'visited':
        return 'Visited';
      case 'liked':
        return 'Liked';
      case 'commented':
        return 'Commented on';
      case 'created':
        return 'Created';
      default:
        return 'Interacted with';
    }
  }
}

class UserStats {
  final int totalActivities;
  final int currentStreak;
  final int longestStreak;
  final List<Badge> badges;

  UserStats({
    required this.totalActivities,
    required this.currentStreak,
    required this.longestStreak,
    required this.badges,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalActivities: json['totalActivities'],
      currentStreak: json['currentStreak'],
      longestStreak: json['longestStreak'],
      badges: (json['badges'] as List)
          .map((b) => Badge.fromJson(b))
          .toList(),
    );
  }
}

class Badge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final DateTime earnedAt;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.earnedAt,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: json['icon'],
      earnedAt: DateTime.parse(json['earnedAt']),
    );
  }
}
