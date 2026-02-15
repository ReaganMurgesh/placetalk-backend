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
    );
  }

  bool get isLocationPin => type == 'location';
  bool get isSerendipityPin => type == 'serendipity';
  bool get isCommunityPin => pinCategory == 'community';
  
  String get distanceText {
    if (distance == null) return '';
    if (distance! < 10) return '< 10m';
    return '${distance!.toStringAsFixed(0)}m';
  }
}
