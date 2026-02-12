// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pin.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Pin _$PinFromJson(Map<String, dynamic> json) => Pin(
  id: json['id'] as String,
  title: json['title'] as String,
  directions: json['directions'] as String,
  details: json['details'] as String?,
  lat: (json['lat'] as num).toDouble(),
  lon: (json['lon'] as num).toDouble(),
  type: json['type'] as String,
  pinCategory: json['pinCategory'] as String,
  attributeId: json['attributeId'] as String?,
  createdBy: json['createdBy'] as String,
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  likeCount: (json['likeCount'] as num).toInt(),
  dislikeCount: (json['dislikeCount'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  distance: (json['distance'] as num?)?.toDouble(),
);

Map<String, dynamic> _$PinToJson(Pin instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'directions': instance.directions,
  'details': instance.details,
  'lat': instance.lat,
  'lon': instance.lon,
  'type': instance.type,
  'pinCategory': instance.pinCategory,
  'attributeId': instance.attributeId,
  'createdBy': instance.createdBy,
  'expiresAt': instance.expiresAt.toIso8601String(),
  'likeCount': instance.likeCount,
  'dislikeCount': instance.dislikeCount,
  'createdAt': instance.createdAt.toIso8601String(),
  'distance': instance.distance,
};
