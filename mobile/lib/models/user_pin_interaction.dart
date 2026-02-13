/// User-Pin Interaction Model for Serendipity Notifications
/// Tracks per-user mute status, cooldown timers, and notification history
class UserPin Interaction {
  final String pinId;
  final DateTime lastSeenAt;
  final DateTime? nextNotifyAt;
  final bool isMuted;

  const UserPinInteraction({
    required this.pinId,
    required this.lastSeenAt,
    this.nextNotifyAt,
    required this.isMuted,
  });

  /// Check if user should be notified about this pin
  bool get shouldNotify {
    if (isMuted) return false; // Never notify for muted pins
    if (nextNotifyAt == null) return true; // No cooldown
    return DateTime.now().isAfter(nextNotifyAt!); // Cooldown expired?
  }

  factory UserPinInteraction.fromJson(Map<String, dynamic> json) {
    return UserPinInteraction(
      pinId: json['pinId'] as String,
      lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
      nextNotifyAt: json['nextNotifyAt'] != null
          ? DateTime.parse(json['nextNotifyAt'] as String)
          : null,
      isMuted: json['isMuted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pinId': pinId,
      'lastSeenAt': lastSeenAt.toIso8601String(),
      'nextNotifyAt': nextNotifyAt?.toIso8601String(),
      'isMuted': isMuted,
    };
  }

  UserPinInteraction copyWith({
    DateTime? lastSeenAt,
    DateTime? nextNotifyAt,
    bool? isMuted,
  }) {
    return UserPinInteraction(
      pinId: pinId,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      nextNotifyAt: nextNotifyAt ?? this.nextNotifyAt,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}
