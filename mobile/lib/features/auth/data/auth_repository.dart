import 'dart:convert';

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
      data: {'username': username, 'password': password},
    );
    return LoginResult.fromJson(response.data!);
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
      data: {
        'imageBase64': 'data:$safeMime;base64,${base64Encode(bytes)}',
      },
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
