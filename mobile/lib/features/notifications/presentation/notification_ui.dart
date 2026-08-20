import 'package:flutter/material.dart';

import '../../../core/router/app_shell.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';

/// Đích điều hướng của một thông báo: hoặc là tab trong AppShell, hoặc là một
/// route đầy đủ. Tách rõ hai loại vì tab không phải route của go_router.
class NotificationTarget {
  const NotificationTarget.tab(this.tab) : route = null;
  const NotificationTarget.route(this.route) : tab = null;

  final AppShellTab? tab;
  final String? route;

  @Deprecated('Dùng [tab]')
  int? get tabIndex => tab?.index;
}

/// Icon + màu theo NotificationCategory (backend) — đồng bộ tinh thần với
/// NotificationPopover bên web.
class NotificationUi {
  NotificationUi._();

  static IconData iconFor(String category, {String? title}) {
    final t = title ?? '';
    if (category == 'ATTENDANCE') {
      if (_containsAny(t, const ['điều động', 'Dieu dong', 'Điều động'])) {
        return Icons.swap_horiz_rounded;
      }
      if (_containsAny(t, const ['nghỉ phép', 'không lương', 'Nghỉ phép'])) {
        return Icons.beach_access_rounded;
      }
      if (_containsAny(t, const ['đơn công', 'cập nhật công', 'Đơn công'])) {
        return Icons.assignment_outlined;
      }
      return Icons.event_note_rounded;
    }
    switch (category) {
      case 'SALARY_REVIEW':
      case 'SALARY_ADJUSTMENT':
      case 'PAYROLL':
        return Icons.payments_rounded;
      case 'DEPARTMENT_TRANSFER':
        return Icons.compare_arrows_rounded;
      case 'PROBATION_CONVERSION':
        return Icons.how_to_reg_rounded;
      case 'YOUNG_CHILD':
        return Icons.child_care_rounded;
      case 'TRAINING_PROPOSAL':
        return Icons.school_rounded;
      case 'SEMINAR_PROPOSAL':
        return Icons.groups_rounded;
      case 'MAIN_DUTY_AUTHORIZATION':
        return Icons.verified_user_rounded;
      case 'SHIFT_CONFIG_CHANGE':
        return Icons.schedule_rounded;
      case 'NURSING_EVALUATION':
        return Icons.fact_check_rounded;
      case 'ANNOUNCEMENT':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  static Color colorFor(String category, {String? title}) {
    final t = title ?? '';
    if (category == 'ATTENDANCE') {
      if (_containsAny(t, const ['điều động', 'Điều động'])) {
        return const Color(0xFF0F766E);
      }
      if (_containsAny(t, const ['nghỉ phép', 'không lương', 'Nghỉ phép'])) {
        return AppColors.success;
      }
      return AppColors.warning;
    }
    switch (category) {
      case 'PAYROLL':
      case 'SALARY_ADJUSTMENT':
      case 'SALARY_REVIEW':
        return AppColors.secondaryDark;
      case 'SHIFT_CONFIG_CHANGE':
        return const Color(0xFF5C6BC0);
      case 'DEPARTMENT_TRANSFER':
        return const Color(0xFF0369A1);
      case 'PROBATION_CONVERSION':
      case 'MAIN_DUTY_AUTHORIZATION':
        return AppColors.info;
      case 'YOUNG_CHILD':
        return const Color(0xFFBE185D);
      case 'TRAINING_PROPOSAL':
      case 'SEMINAR_PROPOSAL':
        return const Color(0xFF7C3AED);
      case 'NURSING_EVALUATION':
        return AppColors.primary;
      case 'ANNOUNCEMENT':
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  static bool _containsAny(String source, List<String> needles) {
    final lower = source.toLowerCase();
    return needles.any((n) => lower.contains(n.toLowerCase()));
  }

  /// Nhãn tiếng Việt của nhóm thông báo — dùng làm chip phân loại.
  static String labelFor(String category, {String? title}) {
    final t = title ?? '';
    if (category == 'ATTENDANCE') {
      if (_containsAny(t, const ['điều động', 'Điều động'])) return 'Điều động';
      if (_containsAny(t, const ['nghỉ phép', 'không lương', 'Nghỉ phép'])) {
        return 'Nghỉ phép';
      }
      return 'Công';
    }
    switch (category) {
      case 'SALARY_REVIEW':
        return 'Xét lương';
      case 'SALARY_ADJUSTMENT':
        return 'Điều chỉnh lương';
      case 'PAYROLL':
        return 'Bảng lương';
      case 'DEPARTMENT_TRANSFER':
        return 'Luân chuyển';
      case 'PROBATION_CONVERSION':
        return 'Chính thức';
      case 'YOUNG_CHILD':
        return 'Nuôi con nhỏ';
      case 'TRAINING_PROPOSAL':
        return 'Đào tạo';
      case 'SEMINAR_PROPOSAL':
        return 'Hội thảo';
      case 'MAIN_DUTY_AUTHORIZATION':
        return 'Trực chính';
      case 'SHIFT_CONFIG_CHANGE':
        return 'Giờ ca';
      case 'NURSING_EVALUATION':
        return 'Đánh giá';
      case 'ANNOUNCEMENT':
        return 'Thông báo';
      default:
        return 'Khác';
    }
  }

  /// Quy đổi actionPath trả về từ backend (dạng route web) sang đích mobile.
  /// Khi có ID đơn: mở **danh sách** và khoanh card (không vào chi tiết).
  static NotificationTarget resolveTarget(
    String? actionPath, {
    String? category,
    int? relatedRequestId,
    String? title,
  }) {
    final uri = actionPath == null || actionPath.trim().isEmpty
        ? null
        : Uri.tryParse(actionPath.trim());
    final path = uri?.path ?? '';
    final openId = int.tryParse(uri?.queryParameters['open'] ?? '');
    final queryId = int.tryParse(uri?.queryParameters['id'] ?? '');
    final id = openId ?? queryId ?? relatedRequestId;
    // `open` = luồng duyệt → tab Chờ duyệt; `id` = đơn của tôi.
    final listTab = openId != null
        ? 'approve'
        : (queryId != null ? 'mine' : null);

    if (path == '/' || path.isEmpty) {
      return _fallbackForCategory(category, relatedRequestId, title);
    }
    if (path.startsWith('/work')) {
      return NotificationTarget.route(
        RoutePaths.withListFocus(
          _attendanceListBase(title, null),
          id: id,
          tab: id != null ? 'mine' : null,
        ),
      );
    }
    if (path.startsWith('/requests')) {
      final tab = uri?.queryParameters['tab'];
      final typeKey = _requestTypeForWebTab(tab);
      if (typeKey != null) {
        return NotificationTarget.route(
          RoutePaths.withListFocus(
            RoutePaths.requestTypeListPath(typeKey),
            id: id,
            tab: listTab ?? (id != null ? 'approve' : null),
          ),
        );
      }
      if (tab == 'deployments' || tab == 'mine' || tab == 'approve') {
        return NotificationTarget.route(
          RoutePaths.withListFocus(
            _attendanceListBase(title, tab),
            id: id,
            tab: tab,
          ),
        );
      }
      return const NotificationTarget.tab(AppShellTab.requests);
    }
    if (path.startsWith('/evaluations')) {
      return NotificationTarget.route(
        RoutePaths.withListFocus(RoutePaths.evaluation, id: id),
      );
    }
    if (path.startsWith('/salary')) {
      return const NotificationTarget.tab(AppShellTab.salary);
    }
    if (path.startsWith('/employees')) {
      return const NotificationTarget.route(RoutePaths.employees);
    }
    if (path.startsWith('/departments')) {
      return const NotificationTarget.route(RoutePaths.departments);
    }
    if (path.startsWith('/profile')) {
      return const NotificationTarget.tab(AppShellTab.profile);
    }
    return _fallbackForCategory(category, relatedRequestId, title);
  }

  /// Resolve từ payload FCM data map.
  static NotificationTarget resolveFromPushData(Map<String, dynamic> data) {
    final actionPath = data['actionPath']?.toString();
    final category = data['category']?.toString();
    final title = data['title']?.toString();
    final relatedRequestId = int.tryParse(
      data['relatedRequestId']?.toString() ?? '',
    );
    return resolveTarget(
      actionPath,
      category: category,
      relatedRequestId: relatedRequestId,
      title: title,
    );
  }

  static String _attendanceListBase(String? title, String? tab) {
    if (tab == 'deployments') {
      return RoutePaths.attendanceDeploymentRequests;
    }
    final t = title ?? '';
    if (t.contains('nghỉ phép') ||
        t.contains('Nghỉ phép') ||
        t.contains('không lương') ||
        t.contains('Không lương')) {
      return RoutePaths.attendanceLeaveRequests;
    }
    return RoutePaths.attendanceWorkRequests;
  }

  static String? _requestTypeForWebTab(String? tab) {
    return switch (tab) {
      'young-child' => 'young-child',
      'transfer' || 'transfers' => 'department-transfer',
      'probation' || 'probation-conversions' => 'probation-conversion',
      'training' || 'training-proposals' => 'training-proposal',
      'seminar' || 'seminar-proposals' => 'seminar-proposal',
      'main-duty' => 'main-duty-authorization',
      'shift-config' => 'shift-config-change',
      _ => null,
    };
  }

  static NotificationTarget _fallbackForCategory(
    String? category,
    int? relatedRequestId,
    String? title,
  ) {
    if (relatedRequestId != null) {
      return switch (category) {
        'ATTENDANCE' => NotificationTarget.route(
          RoutePaths.withListFocus(
            _attendanceListBase(title, null),
            id: relatedRequestId,
            tab: 'approve',
          ),
        ),
        'DEPARTMENT_TRANSFER' => NotificationTarget.route(
          RoutePaths.withListFocus(
            RoutePaths.requestTypeListPath('department-transfer'),
            id: relatedRequestId,
            tab: 'approve',
          ),
        ),
        'PROBATION_CONVERSION' => NotificationTarget.route(
          RoutePaths.withListFocus(
            RoutePaths.requestTypeListPath('probation-conversion'),
            id: relatedRequestId,
            tab: 'approve',
          ),
        ),
        'YOUNG_CHILD' => NotificationTarget.route(
          RoutePaths.withListFocus(
            RoutePaths.requestTypeListPath('young-child'),
            id: relatedRequestId,
            tab: 'approve',
          ),
        ),
        'TRAINING_PROPOSAL' => NotificationTarget.route(
          RoutePaths.withListFocus(
            RoutePaths.requestTypeListPath('training-proposal'),
            id: relatedRequestId,
            tab: 'approve',
          ),
        ),
        'SEMINAR_PROPOSAL' => NotificationTarget.route(
          RoutePaths.withListFocus(
            RoutePaths.requestTypeListPath('seminar-proposal'),
            id: relatedRequestId,
            tab: 'approve',
          ),
        ),
        'MAIN_DUTY_AUTHORIZATION' => NotificationTarget.route(
          RoutePaths.withListFocus(
            RoutePaths.requestTypeListPath('main-duty-authorization'),
            id: relatedRequestId,
            tab: 'approve',
          ),
        ),
        'SHIFT_CONFIG_CHANGE' => NotificationTarget.route(
          RoutePaths.withListFocus(
            RoutePaths.requestTypeListPath('shift-config-change'),
            id: relatedRequestId,
            tab: 'approve',
          ),
        ),
        'NURSING_EVALUATION' => NotificationTarget.route(
          RoutePaths.withListFocus(
            RoutePaths.evaluation,
            id: relatedRequestId,
          ),
        ),
        _ => _listFallback(category),
      };
    }
    return _listFallback(category);
  }

  static NotificationTarget _listFallback(String? category) {
    return switch (category) {
      'ATTENDANCE' => const NotificationTarget.tab(AppShellTab.attendance),
      'DEPARTMENT_TRANSFER' => NotificationTarget.route(
        RoutePaths.requestTypeListPath('department-transfer'),
      ),
      'PROBATION_CONVERSION' => NotificationTarget.route(
        RoutePaths.requestTypeListPath('probation-conversion'),
      ),
      'YOUNG_CHILD' => NotificationTarget.route(
        RoutePaths.requestTypeListPath('young-child'),
      ),
      'TRAINING_PROPOSAL' => NotificationTarget.route(
        RoutePaths.requestTypeListPath('training-proposal'),
      ),
      'SEMINAR_PROPOSAL' => NotificationTarget.route(
        RoutePaths.requestTypeListPath('seminar-proposal'),
      ),
      'MAIN_DUTY_AUTHORIZATION' => NotificationTarget.route(
        RoutePaths.requestTypeListPath('main-duty-authorization'),
      ),
      'SHIFT_CONFIG_CHANGE' => NotificationTarget.route(
        RoutePaths.requestTypeListPath('shift-config-change'),
      ),
      'NURSING_EVALUATION' => const NotificationTarget.route(
        RoutePaths.evaluation,
      ),
      'PAYROLL' ||
      'SALARY_ADJUSTMENT' ||
      'SALARY_REVIEW' =>
        const NotificationTarget.tab(AppShellTab.salary),
      'INTERNAL' => const NotificationTarget.tab(AppShellTab.profile),
      _ => const NotificationTarget.tab(AppShellTab.home),
    };
  }
}
