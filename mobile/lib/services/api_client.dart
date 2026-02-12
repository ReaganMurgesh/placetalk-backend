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
    final response = await _dio.post('${ApiConfig.pinsGetById}/$pinId/like');
    return response.data;
  }

  Future<Map<String, dynamic>> dislikePin(String pinId) async {
    final response = await _dio.post('${ApiConfig.pinsGetById}/$pinId/dislike');
    return response.data;
  }
}
