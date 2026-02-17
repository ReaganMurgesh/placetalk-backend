/// Model for tracking pins that user has passed/visited
class PassedPin {
  final String id;
  final String pinId;
  final String pinTitle;
  final String? pinAttribute;
  final double pinLat;
  final double pinLon;
  final String pinCreatedBy;
  final DateTime passedAt;
  final String passType; // 'passed_nearby', 'visited', 'interacted'
  final double distanceFromPin; // meters when they passed it
  
  PassedPin({
    required this.id,
    required this.pinId,
    required this.pinTitle,
    this.pinAttribute,
    required this.pinLat,
    required this.pinLon,
    required this.pinCreatedBy,
    required this.passedAt,
    required this.passType,
    required this.distanceFromPin,
  });
  
  factory PassedPin.fromJson(Map<String, dynamic> json) {
    return PassedPin(
      id: json['id'],
      pinId: json['pinId'],
      pinTitle: json['pinTitle'],
      pinAttribute: json['pinAttribute'],
      pinLat: json['pinLat'].toDouble(),
      pinLon: json['pinLon'].toDouble(),
      pinCreatedBy: json['pinCreatedBy'],
      passedAt: DateTime.parse(json['passedAt']),
      passType: json['passType'],
      distanceFromPin: json['distanceFromPin'].toDouble(),
    );
  }
  
  String get passTypeDisplay {
    switch (passType) {
      case 'passed_nearby':
        return 'Passed nearby';
      case 'visited':
        return 'Visited'; 
      case 'interacted':
        return 'Interacted with';
      default:
        return 'Discovered';
    }
  }
  
  String get passTypeEmoji {
    switch (passType) {
      case 'passed_nearby':
        return '🚶';
      case 'visited':
        return '📍';
      case 'interacted':
        return '⭐';
      default:
        return '👀';
    }
  }
}

/// Statistics for passed pins
class PassedPinsStats {
  final int totalPassed;
  final int totalVisited;
  final int totalInteracted;
  final int uniqueCreators;
  final double totalDistanceCovered; // km
  
  PassedPinsStats({
    required this.totalPassed,
    required this.totalVisited,
    required this.totalInteracted,
    required this.uniqueCreators,
    required this.totalDistanceCovered,
  });
  
  factory PassedPinsStats.fromJson(Map<String, dynamic> json) {
    return PassedPinsStats(
      totalPassed: json['totalPassed'],
      totalVisited: json['totalVisited'],
      totalInteracted: json['totalInteracted'],
      uniqueCreators: json['uniqueCreators'],
      totalDistanceCovered: json['totalDistanceCovered'].toDouble(),
    );
  }
}