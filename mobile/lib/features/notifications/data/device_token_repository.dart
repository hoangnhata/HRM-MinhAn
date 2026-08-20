import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class DeviceTokenRepository {
  DeviceTokenRepository(this._client);
  final ApiClient _client;

  Future<void> register({
    required String token,
    String platform = 'ANDROID',
  }) async {
    await _client.post(
      '/v1/device-tokens',
      data: {'token': token, 'platform': platform},
      options: Options(responseType: ResponseType.plain),
    );
  }

  Future<void> unregister(String token) async {
    await _client.delete(
      '/v1/device-tokens',
      data: {'token': token},
      options: Options(responseType: ResponseType.plain),
    );
  }
}

final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  return DeviceTokenRepository(ref.watch(apiClientProvider));
});
