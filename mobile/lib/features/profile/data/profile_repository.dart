import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/current_user.dart';

class ProfileRepository {
  ProfileRepository(this._client);
  final ApiClient _client;

  Future<CurrentUser> updateProfile({
    String? email,
    String? phone,
    String? address,
    String? fullName,
    String? dateOfBirth,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/v1/account/me',
      data: {
        'email': ?email,
        'phone': ?phone,
        'address': ?address,
        'fullName': ?fullName,
        'dateOfBirth': ?dateOfBirth,
      },
    );
    return CurrentUser.fromJson(response.data!);
  }

  Future<CurrentUser> uploadAvatar(List<int> imageBytes) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/v1/account/me/avatar',
      data: {'imageBase64': 'data:image/png;base64,${base64Encode(imageBytes)}'},
    );
    return CurrentUser.fromJson(response.data!);
  }

  Future<CurrentUser> deleteAvatar() async {
    final response = await _client.delete<Map<String, dynamic>>('/v1/account/me/avatar');
    return CurrentUser.fromJson(response.data!);
  }

  Future<CurrentUser> deleteSignature() async {
    final response = await _client.delete<Map<String, dynamic>>('/v1/account/me/signature');
    return CurrentUser.fromJson(response.data!);
  }

  /// URL trực tiếp (kèm header Authorization khi hiển thị) cho ảnh đại diện.
  static String get myAvatarUrl => '${AppConfig.apiBaseUrl}/v1/account/me/avatar';
  static String get mySignatureUrl => '${AppConfig.apiBaseUrl}/v1/account/me/signature';
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});
