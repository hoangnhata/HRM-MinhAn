import '../../../core/utils/user_role.dart';

class LoginResult {
  LoginResult({
    required this.accessToken,
    required this.role,
    required this.userId,
    this.employeeId,
    this.fullName,
    this.email,
    this.mustChangePassword = false,
    this.mustSetSignature = false,
  });

  final String accessToken;
  final UserRole role;
  final int userId;
  final int? employeeId;
  final String? fullName;
  final String? email;
  final bool mustChangePassword;
  final bool mustSetSignature;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      accessToken: json['accessToken'] as String? ?? '',
      role: UserRoleX.fromApi(json['role'] as String?),
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      employeeId: (json['employeeId'] as num?)?.toInt(),
      fullName: json['fullName'] as String?,
      email: json['email'] as String?,
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      mustSetSignature: json['mustSetSignature'] as bool? ?? false,
    );
  }
}
