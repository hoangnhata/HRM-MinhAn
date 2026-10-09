import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/current_user.dart';
import 'auth_models.dart';

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Future<LoginResult> login(String username, String password) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'username': username,
        'password': password,
        // Nhận refresh token: giữ đăng nhập tới khi người dùng tự đăng xuất.
        'rememberDevice': true,
        'deviceLabel': _deviceLabel(),
      },
    );
    return LoginResult.fromJson(response.data!);
  }

  /// Thu hồi refresh token của thiết bị này trên máy chủ.
  Future<void> logout(String refreshToken) async {
    await _client.post('/auth/logout', data: {'refreshToken': refreshToken});
  }

  static String _deviceLabel() {
    try {
      final os = Platform.isIOS
          ? 'iOS'
          : Platform.isAndroid
          ? 'Android'
          : Platform.operatingSystem;
      final label = '$os ${Platform.operatingSystemVersion}'.trim();
      return label.length > 120 ? label.substring(0, 120) : label;
    } catch (_) {
      return 'mobile';
    }
  }

  Future<CurrentUser> fetchMe() async {
    final response = await _client.get<Map<String, dynamic>>('/v1/account/me');
    return CurrentUser.fromJson(response.data!);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.post(
      '/v1/account/change-password',
      // Backend dùng `oldPassword` (ChangePasswordRequest), không phải `currentPassword`.
      data: {'oldPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<void> uploadSignature(
    List<int> bytes, {
    String mimeType = 'image/png',
  }) async {
    final safeMime = mimeType.startsWith('image/') ? mimeType : 'image/png';
    await _client.put(
      '/v1/account/me/signature',
      data: {'imageBase64': 'data:$safeMime;base64,${base64Encode(bytes)}'},
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
