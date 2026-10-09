import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_mobile/core/network/api_client.dart';
import 'package:hrm_mobile/core/network/api_exception.dart';
import 'package:hrm_mobile/core/storage/token_storage.dart';

/// TokenStorage trong bộ nhớ (không đụng secure storage của máy).
class _MemoryTokenStorage extends TokenStorage {
  String? access;
  String? refresh;

  @override
  Future<String?> readToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    access = accessToken;
    if (refreshToken != null) refresh = refreshToken;
  }
}

/// Máy chủ giả: API chỉ nhận access token "fresh"; /auth/refresh trả token mới
/// hoặc từ chối / mất mạng tuỳ [refreshMode].
class _FakeServer implements HttpClientAdapter {
  String refreshMode = 'ok'; // ok | reject | offline
  int refreshCalls = 0;
  int apiCalls = 0;

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.endsWith('/auth/refresh')) {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (refreshMode == 'offline') {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        );
      }
      if (refreshMode == 'reject') {
        return _json(401, {'message': 'Phiên đăng nhập đã hết hạn'});
      }
      return _json(200, {'accessToken': 'fresh', 'refreshToken': 'r1'});
    }
    apiCalls++;
    if (options.headers['Authorization'] == 'Bearer fresh') {
      return _json(200, {'ok': true});
    }
    return _json(401, {'message': 'Unauthorized'});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _MemoryTokenStorage storage;
  late _FakeServer server;
  late ApiClient client;
  late int unauthorizedCalls;

  setUp(() {
    storage = _MemoryTokenStorage()
      ..access = 'expired'
      ..refresh = 'r1';
    server = _FakeServer();
    client = ApiClient(storage);
    client.dio.httpClientAdapter = server;
    client.refreshDioForTest.httpClientAdapter = server;
    unauthorizedCalls = 0;
    client.onUnauthorized = () => unauthorizedCalls++;
  });

  test('access token hết hạn → tự làm mới rồi gửi lại, không đăng xuất', () async {
    final res = await client.get<Map<String, dynamic>>('/v1/account/me');

    expect(res.data, {'ok': true});
    expect(storage.access, 'fresh');
    expect(server.refreshCalls, 1);
    expect(unauthorizedCalls, 0);
  });

  test('refresh token bị từ chối → đăng xuất', () async {
    server.refreshMode = 'reject';

    await expectLater(
      client.get<Map<String, dynamic>>('/v1/account/me'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(unauthorizedCalls, 1);
  });

  test('mất mạng lúc làm mới → giữ phiên, không đăng xuất', () async {
    server.refreshMode = 'offline';

    await expectLater(
      client.get<Map<String, dynamic>>('/v1/account/me'),
      throwsA(isA<ApiException>()),
    );
    expect(unauthorizedCalls, 0);
    expect(storage.refresh, 'r1');
  });

  test('nhiều request cùng hết hạn → chỉ làm mới một lần', () async {
    final results = await Future.wait([
      for (var i = 0; i < 4; i++)
        client.get<Map<String, dynamic>>('/v1/notifications'),
    ]);

    expect(results.every((r) => r.data?['ok'] == true), isTrue);
    expect(server.refreshCalls, 1);
    expect(unauthorizedCalls, 0);
  });

  test('chưa có refresh token (bản cũ) → đăng xuất như trước', () async {
    storage.refresh = null;

    await expectLater(
      client.get<Map<String, dynamic>>('/v1/account/me'),
      throwsA(isA<ApiException>()),
    );
    expect(unauthorizedCalls, 1);
    expect(server.refreshCalls, 0);
  });
}
