import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../data/request_type_config.dart';

/// Cac tien ich hien thi chung cho don tu generic — vi khong the biet truoc
/// het cac gia tri enum trang thai cua tung loai don, ta "human hoa" status
/// string tu backend (SNAKE_CASE -> "Cau tu nhien") + suy mau theo tu khoa.
class GenericRequestUi {
  GenericRequestUi._();

  static const Set<String> _hiddenKeys = {
    'id', 'employeeId', 'reviewerId', 'evaluatorId', 'scores', 'raw',
  };

  static String humanizeStatus(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final words = raw.split('_').map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}');
    return words.join(' ');
  }

  static Color statusColor(String? raw) {
    final s = (raw ?? '').toUpperCase();
    if (s.contains('APPROVED') ||
        s.contains('COMPLETED') ||
        s == 'APPLIED') {
      return AppColors.success;
    }
    if (s.contains('REJECT') || s.contains('STOP')) return AppColors.error;
    if (s.contains('CANCEL') || s.contains('WITHDRAW')) return AppColors.textSecondary;
    if (s.contains('PENDING') || s.contains('EXTEND')) return AppColors.warning;
    return AppColors.textSecondary;
  }

  static String fieldLabel(RequestTypeConfig config, String key) {
    return config.fieldLabels[key] ?? _defaultLabel(key);
  }

  static String _defaultLabel(String key) {
    final withSpaces = key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}');
    final trimmed = withSpaces.trim();
    return trimmed.isEmpty ? key : '${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}';
  }

  static String formatValue(dynamic value) {
    if (value == null) return '—';
    if (value is bool) return value ? 'Có' : 'Không';
    if (value is String) {
      final parsedDate = DateTime.tryParse(value);
      if (parsedDate != null && value.length <= 10) return AppFormat.date(parsedDate);
      if (parsedDate != null) return AppFormat.dateTime(parsedDate);
      return value.isEmpty ? '—' : value;
    }
    if (value is num) return AppFormat.number(value, decimals: 2);
    return value.toString();
  }

  /// Danh sach (key, value) de hien thi tren man chi tiet, loai bo cac field
  /// noi bo (id, signature url, comment cua tung buoc — hien rieng).
  static List<MapEntry<String, dynamic>> displayableEntries(Map<String, dynamic> raw) {
    return raw.entries.where((e) {
      final k = e.key;
      if (_hiddenKeys.contains(k)) return false;
      if (k.endsWith('SignatureUrl') || k.endsWith('SignaturePath')) return false;
      if (k.endsWith('Comment') || k.endsWith('ReviewedAt') || k.endsWith('ReviewerUsername')) return false;
      if (k == 'status' ||
          k == 'createdAt' ||
          k == 'employeeName' ||
          k == 'fullName' ||
          k == 'department' ||
          k == 'departmentName' ||
          k == 'positionTitle') {
        return false;
      }
      if (e.value == null) return false;
      if (e.value is String && (e.value as String).trim().isEmpty) return false;
      if (e.value is List && (e.value as List).isEmpty) return false;
      if (e.value is Map && (e.value as Map).isEmpty) return false;
      return true;
    }).toList();
  }
}
