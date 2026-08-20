import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/salary/salary_access_store.dart';
import '../../../core/session/session_epoch.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/user_role.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

/// Nguon su thuc duy nhat cho trang thai dang nhap. Router lang nghe status
/// nay de dieu huong (login / doi mat khau / thiet lap chu ky / app chinh).
class AuthController extends StateNotifier<AuthState> {
  AuthController(
    this._ref,
    this._repository,
    this._tokenStorage,
    this._apiClient,
  ) : super(const AuthState()) {
    _apiClient.onUnauthorized = _handleUnauthorized;
    bootstrap();
  }

  final Ref _ref;
  final AuthRepository _repository;
  final TokenStorage _tokenStorage;
  final ApiClient _apiClient;

  void _resetUserScopedCaches() {
    bumpSessionEpoch(_ref);
    _ref.read(salaryAccessStoreProvider).clear();
  }

  Future<void> bootstrap() async {
    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final me = await _repository.fetchMe();
      state = state.copyWith(
        status: me.mustChangePassword
            ? AuthStatus.mustChangePassword
            : (!me.hasSignature ? AuthStatus.mustSetSignature : AuthStatus.authenticated),
        role: me.role,
        userId: me.userId,
        employeeId: me.employeeId,
        fullName: me.displayName,
        currentUser: me,
      );
    } catch (_) {
      await _tokenStorage.clear();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(errorMessage: null);
    try {
      final result = await _repository.login(username.trim(), password);
      await _tokenStorage.saveSession(
        accessToken: result.accessToken,
        role: result.role.apiValue,
        userId: result.userId,
        employeeId: result.employeeId,
        fullName: result.fullName,
      );

      // Xoá cache nick cũ trước khi gắn state nick mới.
      _resetUserScopedCaches();

      AuthStatus status;
      if (result.mustChangePassword) {
        status = AuthStatus.mustChangePassword;
      } else if (result.mustSetSignature) {
        status = AuthStatus.mustSetSignature;
      } else {
        status = AuthStatus.authenticated;
      }

      state = state.copyWith(
        status: status,
        role: result.role,
        userId: result.userId,
        employeeId: result.employeeId,
        fullName: result.fullName,
      );

      unawaited(_refreshCurrentUser());
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Đăng nhập thất bại. Vui lòng thử lại.');
      return false;
    }
  }

  Future<void> _refreshCurrentUser() async {
    try {
      final me = await _repository.fetchMe();
      state = state.copyWith(currentUser: me, fullName: me.displayName);
    } catch (_) {
      // im lang - khong lam gian trai nghiem dang nhap vi loi phu
    }
  }

  Future<void> refreshCurrentUser() => _refreshCurrentUser();

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      await _repository.changePassword(currentPassword: currentPassword, newPassword: newPassword);
      final me = await _repository.fetchMe();
      state = state.copyWith(
        status: !me.hasSignature ? AuthStatus.mustSetSignature : AuthStatus.authenticated,
        currentUser: me,
        errorMessage: null,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  Future<bool> submitSignature(
    List<int> bytes, {
    String mimeType = 'image/png',
  }) async {
    try {
      await _repository.uploadSignature(bytes, mimeType: mimeType);
      final me = await _repository.fetchMe();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        currentUser: me,
        errorMessage: null,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  void skipSignatureForNow() {
    if (state.status == AuthStatus.mustSetSignature) {
      state = state.copyWith(status: AuthStatus.authenticated);
    }
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
    _resetUserScopedCaches();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void _handleUnauthorized() {
    if (state.status == AuthStatus.unauthenticated) return;
    _tokenStorage.clear();
    _resetUserScopedCaches();
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: 'Phiên đăng nhập đã hết hạn.',
    );
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref,
    ref.watch(authRepositoryProvider),
    ref.watch(tokenStorageProvider),
    ref.watch(apiClientProvider),
  );
});
