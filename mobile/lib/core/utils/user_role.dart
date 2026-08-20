/// Vai tro nguoi dung — khop chinh xac voi backend UserRole enum va cach
/// dat ten trong frontend/src/layouts/MainLayout.tsx.
enum UserRole {
  admin,
  employee,
  hr,
  hr2,
  headDepartment,
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
      case UserRole.headNursing:
        return 'Trưởng phòng Điều dưỡng';
      case UserRole.director:
        return 'Giám đốc';
      case UserRole.unknown:
        return 'Không xác định';
    }
  }
}

/// Cac nhom vai tro dung de gan quyen hien thi menu/hanh dong — mirror
/// ALL_STAFF / WORK_MANAGERS / ... trong MainLayout.tsx (web).
class RoleGroups {
  RoleGroups._();

  static const allStaff = {
    UserRole.admin,
    UserRole.employee,
    UserRole.hr,
    UserRole.hr2,
    UserRole.headDepartment,
    UserRole.headNursing,
    UserRole.director,
  };

  static const adminHrHeads = {
    UserRole.admin,
    UserRole.hr,
    UserRole.headDepartment,
    UserRole.headNursing,
  };

  static const workManagers = {
    UserRole.admin,
    UserRole.hr,
    UserRole.hr2,
    UserRole.headDepartment,
    UserRole.headNursing,
  };

  static const salaryManagers = {UserRole.admin, UserRole.hr};

  /// Xem danh sách nhân viên (khớp EmployeeController list roles).
  static const employeeDirectory = {
    UserRole.admin,
    UserRole.hr,
    UserRole.hr2,
    UserRole.headDepartment,
    UserRole.headNursing,
    UserRole.director,
  };

  static const approvalManagers = {
    UserRole.admin,
    UserRole.hr,
    UserRole.hr2,
    UserRole.headDepartment,
    UserRole.headNursing,
    UserRole.director,
  };

  /// Xem báo cáo nhân lực — khớp web `REPORT_VIEWERS` + `reportViewEnabled`.
  static const reportViewers = {
    UserRole.admin,
    UserRole.hr,
    UserRole.hr2,
    UserRole.director,
  };

  static bool canViewWorkforceReports(
    UserRole role, {
    bool reportViewEnabled = false,
  }) =>
      reportViewers.contains(role) || reportViewEnabled;

  /// Lập / chấm phiếu đánh giá khối ĐD — khớp web HEAD_DEPARTMENT | ADMIN.
  static const nursingEvalScorers = {
    UserRole.admin,
    UserRole.headDepartment,
  };

  /// Duyệt phiếu đánh giá — khớp GET /pending roles.
  static const nursingEvalApprovers = {
    UserRole.admin,
    UserRole.hr2,
    UserRole.headNursing,
    UserRole.director,
  };

  /// Tổng hợp xếp loại tháng — khớp GET /summary roles.
  static const nursingEvalSummaryViewers = {
    UserRole.admin,
    UserRole.hr,
    UserRole.hr2,
    UserRole.headNursing,
    UserRole.director,
  };

  static bool canScoreNursingEval(UserRole role) =>
      nursingEvalScorers.contains(role);

  static bool canApproveNursingEval(
    UserRole role, {
    bool directorApprovalEnabled = false,
  }) =>
      nursingEvalApprovers.contains(role) || directorApprovalEnabled;

  static bool canViewNursingEvalSummary(
    UserRole role, {
    bool directorApprovalEnabled = false,
  }) =>
      nursingEvalSummaryViewers.contains(role) || directorApprovalEnabled;

  static bool isIn(UserRole role, Set<UserRole> group) => group.contains(role);
}
