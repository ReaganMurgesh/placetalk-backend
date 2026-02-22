class Pin {
  final String id;
  final String title;
  final String directions;
  final String? details;
  final double lat;
  final double lon;
  final String type;
  final String pinCategory;
  final String? attributeId;
  final String createdBy;
  final DateTime? expiresAt;
  final int likeCount;
  final int dislikeCount;
  final DateTime createdAt;
  final double? distance;
  final bool? isHidden;
  final bool? isDeprioritized;
  final String? externalLink;  // spec 2.2
  final bool chatEnabled;       // spec 2.2 (community pins only)
  final bool isPrivate;         // spec 2.3: Paid/restricted visibility
  final String? communityId;    // spec 3: linked community
  // spec 4.1: engagement metrics for My Pins tab
  final int passThrough;
  final int hideCount;
  final int reportCount;
  // spec 5: creator snapshot stored at creation time
  final Map<String, dynamic>? creatorSnapshot;

  Pin({
    required this.id,
    required this.title,
    required this.directions,
    this.details,
    required this.lat,
    required this.lon,
    required this.type,
    required this.pinCategory,
    this.attributeId,
    required this.createdBy,
    this.expiresAt,
    required this.likeCount,
    required this.dislikeCount,
    required this.createdAt,
    this.distance,
    this.isHidden,
    this.isDeprioritized,
    this.externalLink,
    this.chatEnabled = false,
    this.isPrivate = false,
    this.communityId,
    this.passThrough = 0,
    this.hideCount = 0,
    this.reportCount = 0,
    this.creatorSnapshot,
  });

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  factory Pin.fromJson(Map<String, dynamic> json) {
    return Pin(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? 'Untitled') as String,
      directions: (json['directions'] ?? '') as String,
      details: json['details'] as String?,
      lat: _parseDouble(json['lat']),
      lon: _parseDouble(json['lon']),
      type: (json['type'] ?? 'location') as String,
      pinCategory: (json['pinCategory'] ?? json['pin_category'] ?? 'community') as String,
      attributeId: (json['attributeId'] ?? json['attribute_id']) as String?,
      createdBy: (json['createdBy'] ?? json['created_by'] ?? '') as String,
      expiresAt: (json['expiresAt'] ?? json['expires_at']) != null
          ? DateTime.tryParse((json['expiresAt'] ?? json['expires_at']).toString())
          : null,
      likeCount: (json['likeCount'] ?? json['like_count']) as int? ?? 0,
      dislikeCount: (json['dislikeCount'] ?? json['dislike_count']) as int? ?? 0,
      createdAt: DateTime.tryParse((json['createdAt'] ?? json['created_at'] ?? '').toString()) ?? DateTime.now(),
      distance: json['distance'] != null ? _parseDouble(json['distance']) : null,
      isHidden: json['isHidden'] as bool?,
      isDeprioritized: json['isDeprioritized'] as bool?,
      externalLink: json['externalLink'] as String?,
      chatEnabled: (json['chatEnabled'] as bool?) ?? false,
      isPrivate: (json['isPrivate'] as bool?) ?? false,
      communityId: json['communityId'] as String?,
      passThrough: (json['passThrough'] ?? json['pass_through_count']) as int? ?? 0,
      hideCount: (json['hideCount'] ?? json['hide_count']) as int? ?? 0,
      reportCount: (json['reportCount'] ?? json['report_count']) as int? ?? 0,
      creatorSnapshot: json['creatorSnapshot'] as Map<String, dynamic>?,
    );
  }

  bool get isLocationPin => type == 'location';
  bool get isSerendipityPin => type == 'serendipity';
  bool get isCommunityPin => pinCategory == 'community';

  Pin copyWith({
    String? id,
    String? title,
    String? directions,
    String? details,
    double? lat,
    double? lon,
    String? type,
    String? pinCategory,
    String? attributeId,
    String? createdBy,
    DateTime? expiresAt,
    int? likeCount,
    int? dislikeCount,
    DateTime? createdAt,
    double? distance,
    bool? isHidden,
    bool? isDeprioritized,
    String? externalLink,
    bool? chatEnabled,
    bool? isPrivate,
    String? communityId,
    int? passThrough,
    int? hideCount,
    int? reportCount,
    Map<String, dynamic>? creatorSnapshot,
  }) {
    return Pin(
      id: id ?? this.id,
      title: title ?? this.title,
      directions: directions ?? this.directions,
      details: details ?? this.details,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      type: type ?? this.type,
      pinCategory: pinCategory ?? this.pinCategory,
      attributeId: attributeId ?? this.attributeId,
      createdBy: createdBy ?? this.createdBy,
      expiresAt: expiresAt ?? this.expiresAt,
      likeCount: likeCount ?? this.likeCount,
      dislikeCount: dislikeCount ?? this.dislikeCount,
      createdAt: createdAt ?? this.createdAt,
      distance: distance ?? this.distance,
      isHidden: isHidden ?? this.isHidden,
      isDeprioritized: isDeprioritized ?? this.isDeprioritized,
      externalLink: externalLink ?? this.externalLink,
      chatEnabled: chatEnabled ?? this.chatEnabled,
      isPrivate: isPrivate ?? this.isPrivate,
      communityId: communityId ?? this.communityId,
      passThrough: passThrough ?? this.passThrough,
      hideCount: hideCount ?? this.hideCount,
      reportCount: reportCount ?? this.reportCount,
      creatorSnapshot: creatorSnapshot ?? this.creatorSnapshot,
    );
  }
  
  String get distanceText {
    if (distance == null) return '';
    if (distance! < 10) return '< 10m';
    return '${distance!.toStringAsFixed(0)}m';
  }
}
