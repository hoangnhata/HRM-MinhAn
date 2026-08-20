import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../salary/salary_access_store.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Callback gọi khi phát hiện 401 (token hết hạn/không hợp lệ) để lớp ứng
/// dụng điều hướng về màn đăng nhập.
typedef UnauthorizedCallback = void Function();

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
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final TokenStorage _tokenStorage;
  final SalaryAccessStore? _salaryAccess;
  UnauthorizedCallback? onUnauthorized;

  Dio get dio => _dio;

  /// Chuẩn hoá path repository (`/auth/login`, `/v1/...`) thành URL đầy đủ
  /// dưới `/j1-api`.
  String _url(String path) => AppConfig.joinApiPath(path);

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
  }) =>
      _guard(() => _dio.getUri<T>(
            Uri.parse(_url(path)).replace(queryParameters: _stringifyQuery(query)),
            options: options,
          ));

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) =>
      _guard(() => _dio.postUri<T>(
            Uri.parse(_url(path)).replace(queryParameters: _stringifyQuery(query)),
            data: data,
            options: options,
          ));

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) =>
      _guard(() => _dio.putUri<T>(
            Uri.parse(_url(path)).replace(queryParameters: _stringifyQuery(query)),
            data: data,
            options: options,
          ));

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) =>
      _guard(() => _dio.patchUri<T>(
            Uri.parse(_url(path)).replace(queryParameters: _stringifyQuery(query)),
            data: data,
            options: options,
          ));

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) =>
      _guard(() => _dio.deleteUri<T>(
            Uri.parse(_url(path)).replace(queryParameters: _stringifyQuery(query)),
            data: data,
            options: options,
          ));

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
