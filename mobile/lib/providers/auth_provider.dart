import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:placetalk/services/api_client.dart';
import 'package:placetalk/models/user.dart';

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

// Auth State Provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});

// Current User Provider (convenience provider for accessing current user)
final currentUserProvider = FutureProvider<User?>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState.isAuthenticated && authState.token != null) {
    try {
      final apiClient = ref.watch(apiClientProvider);
      apiClient.setAuthToken(authState.token!);
      return await apiClient.getCurrentUser();
    } catch (e) {
      return authState.user;
    }
  }
  return authState.user;
});

class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isAuthenticated => user != null && token != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(AuthState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _apiClient.login(email: email, password: password);
      final user = User.fromJson(response['user']);
      final token = response['tokens']['accessToken'];
      
      _apiClient.setAuthToken(token);
      state = state.copyWith(user: user, token: token, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? homeRegion,
    String? country,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _apiClient.register(
        name: name,
        email: email,
        password: password,
        role: role,
        homeRegion: homeRegion,
        country: country,
      );
      
      final user = User.fromJson(response['user']);
      final token = response['tokens']['accessToken'];
      
      _apiClient.setAuthToken(token);
      state = state.copyWith(user: user, token: token, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    _apiClient.clearAuthToken();
    state = AuthState();
  }
}
