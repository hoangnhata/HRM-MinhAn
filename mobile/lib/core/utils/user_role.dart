/// Vai trò người dùng — khớp backend `UserRole` và web `roleAccess.ts`.
enum UserRole {
  admin,
  employee,
  hr,
  hr2,
  headDepartment,
  /// Trưởng phòng HCNS: vừa HEAD_DEPARTMENT vừa HR2 (web `roleAllows`).
  headHr,
  headNursing,
  director,
  unknown,
}

extension UserRoleX on UserRole {
  static UserRole fromApi(String? raw) {
    switch (raw) {
      case 'ADMIN':
        return UserRole.admin;
      case 'EMPLOYEE':
        return UserRole.employee;
      case 'HR':
        return UserRole.hr;
      case 'HR2':
        return UserRole.hr2;
      case 'HEAD_DEPARTMENT':
        return UserRole.headDepartment;
      case 'HEAD_HR':
        return UserRole.headHr;
      case 'HEAD_NURSING':
        return UserRole.headNursing;
      case 'DIRECTOR':
        return UserRole.director;
      default:
        return UserRole.unknown;
    }
  }

  String get apiValue {
    switch (this) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.employee:
        return 'EMPLOYEE';
      case UserRole.hr:
        return 'HR';
      case UserRole.hr2:
        return 'HR2';
      case UserRole.headDepartment:
        return 'HEAD_DEPARTMENT';
      case UserRole.headHr:
        return 'HEAD_HR';
      case UserRole.headNursing:
        return 'HEAD_NURSING';
      case UserRole.director:
        return 'DIRECTOR';
      case UserRole.unknown:
        return '';
    }
  }

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Quản trị viên';
      case UserRole.employee:
        return 'Nhân viên';
      case UserRole.hr:
        return 'Hành chính - Nhân sự';
      case UserRole.hr2:
        return 'HCNS (duyệt đơn)';
      case UserRole.headDepartment:
        return 'Trưởng khoa/phòng';
      case UserRole.headHr:
        return 'Trưởng phòng HCNS';
      case UserRole.headNursing:
        return 'Trưởng phòng Điều dưỡng';
      case UserRole.director:
        return 'Giám đốc';
      case UserRole.unknown:
        return 'Không xác định';
    }
  }
}

/// Nhóm quyền hiển thị menu/hành động — mirror MainLayout + roleAccess web.
class RoleGroups {
  RoleGroups._();

  static const allStaff = {
    UserRole.admin,
    UserRole.employee,
    UserRole.hr,
    UserRole.hr2,
    UserRole.headDepartment,
    UserRole.headHr,
    UserRole.headNursing,
    UserRole.director,
  };

  static const adminHrHeads = {
    UserRole.admin,
    UserRole.hr,
    UserRole.headDepartment,
    UserRole.headHr,
    UserRole.headNursing,
  };

  static const workManagers = {
    UserRole.admin,
    UserRole.hr,
    UserRole.hr2,
    UserRole.headDepartment,
    UserRole.headHr,
    UserRole.headNursing,
  };

  static const salaryManagers = {UserRole.admin, UserRole.hr};

  /// Xem danh sách NV theo role (API còn cho HOSPITAL_EMPLOYEE_VIEWER qua flag).
  static const employeeDirectory = {
    UserRole.admin,
    UserRole.hr,
    UserRole.hr2,
    UserRole.headDepartment,
    UserRole.headHr,
    UserRole.headNursing,
    UserRole.director,
  };

  /// Duyệt đơn công/nghỉ (không gồm GĐ — GĐ chỉ khi bật directorApprovalEnabled).
  static const approvalManagers = {
    UserRole.admin,
    UserRole.hr,
    UserRole.hr2,
    UserRole.headDepartment,
    UserRole.headHr,
    UserRole.headNursing,
  };

  static const reportViewers = {
    UserRole.admin,
    UserRole.hr,
    UserRole.hr2,
    UserRole.headHr,
    UserRole.director,
  };

  static const professionalQualificationViewers = {
    UserRole.admin,
    UserRole.hr,
    UserRole.hr2,
    UserRole.headHr,
    UserRole.director,
  };

  static const nursingEvalScorers = {
    UserRole.admin,
    UserRole.headDepartment,
    UserRole.headHr,
  };

  static const nursingEvalApprovers = {
    UserRole.admin,
    UserRole.hr2,
    UserRole.headHr,
    UserRole.headNursing,
  };

  static const nursingEvalSummaryViewers = {
    UserRole.admin,
    UserRole.hr,
    UserRole.hr2,
    UserRole.headHr,
    UserRole.headNursing,
  };

  /// Khớp web `roleAllows`: HEAD_HR = HEAD_DEPARTMENT ∪ HR2.
  static bool roleAllows(UserRole userRole, UserRole allowed) {
    if (userRole == allowed) return true;
    if (userRole == UserRole.headHr) {
      return allowed == UserRole.headDepartment || allowed == UserRole.hr2;
    }
    return false;
  }

  static bool roleAllowsAny(UserRole userRole, Set<UserRole> allowed) =>
      allowed.any((r) => roleAllows(userRole, r));

  static bool isIn(UserRole role, Set<UserRole> group) =>
      roleAllowsAny(role, group);

  static bool isHeadDepartmentRole(UserRole role) =>
      role == UserRole.headDepartment || role == UserRole.headHr;

  static bool isHr2Role(UserRole role) =>
      role == UserRole.hr2 || role == UserRole.headHr;

  /// Giống web: ADMIN, DIRECTOR (khi bật flag), hoặc bất kỳ role nào có flag.
  static bool canActAsDirectorApprover(
    UserRole role, {
    required bool directorApprovalEnabled,
  }) {
    if (role == UserRole.admin) return true;
    return directorApprovalEnabled;
  }

  /// Giám đốc tắt quyền duyệt → UI như nhân viên (web RequestsPage).
  static bool isEmployeeLike(
    UserRole role, {
    required bool directorApprovalEnabled,
  }) {
    return role == UserRole.employee ||
        (role == UserRole.director && !directorApprovalEnabled);
  }

  /// Duyệt đơn công / nghỉ / điều động.
  static bool canApproveAttendance(
    UserRole role, {
    required bool directorApprovalEnabled,
  }) {
    if (isIn(role, approvalManagers)) return true;
    return canActAsDirectorApprover(
      role,
      directorApprovalEnabled: directorApprovalEnabled,
    );
  }

  static bool canViewEmployeeDirectory(
    UserRole role, {
    bool hospitalWideEmployeeViewEnabled = false,
  }) =>
      isIn(role, employeeDirectory) || hospitalWideEmployeeViewEnabled;

  static bool canViewWorkforceReports(
    UserRole role, {
    bool reportViewEnabled = false,
  }) =>
      isIn(role, reportViewers) || reportViewEnabled;

  static bool canViewProfessionalQualificationReport(
    UserRole role, {
    bool professionalQualificationReportEnabled = false,
  }) =>
      isIn(role, professionalQualificationViewers) ||
      professionalQualificationReportEnabled;

  static bool canViewNursingAnalytics(UserRole role) =>
      role == UserRole.admin ||
      role == UserRole.headNursing ||
      isHeadDepartmentRole(role);

  static bool canEnterNursingDailyReports(UserRole role) =>
      role == UserRole.admin ||
      role == UserRole.headNursing ||
      isHeadDepartmentRole(role);

  static bool canEnterQtkt(UserRole role) =>
      role == UserRole.admin ||
      role == UserRole.headNursing ||
      isHeadDepartmentRole(role);

  static bool canScoreQtkt(UserRole role) =>
      role == UserRole.admin || isHeadDepartmentRole(role);

  static bool canScoreNursingEval(UserRole role) =>
      isIn(role, nursingEvalScorers);

  static bool canApproveNursingEval(
    UserRole role, {
    bool directorApprovalEnabled = false,
  }) {
    if (role == UserRole.director) return directorApprovalEnabled;
    if (isIn(role, nursingEvalApprovers)) return true;
    return directorApprovalEnabled;
  }

  static bool canViewNursingEvalSummary(
    UserRole role, {
    bool directorApprovalEnabled = false,
  }) {
    if (role == UserRole.director) return directorApprovalEnabled;
    if (isIn(role, nursingEvalSummaryViewers)) return true;
    return directorApprovalEnabled;
  }
}
