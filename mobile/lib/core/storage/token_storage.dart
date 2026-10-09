import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Luu tru an toan token dang nhap va thong tin phien lam viec toi thieu
/// (de khoi phuc session khi mo lai app ma khong can goi /account/me ngay).
class TokenStorage {
  TokenStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'hrm_access_token';
  static const _kRefreshToken = 'hrm_refresh_token';
  static const _kRole = 'hrm_role';
  static const _kUserId = 'hrm_user_id';
  static const _kEmployeeId = 'hrm_employee_id';
  static const _kFullName = 'hrm_full_name';

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    required String role,
    required int userId,
    int? employeeId,
    String? fullName,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      if (refreshToken != null && refreshToken.isNotEmpty)
        _storage.write(key: _kRefreshToken, value: refreshToken),
      _storage.write(key: _kRole, value: role),
      _storage.write(key: _kUserId, value: userId.toString()),
      if (employeeId != null)
        _storage.write(key: _kEmployeeId, value: employeeId.toString())
      else
        _storage.delete(key: _kEmployeeId),
      _storage.write(key: _kFullName, value: fullName ?? ''),
    ]);
  }

  Future<String?> readToken() => _storage.read(key: _kAccessToken);

  /// Refresh token giữ phiên dài hạn — dùng để lấy access token mới khi hết 8 giờ.
  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshToken);

  /// Lưu cặp token mới sau khi làm mới phiên (thông tin hồ sơ giữ nguyên).
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      if (refreshToken != null && refreshToken.isNotEmpty)
        _storage.write(key: _kRefreshToken, value: refreshToken),
    ]);
  }

  Future<String?> readRole() => _storage.read(key: _kRole);

  Future<int?> readEmployeeId() async {
    final raw = await _storage.read(key: _kEmployeeId);
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<int?> readUserId() async {
    final raw = await _storage.read(key: _kUserId);
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<String?> readFullName() => _storage.read(key: _kFullName);

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kRole),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kEmployeeId),
      _storage.delete(key: _kFullName),
    ]);
  }
}
