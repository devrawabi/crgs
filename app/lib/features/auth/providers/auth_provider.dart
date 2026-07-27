import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/auth_session_storage.dart';

class AuthState {
  const AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isRestoring = true,
    this.error,
    this.rememberMe = false,
  });

  final UserModel? user;
  final bool isAuthenticated;
  final bool isLoading;
  final bool isRestoring;
  final String? error;
  final bool rememberMe;

  AuthState copyWith({
    UserModel? user,
    bool? isAuthenticated,
    bool? isLoading,
    bool? isRestoring,
    String? error,
    bool? rememberMe,
    bool clearError = false,
  }) =>
      AuthState(
        user: user ?? this.user,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isLoading: isLoading ?? this.isLoading,
        isRestoring: isRestoring ?? this.isRestoring,
        error: clearError ? null : (error ?? this.error),
        rememberMe: rememberMe ?? this.rememberMe,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository, this._storage, this._apiClient)
      : super(const AuthState(isRestoring: true)) {
    _restoreSession();
  }

  final AuthRepository _repository;
  final AuthSessionStorage _storage;
  final ApiClient _apiClient;

  Future<void> _restoreSession() async {
    final savedUser = await _storage.loadUser();
    if (savedUser != null &&
        savedUser.accessToken != null &&
        savedUser.accessToken!.isNotEmpty) {
      _apiClient.setAuthToken(savedUser.accessToken);
      state = AuthState(
        user: savedUser,
        isAuthenticated: true,
        rememberMe: true,
        isRestoring: false,
      );
      return;
    }

    await _storage.clear();
    _apiClient.setAuthToken(null);
    state = state.copyWith(isRestoring: false, isAuthenticated: false);
  }

  Future<bool> login({
    required String employeeId,
    required String password,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _repository.login(
        employeeCode: employeeId.trim(),
        password: password,
      );

      if (user.accessToken == null || user.accessToken!.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Login response missing token',
        );
        return false;
      }

      _apiClient.setAuthToken(user.accessToken);

      if (rememberMe) {
        await _storage.saveUser(user);
      } else {
        await _storage.clear();
      }

      state = AuthState(
        user: user,
        isAuthenticated: true,
        rememberMe: rememberMe,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to sign in. Please try again.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clear();
    _apiClient.setAuthToken(null);
    state = const AuthState(isRestoring: false);
  }

  Future<void> completeOnboarding() async {
    final user = state.user;
    if (user == null) return;

    await _repository.completeOnboarding(employeeCode: user.employeeCode);

    final updatedUser = user.copyWith(onboardingCompleted: true);
    if (state.rememberMe) {
      await _storage.saveUser(updatedUser);
    }

    state = state.copyWith(user: updatedUser);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final authSessionStorageProvider = Provider<AuthSessionStorage>((ref) {
  return AuthSessionStorage();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(authSessionStorageProvider),
    ref.watch(apiClientProvider),
  );
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});
