import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/attendance_enums.dart';
import '../../features/attendance/presentation/attendance_request_detail_screen.dart';
import '../../features/attendance/presentation/attendance_request_form_screen.dart';
import '../../features/attendance/presentation/attendance_requests_screen.dart';
import '../../features/attendance/presentation/continuous_shift_screen.dart';
import '../../features/attendance/presentation/department_attendance_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signature_setup_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/employees/presentation/departments_screen.dart';
import '../../features/employees/presentation/employee_create_screen.dart';
import '../../features/employees/presentation/employee_detail_screen.dart';
import '../../features/employees/presentation/employees_screen.dart';
import '../../features/evaluation/presentation/evaluation_detail_screen.dart';
import '../../features/evaluation/presentation/evaluation_score_form_screen.dart';
import '../../features/evaluation/presentation/evaluation_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_change_password_screen.dart';
import '../../features/profile/presentation/profile_signature_screen.dart';
import '../../features/reports/presentation/workforce_report_screen.dart';
import '../../features/requests/presentation/employee_proposal_create_screen.dart';
import '../../features/requests/presentation/employee_select_for_request_screen.dart';
import '../../features/requests/presentation/main_duty_authorization_create_screen.dart';
import '../../features/requests/presentation/probation_conversion_create_screen.dart';
import '../../features/requests/presentation/request_generic_detail_screen.dart';
import '../../features/requests/presentation/request_type_screen.dart';
import '../../features/requests/presentation/requests_hub_screen.dart';
import '../../features/requests/presentation/young_child_propose_screen.dart';
import '../../features/salary/presentation/admin_salary_profile_screen.dart';
import '../../features/salary/presentation/salary_grade_review_screen.dart';
import '../../features/salary/presentation/salary_scale_screen.dart';
import '../../features/salary/presentation/salary_screen.dart';
import '../../shared/models/employee.dart';
import 'app_shell.dart';
import 'route_paths.dart';

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

final _authRefreshProvider = Provider<_AuthRefreshNotifier>((ref) => _AuthRefreshNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_authRefreshProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      const publicLocations = {'/splash', RoutePaths.login};

      if (auth.status == AuthStatus.bootstrapping) {
        return loc == '/splash' ? null : '/splash';
      }
      if (auth.status == AuthStatus.unauthenticated) {
        return loc == RoutePaths.login ? null : RoutePaths.login;
      }
      if (auth.status == AuthStatus.mustChangePassword) {
        return loc == RoutePaths.changePassword ? null : RoutePaths.changePassword;
      }
      if (auth.status == AuthStatus.mustSetSignature) {
        return loc == RoutePaths.signatureSetup ? null : RoutePaths.signatureSetup;
      }
      // Da dang nhap day du - khong o lai cac man hinh chi danh cho luc chua vao app.
      if (publicLocations.contains(loc) || loc == RoutePaths.changePassword || loc == RoutePaths.signatureSetup) {
        return RoutePaths.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: RoutePaths.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: RoutePaths.changePassword, builder: (context, state) => const ChangePasswordRequiredScreen()),
      GoRoute(path: RoutePaths.signatureSetup, builder: (context, state) => const SignatureSetupScreen()),
      GoRoute(path: RoutePaths.dashboard, builder: (context, state) => const AppShell()),

      GoRoute(path: RoutePaths.employees, builder: (context, state) => const EmployeesScreen()),
      GoRoute(
        path: RoutePaths.employeeCreate,
        builder: (context, state) => EmployeeCreateScreen(
          trialMode: state.uri.queryParameters['mode'] == 'trial',
        ),
      ),
      GoRoute(
        path: RoutePaths.employeeMe,
        builder: (context, state) => const EmployeeDetailScreen(self: true),
      ),
      GoRoute(
        path: RoutePaths.employeeEdit,
        builder: (context, state) => EmployeeCreateScreen(
          editEmployeeId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: RoutePaths.employeeDetail,
        builder: (context, state) => EmployeeDetailScreen(
          employeeId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: RoutePaths.departments, builder: (context, state) => const DepartmentsScreen()),

      GoRoute(
        path: RoutePaths.attendanceRequests,
        builder: (context, state) => AttendanceRequestsScreen(
          scope: AttendanceRequestScope.work,
          highlightRequestId: _highlightId(state),
          initialTab: state.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: RoutePaths.attendanceLeaveRequests,
        builder: (context, state) => AttendanceRequestsScreen(
          scope: AttendanceRequestScope.leave,
          highlightRequestId: _highlightId(state),
          initialTab: state.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: RoutePaths.attendanceWorkRequests,
        builder: (context, state) => AttendanceRequestsScreen(
          scope: AttendanceRequestScope.work,
          highlightRequestId: _highlightId(state),
          initialTab: state.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: RoutePaths.attendanceDeploymentRequests,
        builder: (context, state) => AttendanceRequestsScreen(
          scope: AttendanceRequestScope.deployment,
          highlightRequestId: _highlightId(state),
          initialTab: state.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: RoutePaths.attendanceRequestNew,
        builder: (context, state) {
          final extra = state.extra;
          return AttendanceRequestFormScreen(
            prefill: extra is AttendanceRequestPrefill ? extra : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.attendanceRequestDetail,
        builder: (context, state) => AttendanceRequestDetailScreen(
          requestId: int.parse(state.pathParameters['id']!),
          highlight: state.uri.queryParameters['highlight'] == '1',
        ),
      ),
      GoRoute(
        path: RoutePaths.attendanceContinuousShift,
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final employeeId = int.tryParse(q['employeeId'] ?? '') ?? 0;
          final year =
              int.tryParse(q['year'] ?? '') ?? DateTime.now().year;
          final month =
              int.tryParse(q['month'] ?? '') ?? DateTime.now().month;
          return ContinuousShiftScreen(
            employeeId: employeeId,
            year: year,
            month: month,
            employeeName: q['name'],
          );
        },
      ),
      GoRoute(
        path: RoutePaths.attendanceDepartmentMatrix,
        builder: (context, state) {
          final extra = state.extra;
          int? year;
          int? month;
          if (extra is Map) {
            year = extra['year'] as int?;
            month = extra['month'] as int?;
          }
          return DepartmentAttendanceScreen(
            initialYear: year,
            initialMonth: month,
          );
        },
      ),

      GoRoute(
        path: RoutePaths.evaluation,
        builder: (context, state) => EvaluationScreen(
          highlightEvaluationId: _highlightId(state),
          initialMode: state.uri.queryParameters['mode'],
        ),
      ),
      GoRoute(
        path: RoutePaths.evaluationScore,
        builder: (context, state) {
          final year = int.tryParse(state.uri.queryParameters['year'] ?? '') ??
              DateTime.now().year;
          final month = int.tryParse(state.uri.queryParameters['month'] ?? '') ??
              DateTime.now().month;
          return EvaluationScoreFormScreen(
            employeeId: int.parse(state.pathParameters['employeeId']!),
            year: year,
            month: month,
            employeeName: state.uri.queryParameters['name'],
          );
        },
      ),
      GoRoute(
        path: RoutePaths.evaluationDetail,
        builder: (context, state) => EvaluationDetailScreen(
          evaluationId: int.parse(state.pathParameters['id']!),
          highlight: state.uri.queryParameters['highlight'] == '1',
        ),
      ),

      GoRoute(path: RoutePaths.salary, builder: (context, state) => const SalaryScreen()),
      GoRoute(
        path: RoutePaths.salaryScales,
        builder: (context, state) => const SalaryScaleScreen(),
      ),
      GoRoute(
        path: RoutePaths.salaryAdminScales,
        builder: (context, state) => const SalaryScaleScreen(admin: true),
      ),
      GoRoute(
        path: RoutePaths.salaryAdminProfile,
        builder: (context, state) {
          final extra = state.extra;
          return AdminSalaryProfileScreen(
            initialEmployee: extra is EmployeeSummary ? extra : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.salaryGradeReviews,
        builder: (context, state) => const SalaryGradeReviewScreen(),
      ),
      GoRoute(
        path: RoutePaths.workforceReports,
        builder: (context, state) => WorkforceReportScreen(
          initialDaily: state.uri.queryParameters['mode'] == 'daily',
        ),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),

      GoRoute(path: RoutePaths.profileEdit, builder: (context, state) => const EditProfileScreen()),
      GoRoute(path: RoutePaths.profileChangePassword, builder: (context, state) => const ProfileChangePasswordScreen()),
      GoRoute(path: RoutePaths.profileSignature, builder: (context, state) => const ProfileSignatureScreen()),

      GoRoute(path: RoutePaths.requestsHub, builder: (context, state) => const RequestsHubScreen()),
      GoRoute(
        path: RoutePaths.requestCreate,
        builder: (context, state) {
          final typeKey = state.pathParameters['type']!;
          final q = state.uri.queryParameters;
          final employeeId = int.tryParse(q['employeeId'] ?? '');
          final requestId = int.tryParse(q['requestId'] ?? '');
          if (employeeId == null) {
            return EmployeeSelectForRequestScreen(typeKey: typeKey);
          }
          if (typeKey == 'young-child') {
            return YoungChildProposeScreen(
              employeeId: employeeId,
              requestId: requestId,
            );
          }
          if (typeKey == 'probation-conversion') {
            return ProbationConversionCreateScreen(
              employeeId: employeeId,
              requestId: requestId,
            );
          }
          if (typeKey == 'main-duty-authorization') {
            return MainDutyAuthorizationCreateScreen(
              employeeId: employeeId,
              requestId: requestId,
            );
          }
          return EmployeeProposalCreateScreen(
            typeKey: typeKey,
            employeeId: employeeId,
            requestId: requestId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.requestTypeList,
        builder: (context, state) => RequestTypeScreen(
          typeKey: state.pathParameters['type']!,
          highlightRequestId: _highlightId(state),
          initialTab: state.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: RoutePaths.requestDetail,
        builder: (context, state) => RequestGenericDetailScreen(
          typeKey: state.pathParameters['type']!,
          requestId: int.parse(state.pathParameters['id']!),
          highlight: state.uri.queryParameters['highlight'] == '1',
        ),
      ),
    ],
  );
});

int? _highlightId(GoRouterState state) {
  if (state.uri.queryParameters['highlight'] != '1') return null;
  return int.tryParse(state.uri.queryParameters['id'] ?? '');
}