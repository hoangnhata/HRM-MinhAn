import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Luu tru an toan token dang nhap va thong tin phien lam viec toi thieu
/// (de khoi phuc session khi mo lai app ma khong can goi /account/me ngay).
class TokenStorage {
  TokenStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'hrm_access_token';
  static const _kRole = 'hrm_role';
  static const _kUserId = 'hrm_user_id';
  static const _kEmployeeId = 'hrm_employee_id';
  static const _kFullName = 'hrm_full_name';

  Future<void> saveSession({
    required String accessToken,
    required String role,
    required int userId,
    int? employeeId,
    String? fullName,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
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
      _storage.delete(key: _kRole),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kEmployeeId),
      _storage.delete(key: _kFullName),
    ]);
  }
}
