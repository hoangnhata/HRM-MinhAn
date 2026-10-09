import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../salary/salary_access_store.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Callback gọi khi phiên thật sự hết (refresh token bị từ chối) để lớp ứng
/// dụng điều hướng về màn đăng nhập.
typedef UnauthorizedCallback = void Function();

/// Kết quả một lần làm mới access token.
enum _RefreshOutcome {
  /// Đã có access token mới trong [TokenStorage].
  refreshed,

  /// Máy chủ từ chối refresh token (đã đăng xuất, bị khoá, hết hạn) → đăng xuất.
  rejected,

  /// Không liên lạc được máy chủ (mất mạng, timeout, 5xx) → giữ phiên, báo lỗi.
  unavailable,
}

/// Bọc Dio + xử lý lỗi tập trung. Đây là điểm duy nhất các repository dùng
/// để gọi HTTP, giúp toàn bộ app có cách xử lý lỗi/timeout/token nhất quán.
class ApiClient {
  ApiClient(this._tokenStorage, {SalaryAccessStore? this._salaryAccess}) {
    AppConfig.debugLogBaseUrl();

    _dio = Dio(
      BaseOptions(
        // Không gắn path /j1-api vào baseUrl của Dio — path tuyệt đối bắt đầu
        // bằng `/` sẽ bị Uri.resolve cắt mất segment. Ta tự ghép URL đầy đủ.
        baseUrl: AppConfig.hostRoot,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: 'application/json',
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Dio riêng cho /auth/refresh: không qua interceptor để không tự gọi lại chính nó.
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: AppConfig.hostRoot,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: 'application/json',
        validateStatus: (status) => status != null,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          final salary = _salaryAccess?.token;
          if (salary != null && salary.isNotEmpty) {
            options.headers[AppConfig.salaryAccessHeader] = salary;
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (response.statusCode != null && response.statusCode! >= 400) {
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              ),
              true,
            );
            return;
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          final options = error.requestOptions;
          if (error.response?.statusCode != 401 || _isAuthPath(options)) {
            handler.next(error);
            return;
          }
          // Đã làm mới mà vẫn 401 → phiên không còn hợp lệ.
          if (options.extra[_kRetried] == true) {
            onUnauthorized?.call();
            handler.next(error);
            return;
          }
          final retried = await _retryWithFreshToken(options);
          if (retried is Response<dynamic>) {
            handler.resolve(retried);
          } else if (retried is DioException) {
            // Lỗi thật của request gửi lại (400, 403…) thay cho 401 cũ.
            handler.next(retried);
          } else {
            handler.next(error);
          }
        },
      ),
    );
  }

  late final Dio _dio;
  late final Dio _refreshDio;
  final TokenStorage _tokenStorage;
  Future<_RefreshOutcome>? _refreshing;

  static const _kRetried = 'hrm_retried_after_refresh';
  final SalaryAccessStore? _salaryAccess;
  UnauthorizedCallback? onUnauthorized;

  Dio get dio => _dio;

  @visibleForTesting
  Dio get refreshDioForTest => _refreshDio;

  bool _isAuthPath(RequestOptions options) =>
      options.uri.path.contains('/j1-api/auth/');

  /// Request bị 401 vì access token hết hạn (8 giờ): lấy token mới bằng refresh
  /// token rồi gửi lại đúng request đó. Trả [Response] khi thành công, [DioException]
  /// của lần gửi lại khi nó lỗi, hoặc `null` nếu không làm mới được.
  Future<Object?> _retryWithFreshToken(RequestOptions options) async {
    final sent = options.headers['Authorization'];
    final current = await _tokenStorage.readToken();
    // Request khác vừa làm mới xong: chỉ cần gửi lại với token mới.
    final alreadyFresh =
        current != null && current.isNotEmpty && sent != 'Bearer $current';
    if (!alreadyFresh) {
      final outcome = await (_refreshing ??= _refreshAccessToken().whenComplete(
        () => _refreshing = null,
      ));
      if (outcome == _RefreshOutcome.rejected) {
        onUnauthorized?.call();
        return null;
      }
      if (outcome == _RefreshOutcome.unavailable) return null;
    }
    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) return null;
    options.headers['Authorization'] = 'Bearer $token';
    options.extra[_kRetried] = true;
    try {
      return await _dio.fetch<dynamic>(options);
    } on DioException catch (e) {
      return e;
    }
  }

  Future<_RefreshOutcome> _refreshAccessToken() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return _RefreshOutcome.rejected;
    }
    try {
      final res = await _refreshDio.postUri<dynamic>(
        Uri.parse(_url('/auth/refresh')),
        data: {'refreshToken': refreshToken},
      );
      final status = res.statusCode ?? 0;
      final data = res.data;
      if (status == 200 && data is Map) {
        final access = data['accessToken'];
        if (access is String && access.isNotEmpty) {
          final nextRefresh = data['refreshToken'];
          await _tokenStorage.saveTokens(
            accessToken: access,
            refreshToken: nextRefresh is String ? nextRefresh : null,
          );
          return _RefreshOutcome.refreshed;
        }
      }
      if (status == 400 || status == 401 || status == 403) {
        return _RefreshOutcome.rejected;
      }
      return _RefreshOutcome.unavailable;
    } on DioException {
      return _RefreshOutcome.unavailable;
    }
  }

  /// Chuẩn hoá path repository (`/auth/login`, `/v1/...`) thành URL đầy đủ
  /// dưới `/j1-api`.
  String _url(String path) => AppConfig.joinApiPath(path);

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
  }) => _guard(
    () => _dio.getUri<T>(
      Uri.parse(_url(path)).replace(queryParameters: _stringifyQuery(query)),
      options: options,
    ),
  );

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) => _guard(
    () => _dio.postUri<T>(
      Uri.parse(_url(path)).replace(queryParameters: _stringifyQuery(query)),
      data: data,
      options: options,
    ),
  );

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) => _guard(
    () => _dio.putUri<T>(
      Uri.parse(_url(path)).replace(queryParameters: _stringifyQuery(query)),
      data: data,
      options: options,
    ),
  );

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) => _guard(
    () => _dio.patchUri<T>(
      Uri.parse(_url(path)).replace(queryParameters: _stringifyQuery(query)),
      data: data,
      options: options,
    ),
  );

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) => _guard(
    () => _dio.deleteUri<T>(
      Uri.parse(_url(path)).replace(queryParameters: _stringifyQuery(query)),
      data: data,
      options: options,
    ),
  );

  Map<String, String>? _stringifyQuery(Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return null;
    return query.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  Future<Response<T>> _guard<T>(Future<Response<T>> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ApiException(
        message: 'Kết nối tới máy chủ quá hạn. Vui lòng kiểm tra mạng.',
      );
    }
    if (e.type == DioExceptionType.connectionError) {
      return ApiException(
        message: 'Không thể kết nối tới máy chủ. Vui lòng thử lại.',
      );
    }

    String message = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
    String? code;
    Map<String, String>? fieldErrors;

    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) message = msg;
      final c = data['code'];
      if (c is String) code = c;
      final fe = data['fieldErrors'];
      if (fe is Map) {
        fieldErrors = fe.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } else if (status == 401) {
      message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    } else if (status == 403) {
      message = 'Bạn không có quyền thực hiện hành động này.';
    } else if (status == 404) {
      message = 'Không tìm thấy dữ liệu.';
    }

    return ApiException(
      message: message,
      statusCode: status,
      code: code,
      fieldErrors: fieldErrors,
    );
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    ref.watch(tokenStorageProvider),
    salaryAccess: ref.read(salaryAccessStoreProvider),
  );
  return client;
});
