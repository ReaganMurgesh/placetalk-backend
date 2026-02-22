class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? homeRegion;
  final String? country;
  final DateTime createdAt;
  final bool isB2bPartner;  // spec 2.4: can edit/delete any pin remotely
  // spec 5: display profile fields
  final String? nickname;   // max 20 chars
  final String? bio;        // max 15 chars
  final String? username;   // max 15 alphanumeric display handle

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.homeRegion,
    this.country,
    required this.createdAt,
    this.isB2bPartner = false,
    this.nickname,
    this.bio,
    this.username,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      homeRegion: json['homeRegion'] as String?,
      country: json['country'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isB2bPartner: (json['isB2bPartner'] ?? json['is_b2b_partner'] ?? false) as bool,
      nickname: json['nickname'] as String?,
      bio: json['bio'] as String?,
      username: json['username'] as String?,
    );
  }

  bool get isNormalUser => role == 'normal';
  bool get isCommunityUser => role == 'community';
  /// Display name: username if set, otherwise nickname, otherwise name
  String get displayName => username ?? nickname ?? name;
}
