import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Token mở khóa phần lương ADMIN/HCNS 1 — cùng header web `X-Salary-Access-Token`.
/// Giữ trong bộ nhớ phiên (giống sessionStorage trên web).
class SalaryAccessStore extends ChangeNotifier {
  String? _token;
  DateTime? _expiresAt;

  bool get isUnlocked => token != null;

  String? get token {
    final value = _token;
    final exp = _expiresAt;
    if (value == null || value.isEmpty || exp == null) return null;
    if (!exp.isAfter(DateTime.now())) return null;
    return value;
  }

  void setGrant({required String token, required DateTime expiresAt}) {
    _token = token;
    _expiresAt = expiresAt;
    notifyListeners();
  }

  void clear() {
    if (_token == null && _expiresAt == null) return;
    _token = null;
    _expiresAt = null;
    notifyListeners();
  }
}

final salaryAccessStoreProvider =
    ChangeNotifierProvider<SalaryAccessStore>((ref) => SalaryAccessStore());
