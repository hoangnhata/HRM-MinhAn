import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class EvaluationEnums {
  EvaluationEnums._();

  static const statusLabels = {
    'NONE': 'Chưa có phiếu',
    'DRAFT': 'Nháp',
    'PENDING_NURSING_HEAD': 'Chờ Trưởng phòng ĐD',
    'NURSING_HEAD_REJECTED': 'Trưởng phòng ĐD từ chối',
    'PENDING_HR': 'Chờ HCNS duyệt',
    'HR_REJECTED': 'HCNS từ chối',
    'PENDING_DIRECTOR': 'Chờ Giám đốc duyệt',
    'DIRECTOR_REJECTED': 'Giám đốc từ chối',
    'APPROVED': 'Đã duyệt',
    'CANCELLED': 'Đã hủy',
  };

  static String statusLabel(String v) => statusLabels[v] ?? v;

  static Color statusColor(String status) {
    if (status == 'APPROVED') return AppColors.success;
    if (status == 'NONE') return AppColors.textTertiary;
    if (status.endsWith('_REJECTED') || status == 'CANCELLED') {
      return AppColors.error;
    }
    if (status == 'DRAFT') return AppColors.info;
    return AppColors.warning;
  }

  static Color gradeColor(String? grade) {
    if (grade == null) return AppColors.textSecondary;
    final g = grade.toUpperCase();
    if (g.contains('XUẤT SẮC') || g.contains('TỐT') || g == 'A') {
      return AppColors.success;
    }
    if (g.contains('KHÁ') || g == 'B') return AppColors.primary;
    if (g.contains('TRUNG BÌNH') || g == 'C') return AppColors.warning;
    return AppColors.error;
  }

  /// Nhóm lọc trạng thái — khớp web `NURSING_EVAL_STATUS_FILTER_GROUPS`.
  static String statusFilterGroup(String? status) {
    final raw = (status ?? '').trim();
    if (raw.isEmpty || raw == 'NONE') return 'NONE';
    for (final g in statusFilterGroups) {
      if (g.$3.contains(raw)) return g.$1;
    }
    return raw;
  }

  static const statusFilterGroups = <(String, String, List<String>)>[
    ('DRAFT', 'Nháp', ['DRAFT']),
    (
      'NURSING_HEAD',
      'Trưởng phòng ĐD',
      ['PENDING_NURSING_HEAD', 'NURSING_HEAD_REJECTED'],
    ),
    ('HR', 'HCNS', ['PENDING_HR', 'HR_REJECTED']),
    (
      'DIRECTOR',
      'Giám đốc',
      ['PENDING_DIRECTOR', 'DIRECTOR_REJECTED'],
    ),
    ('APPROVED', 'Đã duyệt', ['APPROVED']),
    ('CANCELLED', 'Đã thu hồi', ['CANCELLED']),
  ];

  static const rosterStatusFilters = <(String, String)>[
    ('NONE', 'Chưa có phiếu'),
    ('DRAFT', 'Nháp'),
    ('NURSING_HEAD', 'Trưởng phòng ĐD'),
    ('HR', 'HCNS'),
    ('DIRECTOR', 'Giám đốc'),
    ('APPROVED', 'Đã duyệt'),
  ];
}
