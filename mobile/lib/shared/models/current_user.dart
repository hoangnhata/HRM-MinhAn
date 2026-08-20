import '../../core/utils/user_role.dart';

/// Mirror AccountMeResponse (backend) — ho so tai khoan dang nhap hien tai.
class CurrentUser {
  CurrentUser({
    required this.userId,
    required this.username,
    required this.role,
    this.email,
    this.fullName,
    this.employeeId,
    this.enabled = true,
    this.directorApprovalEnabled = false,
    this.reportViewEnabled = false,
    this.workUnitScoped = false,
    this.mustChangePassword = false,
    this.phone,
    this.address,
    this.departmentName,
    this.departmentId,
    this.positionTitle,
    this.workUnitDetail,
    this.erpLinked = false,
    this.dateOfBirth,
    this.userAvatar,
    this.userEnrollNumber,
    this.employeeCode,
    this.hasSignature = false,
    this.hasAvatar = false,
    this.canViewSalary = false,
    this.employeeStatus,
    this.signatureUrl,
  });

  final int userId;
  final String username;
  final UserRole role;
  final String? email;
  final String? fullName;
  final int? employeeId;
  final bool enabled;
  final bool directorApprovalEnabled;
  final bool reportViewEnabled;
  final bool workUnitScoped;
  final bool mustChangePassword;
  final String? phone;
  final String? address;
  final String? departmentName;
  final int? departmentId;
  final String? positionTitle;
  final String? workUnitDetail;
  final bool erpLinked;
  final String? dateOfBirth;
  final String? userAvatar;
  /// Mã chấm công ERP (nếu có) — khác mã nhân viên/CCCD.
  final String? userEnrollNumber;
  /// Mã nhân viên HRM — thường là số CCCD/CMND.
  final String? employeeCode;
  final bool hasSignature;
  final bool hasAvatar;
  final bool canViewSalary;
  final String? employeeStatus;
  final String? signatureUrl;

  String get displayName => (fullName == null || fullName!.isEmpty) ? username : fullName!;

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      role: UserRoleX.fromApi(json['role'] as String?),
      email: json['email'] as String?,
      fullName: json['fullName'] as String?,
      employeeId: (json['employeeId'] as num?)?.toInt(),
      enabled: json['enabled'] as bool? ?? true,
      directorApprovalEnabled: json['directorApprovalEnabled'] as bool? ?? false,
      reportViewEnabled: json['reportViewEnabled'] as bool? ?? false,
      workUnitScoped: json['workUnitScoped'] as bool? ?? false,
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      departmentName: json['departmentName'] as String?,
      departmentId: (json['departmentId'] as num?)?.toInt(),
      positionTitle: json['positionTitle'] as String?,
      workUnitDetail: json['workUnitDetail'] as String?,
      erpLinked: json['erpLinked'] as bool? ?? false,
      dateOfBirth: json['dateOfBirth'] as String?,
      userAvatar: json['userAvatar'] as String?,
      userEnrollNumber: _stringOrNum(json['userEnrollNumber']),
      employeeCode: _emptyToNull(json['employeeCode'] as String?),
      hasSignature: json['hasSignature'] as bool? ?? false,
      hasAvatar: json['hasAvatar'] as bool? ?? false,
      canViewSalary: json['canViewSalary'] as bool? ?? false,
      employeeStatus: json['employeeStatus'] as String?,
      signatureUrl: json['signatureUrl'] as String?,
    );
  }

  static String? _emptyToNull(String? value) {
    final t = value?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  static String? _stringOrNum(Object? value) {
    if (value == null) return null;
    if (value is String) return _emptyToNull(value);
    if (value is num) return value.toString();
    return _emptyToNull(value.toString());
  }
}
