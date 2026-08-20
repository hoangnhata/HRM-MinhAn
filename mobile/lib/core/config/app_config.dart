import 'package:flutter/foundation.dart';

/// Cấu hình môi trường cho ứng dụng.
///
/// Mặc định trỏ tới backend production đã deploy.
/// Override khi chạy local:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/j1-api
///   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080/j1-api
class AppConfig {
  AppConfig._();

  /// Backend production (đồng bộ với web: erp.benhvienminhan.com).
  static const String productionApiBaseUrl =
      'https://erp.benhvienminhan.com/j1-api';

  /// Gốc API backend (không có dấu / cuối).
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return _trimTrailingSlash(override);
    return productionApiBaseUrl;
  }

  /// Gốc máy chủ (không có /j1-api) — dùng ghép đường dẫn tuyệt đối
  /// trả về từ backend (vd chữ ký: "/j1-api/v1/approval-signatures/...").
  static String get hostRoot {
    final api = apiBaseUrl;
    final idx = api.indexOf('/j1-api');
    if (idx > 0) return api.substring(0, idx);
    return api;
  }

  /// Ghép đường dẫn backend thành URL gọi được.
  static String resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '$hostRoot$path';
    return '$hostRoot/$path';
  }

  /// Ghép path API tương đối (vd `/auth/login`, `v1/account/me`) với [apiBaseUrl].
  /// Tránh lỗi Dio/Uri.resolve khi path bắt đầu bằng `/` làm mất segment `/j1-api`.
  static String joinApiPath(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = apiBaseUrl;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$base$normalized';
  }

  static String _trimTrailingSlash(String value) {
    if (value.length > 1 && value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  static const String appName = 'HRM Minh An';
  static const String appVersion = '0.1.0';
  static const String appBuildNumber = '1';
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Header dùng khi HR/Admin mở khoá xem lương nhạy cảm.
  static const String salaryAccessHeader = 'X-Salary-Access-Token';

  /// Debug: in ra URL đang dùng (chỉ khi debug).
  static void debugLogBaseUrl() {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[HRM] API_BASE_URL = $apiBaseUrl');
    }
  }
}
