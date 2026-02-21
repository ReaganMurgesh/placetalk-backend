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
      pinTitle: json['pinTitle'] ?? '[Deleted Pin]',
      pinAttribute: json['pinAttribute'],
      pinLat: (json['pinLat'] ?? 0).toDouble(),
      pinLon: (json['pinLon'] ?? 0).toDouble(),
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
      case 'reported':
        return '🚩';
      case 'hidden':
        return '🙈';
      case 'ghost_pass':
        return '👻';
      case 'discovered':
        return '🔍';
      default:
        return '📍';
    }
  }

  String get activityLabel {
    switch (activityType) {
      case 'visited':
        return 'Passed By';
      case 'liked':
        return 'Liked';
      case 'commented':
        return 'Commented on';
      case 'created':
        return 'Created';
      case 'reported':
        return 'Reported';
      case 'hidden':
        return 'Hidden';
      case 'ghost_pass':
        return 'Ghosted';
      case 'discovered':
        return 'Discovered';
      default:
        return 'Interacted with';
    }
  }
}

class UserStats {
  final int totalActivities;
  final int totalPinsCreated;
  final int totalDiscoveries;
  final int currentStreak;
  final int longestStreak;
  final List<Badge> badges;

  UserStats({
    required this.totalActivities,
    required this.totalPinsCreated,
    required this.totalDiscoveries,
    required this.currentStreak,
    required this.longestStreak,
    required this.badges,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalActivities: json['totalActivities'] ?? 0,
      totalPinsCreated: json['totalPinsCreated'] ?? 0,
      totalDiscoveries: json['totalDiscoveries'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      badges: (json['badges'] as List? ?? [])
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
