import 'package:dio/dio.dart';
import 'package:placetalk/core/config/api_config.dart';
import 'package:placetalk/models/user.dart';
import 'package:placetalk/models/pin.dart';

class ApiClient {
  late final Dio _dio;
  String? _authToken;

  /// Called automatically whenever any API request returns HTTP 401.
  /// Wire this up to AuthNotifier.logout() so the whole app logs out
  /// and shows the login screen — not just a red "failed" SnackBar.
  void Function()? onUnauthorized;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),  // Increased for slow Render free tier
      receiveTimeout: const Duration(seconds: 30),  // Bcrypt can be slow
      sendTimeout: const Duration(seconds: 30),
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
        final status = error.response?.statusCode ?? 'no status';
        final body   = error.response?.data ?? error.message;
        print('❌ API Error [$status]: ${error.requestOptions.uri}');
        print('   Body: $body');
        // Global 401 handler: clear token + trigger app-wide logout.
        // This fires for EVERY endpoint (like, hide, report, heartbeat…)
        // so the user is immediately redirected to login instead of
        // seeing confusing "failed" SnackBars.
        if (error.response?.statusCode == 401) {
          _authToken = null;
          onUnauthorized?.call();
        }
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
    String? nickname,
    String? bio,
    String? username,
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
        if (nickname != null) 'nickname': nickname,
        if (bio != null) 'bio': bio,
        if (username != null) 'username': username,
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

  /// Update the current user's display profile (nickname, bio, username).
  /// Fields are optional — only provided fields are updated.
  Future<User> updateProfile({
    String? nickname,
    String? bio,
    String? username,
  }) async {
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (bio != null) body['bio'] = bio;
    if (username != null) body['username'] = username;

    final response = await _dio.patch(
      ApiConfig.authProfile,
      data: body,
    );
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
    String? externalLink,
    bool chatEnabled = false,
    bool isPrivate = false,
    String? expiresAt, // ISO-8601; null → backend default (1 year)
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
        'externalLink': externalLink,
        'chatEnabled': chatEnabled,
        'isPrivate': isPrivate,
        if (expiresAt != null) 'expiresAt': expiresAt,
      },
    );
    
    return Pin.fromJson(response.data['pin']);
  }

  /// Spec 2.4: Edit a pin. Caller must supply current GPS coords for 50m check.
  Future<Pin> updatePin(
    String pinId, {
    String? title,
    String? directions,
    String? details,
    String? externalLink,
    bool? chatEnabled,
    required double userLat,
    required double userLon,
  }) async {
    final response = await _dio.put(
      '/pins/$pinId',
      data: {
        if (title != null) 'title': title,
        if (directions != null) 'directions': directions,
        if (details != null) 'details': details,
        if (externalLink != null) 'externalLink': externalLink,
        if (chatEnabled != null) 'chatEnabled': chatEnabled,
        'userLat': userLat,
        'userLon': userLon,
      },
    );
    return Pin.fromJson(response.data['pin']);
  }

  /// Spec 2.4: Soft-delete a pin. Caller must supply current GPS coords for 50m check.
  Future<void> deletePin(
    String pinId, {
    required double userLat,
    required double userLon,
  }) async {
    await _dio.delete(
      '/pins/$pinId',
      data: {'userLat': userLat, 'userLon': userLon},
    );
  }

  Future<Pin> getPinById(String pinId) async {
    final response = await _dio.get('${ApiConfig.pinsGetById}/$pinId');
    return Pin.fromJson(response.data['pin']);
  }

  Future<List<Pin>> getMyPins() async {
    print('🌐 ApiClient: Making request to ${ApiConfig.pinsMyPins}');
    final response = await _dio.get(ApiConfig.pinsMyPins);
    print('🌐 ApiClient: Response status = ${response.statusCode}');
    print('🌐 ApiClient: Response data = ${response.data}');
    
    final pins = response.data['pins'] as List;
    print('🌐 ApiClient: Parsed ${pins.length} pins from response');
    
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

  Future<Map<String, dynamic>> reportPin(String pinId) async {
    final response = await _dio.post('/pins/$pinId/report');
    return response.data;
  }

  Future<void> hidePin(String pinId) async {
    await _dio.post('/pins/$pinId/hide');
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

  Future<Map<String, dynamic>> findOrCreateCommunity(String name) async {
    final response = await _dio.post(
      '/communities/find-or-create',
      data: {'name': name},
    );
    return response.data['community'];
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
      '/communities/messages/$messageId/reactions',
      data: {'emoji': emoji},
    );
  }

  // ── spec 3.1: Community pin feed ─────────────────────────────────────────
  Future<List<dynamic>> getCommunityFeed(String communityId, {int limit = 30, int offset = 0}) async {
    final response = await _dio.get(
      '/communities/$communityId/feed',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return response.data['feed'] ?? [];
  }

  // ── spec 3.2: Invite link management ─────────────────────────────────────
  Future<Map<String, dynamic>> createCommunityInvite(String communityId) async {
    final response = await _dio.post('/communities/$communityId/invite');
    return response.data; // { invite: {...}, inviteUrl: '/join/<code>' }
  }

  Future<Map<String, dynamic>> joinByInviteCode(String code) async {
    final response = await _dio.post('/communities/join-by-invite/$code');
    return response.data['community'];
  }

  // ── spec 3.3 + 3.4: Per-member settings (notifications + hide) ───────────
  Future<void> updateCommunityMemberSettings(
    String communityId, {
    bool? notificationsOn,
    bool? hometownNotify,
    bool? isHidden,
    bool? hideMapPins,
  }) async {
    await _dio.put('/communities/$communityId/member-settings', data: {
      if (notificationsOn != null) 'notificationsOn': notificationsOn,
      if (hometownNotify != null) 'hometownNotify': hometownNotify,
      if (isHidden != null) 'isHidden': isHidden,
      if (hideMapPins != null) 'hideMapPins': hideMapPins,
    });
  }

  // ── spec 3.4: Like / unlike community ────────────────────────────────────
  Future<int> likeCommunity(String communityId) async {
    final response = await _dio.post('/communities/$communityId/like');
    return (response.data['likeCount'] as num?)?.toInt() ?? 0;
  }

  Future<int> unlikeCommunity(String communityId) async {
    final response = await _dio.delete('/communities/$communityId/like');
    return (response.data['likeCount'] as num?)?.toInt() ?? 0;
  }

  // ── spec 3.4: Report community ────────────────────────────────────────────
  Future<void> reportCommunity(String communityId, String reason) async {
    await _dio.post('/communities/$communityId/report', data: {'reason': reason});
  }

  // ── spec 3.5: Communities near location (empty state suggestion) ──────────
  Future<List<dynamic>> getCommunitiesNear(double lat, double lon, {double radiusMeters = 5000}) async {
    final response = await _dio.get('/communities/near', queryParameters: {
      'lat': lat,
      'lon': lon,
      'radius': radiusMeters,
    });
    return response.data['communities'] ?? [];
  }

  // ── spec 3: Community detail by ID ────────────────────────────────────────
  Future<Map<String, dynamic>> getCommunityById(String communityId) async {
    final response = await _dio.get('/communities/$communityId');
    return response.data['community'];
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

  // -------------------------------------------------------------------------
  // spec 4.1 Tab 1 — Passive log
  // -------------------------------------------------------------------------
  Future<List<dynamic>> getDiaryPassiveLog({String sort = 'recent'}) async {
    final response = await _dio.get('/diary/passive-log', queryParameters: {'sort': sort});
    return response.data['entries'] ?? [];
  }

  Future<void> verifyGhostPin(String pinId) async {
    await _dio.post('/diary/ghost/$pinId/verify');
  }

  // -------------------------------------------------------------------------
  // spec 4.1 Tab 2 — My Pins with engagement metrics
  // -------------------------------------------------------------------------
  Future<List<dynamic>> getDiaryMyPinsMetrics() async {
    final response = await _dio.get('/diary/my-pins-metrics');
    return response.data['pins'] ?? [];
  }

  // -------------------------------------------------------------------------
  // spec 4.2 — Full-text diary search
  // -------------------------------------------------------------------------
  Future<List<dynamic>> searchDiary(String query) async {
    final response = await _dio.get('/diary/search', queryParameters: {'q': query});
    return response.data['results'] ?? [];
  }
}
