import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_epoch.dart';
import '../../features/attendance/application/attendance_month_controller.dart';
import '../../features/attendance/application/attendance_requests_controller.dart';
import '../../features/attendance/application/attendance_schedule_provider.dart';
import '../../features/attendance/application/department_attendance_controller.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/employees/application/employee_list_controller.dart';
import '../../features/evaluation/application/evaluation_controller.dart';
import '../../features/notifications/application/notification_controller.dart';
import '../../features/requests/application/generic_request_controller.dart';
import '../../features/requests/data/request_type_config.dart';

/// Các employeeId đang mở bảng công — để poll nền refresh đúng NV admin đang xem.
final watchedAttendanceEmployeeIdsProvider =
    StateProvider<Set<int>>((ref) => <int>{});

/// Đồng bộ dữ liệu app với web khi đang mở — FCM / resume / poll định kỳ.
///
/// Không thay thế pull-to-refresh; chỉ làm mới nền các provider đang sống
/// để người dùng không phải vuốt khi có thay đổi từ phía khác.
class LiveDataRefreshCoordinator {
  LiveDataRefreshCoordinator(this._ref);

  final Ref _ref;

  Timer? _timer;
  bool _inFlight = false;
  bool _appResumed = true;
  DateTime? _lastRun;

  static const _interval = Duration(seconds: 25);
  static const _minGap = Duration(seconds: 6);

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      if (_appResumed) unawaited(refreshQuietly());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void setResumed(bool resumed) {
    _appResumed = resumed;
    if (resumed) unawaited(refreshQuietly(force: true));
  }

  Future<void> refreshQuietly({bool force = false}) async {
    final auth = _ref.read(authControllerProvider);
    if (auth.status != AuthStatus.authenticated) return;
    if (_inFlight) return;
    if (!force &&
        _lastRun != null &&
        DateTime.now().difference(_lastRun!) < _minGap) {
      return;
    }

    _inFlight = true;
    try {
      final tasks = <Future<void>>[
        _ref.read(notificationControllerProvider.notifier).pollQuietly(),
      ];

      if (_ref.exists(attendanceRequestsControllerProvider)) {
        tasks.add(
          _ref
              .read(attendanceRequestsControllerProvider.notifier)
              .refreshQuietly(),
        );
      }

      if (_ref.exists(evaluationControllerProvider)) {
        tasks.add(
          _ref.read(evaluationControllerProvider.notifier).refreshQuietly(),
        );
      }

      for (final config in RequestTypeConfig.all) {
        final provider = genericRequestControllerProvider(config.key);
        if (_ref.exists(provider)) {
          tasks.add(_ref.read(provider.notifier).refreshQuietly());
        }
      }

      final empIds = <int>{
        ..._ref.read(watchedAttendanceEmployeeIdsProvider),
        if (auth.employeeId != null && auth.employeeId! > 0) auth.employeeId!,
      };
      for (final empId in empIds) {
        final monthProvider = attendanceMonthControllerProvider(empId);
        if (_ref.exists(monthProvider)) {
          tasks.add(_ref.read(monthProvider.notifier).refreshQuietly());
          final monthState = _ref.read(monthProvider);
          final scheduleKey = AttendanceScheduleKey(
            employeeId: empId,
            year: monthState.year,
            month: monthState.month,
          );
          final scheduleProvider = attendanceScheduleProvider(scheduleKey);
          if (_ref.exists(scheduleProvider)) {
            tasks.add(_ref.refresh(scheduleProvider.future).then((_) {}));
          }
        }
      }
      if (_ref.exists(departmentAttendanceControllerProvider)) {
        tasks.add(
          _ref
              .read(departmentAttendanceControllerProvider.notifier)
              .refreshQuietly(),
        );
      }

      if (_ref.exists(employeeListControllerProvider)) {
        tasks.add(
          _ref.read(employeeListControllerProvider.notifier).refreshQuietly(),
        );
      }

      if (_ref.exists(dashboardAdminStatsProvider)) {
        tasks.add(_ref.refresh(dashboardAdminStatsProvider.future).then((_) {}));
      }
      if (_ref.exists(dashboardNursingStatsProvider)) {
        tasks.add(
          _ref.refresh(dashboardNursingStatsProvider.future).then((_) {}),
        );
      }

      await Future.wait(tasks);
      _lastRun = DateTime.now();
    } catch (_) {
      // Im lặng — làm mới nền không làm gián đoạn UI.
    } finally {
      _inFlight = false;
    }
  }

  void dispose() => stop();
}

final liveDataRefreshProvider = Provider<LiveDataRefreshCoordinator>((ref) {
  ref.watch(sessionEpochProvider);
  final coordinator = LiveDataRefreshCoordinator(ref);
  final auth = ref.read(authControllerProvider);
  if (auth.status == AuthStatus.authenticated) {
    coordinator.start();
  }
  ref.listen<AuthState>(authControllerProvider, (prev, next) {
    if (next.status == AuthStatus.authenticated) {
      coordinator.start();
      unawaited(coordinator.refreshQuietly(force: true));
    } else {
      coordinator.stop();
    }
  });
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
