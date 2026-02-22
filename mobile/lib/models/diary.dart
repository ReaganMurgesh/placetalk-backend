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

// ---------------------------------------------------------------------------
// spec 4.1 Tab 1 — Passive Log entry (ghost_pass / verified)
// ---------------------------------------------------------------------------
class PassiveLogEntry {
  final String activityId;
  final String pinId;
  final String pinTitle;
  final String pinType;
  final String activityType;
  final double pinLat;
  final double pinLon;
  final int pinLikeCount;
  final bool isVerified;
  final DateTime? verifiedAt;
  final DateTime passedAt;

  PassiveLogEntry({
    required this.activityId,
    required this.pinId,
    required this.pinTitle,
    required this.pinType,
    required this.activityType,
    required this.pinLat,
    required this.pinLon,
    required this.pinLikeCount,
    required this.isVerified,
    this.verifiedAt,
    required this.passedAt,
  });

  factory PassiveLogEntry.fromJson(Map<String, dynamic> json) {
    return PassiveLogEntry(
      activityId: json['activityId'] as String,
      pinId: json['pinId'] as String,
      pinTitle: json['pinTitle'] as String? ?? '[Deleted Pin]',
      pinType: json['pinType'] as String? ?? 'normal',
      activityType: json['activityType'] as String? ?? 'ghost_pass',
      pinLat: (json['pinLat'] ?? 0).toDouble(),
      pinLon: (json['pinLon'] ?? 0).toDouble(),
      pinLikeCount: json['pinLikeCount'] as int? ?? 0,
      isVerified: json['isVerified'] as bool? ?? false,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'] as String)
          : null,
      passedAt: DateTime.parse(json['passedAt'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// spec 4.1 Tab 2 — My Pins with engagement metrics
// ---------------------------------------------------------------------------
class DiaryPinMetrics {
  final String id;
  final String title;
  final String? directions;
  final double lat;
  final double lon;
  final String pinType;
  final String? pinCategory;
  final int likeCount;
  final int dislikeCount;
  final int passThrough;
  final int hideCount;
  final int reportCount;
  final DateTime createdAt;

  DiaryPinMetrics({
    required this.id,
    required this.title,
    this.directions,
    required this.lat,
    required this.lon,
    required this.pinType,
    this.pinCategory,
    required this.likeCount,
    required this.dislikeCount,
    required this.passThrough,
    required this.hideCount,
    required this.reportCount,
    required this.createdAt,
  });

  factory DiaryPinMetrics.fromJson(Map<String, dynamic> json) {
    return DiaryPinMetrics(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      directions: json['directions'] as String?,
      lat: (json['lat'] ?? 0).toDouble(),
      lon: (json['lon'] ?? 0).toDouble(),
      pinType: json['pinType'] as String? ?? 'normal',
      pinCategory: json['pinCategory'] as String?,
      likeCount: json['likeCount'] as int? ?? 0,
      dislikeCount: json['dislikeCount'] as int? ?? 0,
      passThrough: (json['passThrough'] ?? json['pass_through_count']) as int? ?? 0,
      hideCount: (json['hideCount'] ?? json['hide_count']) as int? ?? 0,
      reportCount: (json['reportCount'] ?? json['report_count']) as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// spec 4.2 — Full-text search result
// ---------------------------------------------------------------------------
class DiarySearchResult {
  final String activityId;
  final String pinId;
  final String pinTitle;
  final String pinType;
  final String pinCategory;
  final String pinDirections;
  final double pinLat;
  final double pinLon;
  final String activityType;
  final bool isVerified;
  final DateTime lastActivity;

  DiarySearchResult({
    required this.activityId,
    required this.pinId,
    required this.pinTitle,
    required this.pinType,
    required this.pinCategory,
    required this.pinDirections,
    required this.pinLat,
    required this.pinLon,
    required this.activityType,
    required this.isVerified,
    required this.lastActivity,
  });

  factory DiarySearchResult.fromJson(Map<String, dynamic> json) {
    return DiarySearchResult(
      activityId: json['activityId'] as String,
      pinId: json['pinId'] as String,
      pinTitle: json['pinTitle'] as String? ?? '[Deleted Pin]',
      pinType: json['pinType'] as String? ?? 'normal',
      pinCategory: json['pinCategory'] as String? ?? '',
      pinDirections: json['pinDirections'] as String? ?? '',
      pinLat: (json['pinLat'] ?? 0).toDouble(),
      pinLon: (json['pinLon'] ?? 0).toDouble(),
      activityType: json['activityType'] as String? ?? 'ghost_pass',
      isVerified: json['isVerified'] as bool? ?? false,
      lastActivity: DateTime.parse(json['lastActivity'] as String),
    );
  }
}
