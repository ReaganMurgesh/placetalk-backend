class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? homeRegion;
  final String? country;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.homeRegion,
    this.country,
    required this.createdAt,
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
    );
  }

  bool get isNormalUser => role == 'normal';
  bool get isCommunityUser => role == 'community';
}
