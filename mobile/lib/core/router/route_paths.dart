/// Hang so duong dan dieu huong — tap trung mot noi de tranh go sai chuoi.
class RoutePaths {
  RoutePaths._();

  static const login = '/login';
  static const changePassword = '/change-password';
  static const signatureSetup = '/signature-setup';

  // Tabs chinh (trong AppShell)
  static const dashboard = '/';
  static const attendance = '/attendance';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const more = '/more';

  // Man hinh day full (khong co bottom nav)
  static const employees = '/employees';
  static const employeeCreate = '/employees/new';
  static const employeeMe = '/employees/me';
  static const employeeDetail = '/employees/:id';
  static const employeeEdit = '/employees/:id/edit';
  static const attendanceRequestNew = '/attendance/requests/new';
  static const attendanceRequestDetail = '/attendance/requests/:id';
  static const attendanceRequests = '/attendance/requests';
  static const attendanceLeaveRequests = '/attendance/leave-requests';
  static const attendanceWorkRequests = '/attendance/work-requests';
  static const attendanceDeploymentRequests = '/attendance/deployments';
  static const attendanceContinuousShift = '/attendance/continuous-shift';
  static const attendanceDepartmentMatrix = '/attendance/department-matrix';
  static const evaluation = '/evaluation';
  static const evaluationDetail = '/evaluation/:id';
  static const evaluationScore = '/evaluation/score/:employeeId';
  static const salary = '/salary';
  static const salaryScales = '/salary/scales';
  static const salaryAdminScales = '/salary/scales/admin';
  static const salaryAdminProfile = '/salary/admin/profile';
  static const salaryGradeReviews = '/salary/admin/grade-reviews';
  static const workforceReports = '/reports/workforce';
  static const departments = '/departments';
  static const profileEdit = '/profile/edit';
  static const profileChangePassword = '/profile/change-password';
  static const profileSignature = '/profile/signature';
  static const requestsHub = '/requests';
  static const requestTypeList = '/requests/:type';
  static const requestCreate = '/requests/:type/new';
  static const requestDetail = '/requests/:type/:id';

  static String employeeDetailPath(int id) => '/employees/$id';
  static const String employeeMePath = '/employees/me';
  static String employeeEditPath(int id) => '/employees/$id/edit';
  static String employeeCreatePath({bool trial = false}) =>
      Uri(
        path: employeeCreate,
        queryParameters: trial ? {'mode': 'trial'} : null,
      ).toString();
  static String attendanceRequestDetailPath(int id) =>
      '/attendance/requests/$id';
  static String attendanceContinuousShiftPath({
    required int employeeId,
    required int year,
    required int month,
    String? name,
  }) {
    return Uri(
      path: attendanceContinuousShift,
      queryParameters: {
        'employeeId': '$employeeId',
        'year': '$year',
        'month': '$month',
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
    ).toString();
  }
  static String evaluationDetailPath(int id) => '/evaluation/$id';
  static String evaluationScorePath({
    required int employeeId,
    required int year,
    required int month,
    String? name,
  }) {
    return Uri(
      path: '/evaluation/score/$employeeId',
      queryParameters: {
        'year': '$year',
        'month': '$month',
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
    ).toString();
  }
  static String workforceReportsPath({bool daily = false}) => daily
      ? '$workforceReports?mode=daily'
      : workforceReports;
  static String requestTypeListPath(String type) => '/requests/$type';
  static String requestDetailPath(String type, int id) =>
      '/requests/$type/$id';
  /// Không truyền [employeeId] → màn chọn nhân viên trước khi lập phiếu.
  static String requestCreatePath(
    String type, {
    int? employeeId,
    int? requestId,
  }) {
    final params = <String, String>{};
    if (employeeId != null) params['employeeId'] = '$employeeId';
    if (requestId != null) params['requestId'] = '$requestId';
    if (params.isEmpty) return '/requests/$type/new';
    return Uri(path: '/requests/$type/new', queryParameters: params).toString();
  }

  /// Danh sách + khoanh đơn đích (từ thông báo) — không mở chi tiết.
  static String withListFocus(
    String path, {
    int? id,
    String? tab,
  }) {
    final params = <String, String>{};
    if (id != null) {
      params['id'] = '$id';
      params['highlight'] = '1';
    }
    if (tab != null && tab.isNotEmpty) {
      params['tab'] = tab;
    }
    if (params.isEmpty) return path;
    return Uri(path: path, queryParameters: params).toString();
  }
}
