/// Loi API duoc chuan hoa tu response cua backend (GlobalExceptionHandler)
/// de UI hien thi thong bao nhat quan bang tieng Viet.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.fieldErrors,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, String>? fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get mustChangePassword => code == 'MUST_CHANGE_PASSWORD';
  bool get mustSetSignature => code == 'MUST_SET_SIGNATURE';

  @override
  String toString() => message;
}
