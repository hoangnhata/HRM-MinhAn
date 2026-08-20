import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/user_role.dart';
import '../../../shared/models/attendance_models.dart';

class AttendanceEnums {
  AttendanceEnums._();

  static const requestTypeLabels = {
    'EXPLANATION': 'Giải trình đi muộn/về sớm',
    'UPDATE': 'Cập nhật công (quên chấm công)',
    'LEAVE': 'Nghỉ phép năm',
    'UNPAID_LEAVE': 'Nghỉ không lương',
    'BUSINESS_TRIP': 'Công tác',
    'DEPLOYMENT': 'Điều động / biệt phái',
  };

  /// Các loại đơn nhân viên tự lập được trên mobile.
  ///
  /// `BUSINESS_TRIP` đã ngừng sử dụng ở backend (thay bằng đơn Hội thảo) và
  /// `DEPLOYMENT` là phiếu do trưởng khoa/phòng lập cho người khác nên không
  /// nằm trong luồng tạo đơn cá nhân.
  static const creatableRequestTypeLabels = {
    'EXPLANATION': 'Giải trình đi muộn/về sớm',
    'UPDATE': 'Cập nhật công (quên chấm công)',
    'LEAVE': 'Nghỉ phép năm',
    'UNPAID_LEAVE': 'Nghỉ không lương',
  };

  static const leaveRequestTypes = {'LEAVE', 'UNPAID_LEAVE'};
  static const workRequestTypes = {'EXPLANATION', 'UPDATE'};
  static const deploymentRequestTypes = {'DEPLOYMENT'};

  static bool isLeaveRequestType(String type) => leaveRequestTypes.contains(type);
  static bool isWorkRequestType(String type) => workRequestTypes.contains(type);
  static bool isDeploymentRequestType(String type) =>
      deploymentRequestTypes.contains(type);

  /// Bốn mốc chấm công có thể giải trình — khớp với web.
  static const explanationSlotLabels = {
    'explainedMorningIn': 'Giờ vào ca sáng',
    'explainedMorningOut': 'Giờ ra ca sáng',
    'explainedAfternoonIn': 'Giờ vào ca chiều',
    'explainedAfternoonOut': 'Giờ ra ca chiều',
  };

  /// Buổi áp dụng suy ra từ loại bổ sung công (backend yêu cầu shiftScope).
  static String shiftScopeFromUpdateKind(String updateKind) {
    if (updateKind == 'AFTERNOON_SUPPLEMENT') return 'AFTERNOON';
    if (updateKind == 'FULL_DAY_SUPPLEMENT') return 'FULL_DAY';
    return 'MORNING';
  }

  /// Buổi áp dụng suy ra từ các mốc giải trình đã chọn.
  static String shiftScopeFromExplanationSlots(Iterable<String> slotKeys) {
    final morning = slotKeys.any((k) => k.contains('Morning'));
    final afternoon = slotKeys.any((k) => k.contains('Afternoon'));
    if (morning && afternoon) return 'FULL_DAY';
    if (afternoon) return 'AFTERNOON';
    return 'MORNING';
  }

  static const shiftScopeLabels = {
    'MORNING': 'Buổi sáng',
    'AFTERNOON': 'Buổi chiều',
    'FULL_DAY': 'Cả ngày',
  };

  static const updateKindLabels = {
    'MORNING_SUPPLEMENT': 'Bổ sung công sáng',
    'AFTERNOON_SUPPLEMENT': 'Bổ sung công chiều',
    'FULL_DAY_SUPPLEMENT': 'Bổ sung công cả ngày',
  };

  static const explanationKindLabels = {
    'LATE_ARRIVAL': 'Đi muộn',
    'EARLY_DEPARTURE': 'Về sớm',
  };

  static const statusLabels = {
    'PENDING_HEAD': 'Chờ Trưởng khoa/phòng',
    'HEAD_REJECTED': 'Trưởng khoa/phòng từ chối',
    'PENDING_NURSING_HEAD': 'Chờ Trưởng phòng Điều dưỡng',
    'NURSING_HEAD_REJECTED': 'Trưởng phòng ĐD từ chối',
    'PENDING_HR': 'Chờ HCNS duyệt',
    'HR_REJECTED': 'HCNS từ chối',
    'PENDING_DIRECTOR': 'Chờ Giám đốc quyết định',
    'DIRECTOR_REJECTED': 'Giám đốc từ chối',
    'APPROVED': 'Đã duyệt',
    'APPROVED_NO_FINE': 'Đã duyệt (miễn phạt)',
    'WITHDRAWN': 'Đã rút đơn',
  };

  static const requestTypeIcons = {
    'EXPLANATION': Icons.record_voice_over_outlined,
    'UPDATE': Icons.touch_app_outlined,
    'LEAVE': Icons.beach_access_outlined,
    'UNPAID_LEAVE': Icons.money_off_outlined,
    'BUSINESS_TRIP': Icons.flight_takeoff_outlined,
    'DEPLOYMENT': Icons.swap_horiz_outlined,
  };

  static const requestTypeColors = {
    'EXPLANATION': AppColors.warning,
    'UPDATE': AppColors.info,
    'LEAVE': AppColors.primary,
    'UNPAID_LEAVE': AppColors.secondaryDark,
    'BUSINESS_TRIP': AppColors.success,
    'DEPLOYMENT': Color(0xFF7C3AED),
  };

  static IconData requestTypeIcon(String v) =>
      requestTypeIcons[v] ?? Icons.description_outlined;

  static Color requestTypeColor(String v) =>
      requestTypeColors[v] ?? AppColors.primary;

  static String requestTypeLabel(String v) => requestTypeLabels[v] ?? v;

  /// Trạng thái đang chờ một cấp nào đó duyệt (chưa kết thúc quy trình).
  static bool isPending(String status) => status.startsWith('PENDING_');

  /// Nhãn ngắn cho chip trạng thái trong danh sách hẹp.
  static String shortStatusLabel(String status) {
    if (status == 'APPROVED' || status == 'APPROVED_NO_FINE') return 'Đã duyệt';
    if (status.endsWith('_REJECTED')) return 'Từ chối';
    if (status == 'WITHDRAWN') return 'Đã rút';
    return 'Chờ duyệt';
  }
  static String shiftScopeLabel(String? v) => v == null ? '—' : (shiftScopeLabels[v] ?? v);
  static String updateKindLabel(String? v) => v == null ? '—' : (updateKindLabels[v] ?? v);
  static String explanationKindLabel(String? v) => v == null ? '—' : (explanationKindLabels[v] ?? v);
  static String statusLabel(String v) => statusLabels[v] ?? v;

  static Color statusColor(String status) {
    if (status == 'APPROVED' || status == 'APPROVED_NO_FINE') return AppColors.success;
    if (status.endsWith('_REJECTED')) return AppColors.error;
    if (status == 'WITHDRAWN') return AppColors.textSecondary;
    return AppColors.warning;
  }

  /// Suy ra endpoint review tuong ung voi trang thai hien tai cua don —
  /// dung chung cho moi vai tro duyet (backend tu kiem tra quyen).
  static String? reviewEndpointFor(String status) {
    switch (status) {
      case 'PENDING_HEAD':
        return 'head-review';
      case 'PENDING_NURSING_HEAD':
        return 'nursing-head-review';
      case 'PENDING_HR':
        return 'hr-review';
      case 'PENDING_DIRECTOR':
        return 'director-review';
      default:
        return null;
    }
  }
}

/// Prefill khi mở form đơn công / nghỉ phép.
class AttendanceRequestPrefill {
  const AttendanceRequestPrefill({
    required this.requestType,
    this.workDate,
    this.updateKind,
    this.allowedTypes,
    this.editRequest,
  });

  final String requestType;
  final DateTime? workDate;
  final String? updateKind;

  /// Khi có giá trị, form chỉ cho chọn các loại trong danh sách này.
  final List<String>? allowedTypes;

  /// Khi chỉnh sửa đơn đang chờ duyệt — prefill từ bản ghi hiện có.
  final AttendanceWorkRequest? editRequest;

  AttendanceRequestPrefill copyWith({
    String? requestType,
    DateTime? workDate,
    String? updateKind,
    List<String>? allowedTypes,
    AttendanceWorkRequest? editRequest,
  }) {
    return AttendanceRequestPrefill(
      requestType: requestType ?? this.requestType,
      workDate: workDate ?? this.workDate,
      updateKind: updateKind ?? this.updateKind,
      allowedTypes: allowedTypes ?? this.allowedTypes,
      editRequest: editRequest ?? this.editRequest,
    );
  }

  factory AttendanceRequestPrefill.edit(AttendanceWorkRequest request) {
    final type = request.requestType;
    List<String>? allowedTypes;
    if (AttendanceEnums.isLeaveRequestType(type)) {
      allowedTypes = AttendanceEnums.leaveRequestTypes.toList();
    } else if (AttendanceEnums.isWorkRequestType(type)) {
      allowedTypes = AttendanceEnums.workRequestTypes.toList();
    }
    return AttendanceRequestPrefill(
      requestType: type,
      workDate: request.workDate,
      updateKind: request.updateKind,
      allowedTypes: allowedTypes,
      editRequest: request,
    );
  }

  factory AttendanceRequestPrefill.leave({
    DateTime? workDate,
    String requestType = 'LEAVE',
  }) {
    return AttendanceRequestPrefill(
      requestType: requestType,
      workDate: workDate,
      allowedTypes: AttendanceEnums.leaveRequestTypes.toList(),
    );
  }

  factory AttendanceRequestPrefill.work({
    DateTime? workDate,
    String requestType = 'EXPLANATION',
    String? updateKind,
  }) {
    return AttendanceRequestPrefill(
      requestType: requestType,
      workDate: workDate,
      updateKind: updateKind,
      allowedTypes: AttendanceEnums.workRequestTypes.toList(),
    );
  }

  /// Gợi ý loại bổ sung theo ca còn thiếu.
  static String updateKindForDay({
    required bool missingMorning,
    required bool missingAfternoon,
  }) {
    if (missingMorning && missingAfternoon) return 'FULL_DAY_SUPPLEMENT';
    if (missingMorning) return 'MORNING_SUPPLEMENT';
    if (missingAfternoon) return 'AFTERNOON_SUPPLEMENT';
    return 'FULL_DAY_SUPPLEMENT';
  }
}

/// Phân tách danh sách: nghỉ phép / đơn công / điều động.
enum AttendanceRequestScope {
  leave,
  work,
  deployment;

  bool matches(String requestType) => switch (this) {
        leave => AttendanceEnums.isLeaveRequestType(requestType),
        work => AttendanceEnums.isWorkRequestType(requestType),
        deployment => AttendanceEnums.isDeploymentRequestType(requestType),
      };

  /// Nhân viên tự lập nghỉ phép / đơn công. Điều động: trưởng khoa hoặc admin.
  bool canCreate(UserRole role) => switch (this) {
        leave || work => true,
        deployment =>
          role == UserRole.admin || role == UserRole.headDepartment,
      };

  List<String> get creatableTypes => switch (this) {
        leave => AttendanceEnums.leaveRequestTypes.toList(),
        work => AttendanceEnums.workRequestTypes.toList(),
        deployment => const [],
      };

  String get defaultCreateType => switch (this) {
        leave => 'LEAVE',
        work => 'EXPLANATION',
        deployment => 'DEPLOYMENT',
      };

  String get title => switch (this) {
        leave => 'Đơn nghỉ phép',
        work => 'Đơn công',
        deployment => 'Đơn điều động',
      };

  String get subtitle => switch (this) {
        leave => 'Nghỉ phép năm và nghỉ không lương.',
        work => 'Giải trình muộn/sớm và cập nhật quên chấm công.',
        deployment =>
          'Điều động: lập bởi Trưởng khoa/ĐD trưởng → duyệt theo luồng.',
      };

  /// Banner dưới header — chỉ dùng khi xem danh sách cá nhân (không phải người duyệt).
  String employeeListIntro(bool canApprove) {
    if (this != deployment) return '';
    if (canApprove) {
      return 'Điều động: Trưởng khoa/Điều dưỡng trưởng lập → Trưởng phòng ĐD (khối ĐD) → HCNS → Giám đốc. Duyệt ở tab Chờ duyệt.';
    }
    return 'Các đơn điều động được Trưởng khoa/Điều dưỡng trưởng lập cho bạn và trạng thái duyệt hiện tại.';
  }

  IconData get icon => switch (this) {
        leave => Icons.beach_access_rounded,
        work => Icons.assignment_outlined,
        deployment => Icons.swap_horiz_rounded,
      };

  AttendanceRequestPrefill? createPrefill() => switch (this) {
        leave => AttendanceRequestPrefill.leave(),
        work => AttendanceRequestPrefill.work(),
        deployment => null,
      };
}
