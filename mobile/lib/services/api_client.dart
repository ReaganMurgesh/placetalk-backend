import 'package:dio/dio.dart';
import 'package:placetalk/core/config/api_config.dart';
import 'package:placetalk/models/user.dart';
import 'package:placetalk/models/pin.dart';

class ApiClient {
  late final Dio _dio;
  String? _authToken;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),  // Increased for phone
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true', // Bypasses Ngrok warning page
      },
    ));

    // Add interceptor for auth token + error logging
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        print('📡 API: ${options.method} ${options.uri}');
        return handler.next(options);
      },
      onError: (error, handler) {
        print('❌ API Error: ${error.type} - ${error.message}');
        print('   URL: ${error.requestOptions.uri}');
        return handler.next(error);
      },
    ));
  }

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  // ========== Authentication ==========

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? homeRegion,
    String? country,
  }) async {
    final response = await _dio.post(
      ApiConfig.authRegister,
      data: {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'homeRegion': homeRegion,
        'country': country ?? 'Japan',
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiConfig.authLogin,
      data: {
        'email': email,
        'password': password,
      },
    );
    return response.data;
  }

  Future<User> getCurrentUser() async {
    final response = await _dio.get(ApiConfig.authMe);
    return User.fromJson(response.data['user']);
  }

  // ========== Discovery ==========

  Future<List<Pin>> sendHeartbeat({
    required double lat,
    required double lon,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.discoveryHeartbeat,
        data: {
          'lat': lat,
          'lon': lon,
        },
      );
      
      final discovered = response.data['discovered'] as List? ?? [];
      return discovered.map((json) => Pin.fromJson(json)).toList();
    } on DioException catch (e) {
      print('❌ Heartbeat failed: ${e.type} - ${e.message}');
      return []; // Don't crash — return empty list
    }
  }

  Future<List<Pin>> getNearbyPins({
    required double lat,
    required double lon,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.discoveryNearby,
        queryParameters: {
          'lat': lat,
          'lon': lon,
        },
      );
      
      final discovered = response.data['discovered'] as List? ?? [];
      return discovered.map((json) => Pin.fromJson(json)).toList();
    } on DioException catch (e) {
      print('❌ Nearby failed: ${e.type} - ${e.message}');
      return [];
    }
  }

  // ========== Pins ==========

  Future<Pin> createPin({
    required String title,
    required String directions,
    String? details,
    required double lat,
    required double lon,
    required String type,
    required String pinCategory,
    String? attributeId,
    String? visibleFrom,
    String? visibleTo,
  }) async {
    final response = await _dio.post(
      ApiConfig.pinsCreate,
      data: {
        'title': title,
        'directions': directions,
        'details': details,
        'lat': lat,
        'lon': lon,
        'type': type,
        'pinCategory': pinCategory,
        'attributeId': attributeId,
        'visibleFrom': visibleFrom,
        'visibleTo': visibleTo,
      },
    );
    
    return Pin.fromJson(response.data['pin']);
  }

  Future<Pin> getPinById(String pinId) async {
    final response = await _dio.get('${ApiConfig.pinsGetById}/$pinId');
    return Pin.fromJson(response.data['pin']);
  }

  Future<List<Pin>> getMyPins() async {
    final response = await _dio.get(ApiConfig.pinsMyPins);
    final pins = response.data['pins'] as List;
    return pins.map((json) => Pin.fromJson(json)).toList();
  }

  // ========== Interactions ==========

  Future<Map<String, dynamic>> likePin(String pinId) async {
    final response = await _dio.post('/pins/$pinId/like');
    return response.data;
  }

  Future<Map<String, dynamic>> dislikePin(String pinId) async {
    final response = await _dio.post('/pins/$pinId/dislike');
    return response.data;
  }

  // ========== SERENDIPITY: Pin Interactions ==========

  /// Mark pin as "Good" (7-day cooldown timer)
  Future<void> markPinGood(String pinId) async {
    await _dio.post('/pins/$pinId/mark-good');
  }

  /// Mark pin as "Bad" (mute forever)
  Future<void> markPinBad(String pinId) async {
    await _dio.post('/pins/$pinId/mark-bad');
  }

  /// Unmute pin (re-enable notifications)
  Future<void> unmutePinForever(String pinId) async {
    await _dio.post('/pins/$pinId/unmute');
  }

  /// Get all user interactions (for syncing)
  Future<List<Map<String, dynamic>>> getPinInteractions() async {
    final response = await _dio.get('/pins/interactions');
    return List<Map<String, dynamic>>.from(response.data['interactions']);
  }

  // ========== Communities ==========

  Future<List<dynamic>> getJoinedCommunities() async {
    final response = await _dio.get('/communities/joined');
    return response.data['communities'] ?? [];
  }

  Future<void> joinCommunity(String communityId) async {
    await _dio.post('/communities/$communityId/join');
  }

  Future<void> leaveCommunity(String communityId) async {
    await _dio.delete('/communities/$communityId/leave');
  }

  Future<List<dynamic>> getCommunityMessages(String communityId, {int limit = 50, int offset = 0}) async {
    final response = await _dio.get(
      '/communities/$communityId/messages',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return response.data['messages'] ?? [];
  }

  Future<void> postCommunityMessage(String communityId, {required String content, String? imageUrl}) async {
    await _dio.post(
      '/communities/$communityId/messages',
      data: {'content': content, 'imageUrl': imageUrl},
    );
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    await _dio.post(
      '/messages/$messageId/reactions',
      data: {'emoji': emoji},
    );
  }

  // ========== Diary ==========

  Future<List<dynamic>> getDiaryTimeline({DateTime? startDate, DateTime? endDate, int limit = 100}) async {
    final queryParams = <String, dynamic>{'limit': limit};
    if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
    if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

    final response = await _dio.get('/diary/timeline', queryParameters: queryParams);
    return response.data['timeline'] ?? [];
  }

  Future<Map<String, dynamic>> getDiaryStats() async {
    final response = await _dio.get('/diary/stats');
    return response.data;
  }

  Future<void> logActivity(String pinId, String activityType, {Map<String, dynamic>? metadata}) async {
    await _dio.post(
      '/diary/log',
      data: {
        'pinId': pinId,
        'activityType': activityType,
        'metadata': metadata,
      },
    );
  }
}
