import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/request_type_config.dart';
import 'probation_conversion_detail_body.dart';
import 'typed_request_detail_widgets.dart';

/// Chi tiết đơn typed theo loại — bố cục mobile, dữ liệu đồng bộ API web.
class TypedRequestDetailBody extends StatelessWidget {
  const TypedRequestDetailBody({
    super.key,
    required this.config,
    required this.raw,
    this.status,
    this.stageLabel,
    this.bottom,
  });

  final RequestTypeConfig config;
  final Map<String, dynamic> raw;
  final String? status;
  final String? stageLabel;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return switch (config.key) {
      'probation-conversion' => ProbationConversionDetailBody(
          raw: raw,
          status: status,
          stageLabel: stageLabel,
          bottom: bottom,
        ),
      'department-transfer' => _TransferBody(
          config: config,
          raw: raw,
          status: status,
          stageLabel: stageLabel,
          bottom: bottom,
        ),
      'main-duty-authorization' => _MainDutyBody(
          config: config,
          raw: raw,
          status: status,
          stageLabel: stageLabel,
          bottom: bottom,
        ),
      'training-proposal' => _TrainingBody(
          config: config,
          raw: raw,
          status: status,
          stageLabel: stageLabel,
          bottom: bottom,
        ),
      'seminar-proposal' => _SeminarBody(
          config: config,
          raw: raw,
          status: status,
          stageLabel: stageLabel,
          bottom: bottom,
        ),
      'young-child' => _YoungChildBody(
          config: config,
          raw: raw,
          status: status,
          stageLabel: stageLabel,
          bottom: bottom,
        ),
      'shift-config-change' => _ShiftConfigBody(
          config: config,
          raw: raw,
          status: status,
          stageLabel: stageLabel,
          bottom: bottom,
        ),
      _ => const SizedBox.shrink(),
    };
  }

  static bool supports(String typeKey) => const {
        'probation-conversion',
        'department-transfer',
        'main-duty-authorization',
        'training-proposal',
        'seminar-proposal',
        'young-child',
        'shift-config-change',
      }.contains(typeKey);
}

String _employeeLine(Map<String, dynamic> raw) {
  final code = typedStr(raw, 'employeeCode');
  final position = typedStr(raw, 'positionTitle');
  return [
    if (code != null) code,
    if (position != null) position,
  ].join(' · ');
}

List<Widget> _employeeSection(
  RequestTypeConfig config,
  Map<String, dynamic> raw, {
  List<(String, String)> extra = const [],
}) {
  final name = typedStr(raw, 'employeeName') ?? typedStr(raw, 'fullName') ?? '—';
  final code = typedStr(raw, 'employeeCode');
  final dept =
      typedStr(raw, 'departmentName') ?? typedStr(raw, 'department');
  final position = typedStr(raw, 'positionTitle');
  final requester = typedStr(raw, 'requestedByUsername');

  return [
    TypedDetailSection(
      title: 'Thông tin nhân viên',
      icon: Icons.person_outline_rounded,
      color: config.color,
      child: Column(
        children: [
          TypedDetailKV(label: 'Họ tên', value: name),
          if (code != null) TypedDetailKV(label: 'Mã nhân viên', value: code),
          if (position != null) TypedDetailKV(label: 'Vị trí', value: position),
          if (dept != null) TypedDetailKV(label: 'Khoa/phòng', value: dept),
          for (final e in extra) TypedDetailKV(label: e.$1, value: e.$2),
          if (requester != null)
            TypedDetailKV(label: 'Người lập', value: requester),
        ],
      ),
    ),
  ];
}

class _TransferBody extends StatelessWidget {
  const _TransferBody({
    required this.config,
    required this.raw,
    this.status,
    this.stageLabel,
    this.bottom,
  });

  final RequestTypeConfig config;
  final Map<String, dynamic> raw;
  final String? status;
  final String? stageLabel;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final name = typedStr(raw, 'employeeName') ?? '—';
    final fromDept = typedStr(raw, 'fromDepartmentName');
    final toDept = typedStr(raw, 'toDepartmentName');
    final toPosition = typedStr(raw, 'toPositionTitle');
    final effective = typedDate(raw, 'effectiveDate');
    final reason = typedStr(raw, 'reason');
    final created = typedDate(raw, 'createdAt');
    final applied = typedDate(raw, 'appliedAt');

    return TypedDetailScaffold(
      hero: TypedDetailHero(
        icon: config.icon,
        color: config.color,
        title: name,
        subtitle: _employeeLine(raw),
        status: status,
        statusLabel: typedStatusLabel(config.key, status),
        stageLabel: stageLabel,
        chips: [
          if (toDept != null) (toDept, config.color),
          if (effective != null)
            ('Hiệu lực ${typedDateLabel(effective)}', AppColors.textSecondary),
        ],
      ),
      sections: [
        ..._employeeSection(config, raw),
        TypedDetailSection(
          title: 'Nội dung luân chuyển',
          icon: Icons.swap_horiz_rounded,
          color: config.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (fromDept != null)
                TypedDetailKV(label: 'Từ phòng ban', value: fromDept),
              if (toDept != null)
                TypedDetailKV(label: 'Đến phòng ban', value: toDept),
              if (toPosition != null)
                TypedDetailKV(label: 'Chức danh mới', value: toPosition),
              if (effective != null)
                TypedDetailKV(
                  label: 'Ngày hiệu lực',
                  value: typedDateLabel(effective),
                ),
              if (created != null)
                TypedDetailKV(
                  label: 'Ngày gửi',
                  value: typedDateTimeLabel(created),
                ),
              if (applied != null)
                TypedDetailKV(
                  label: 'Ngày áp dụng',
                  value: typedDateTimeLabel(applied),
                ),
              if (reason != null) ...[
                const SizedBox(height: 4),
                TypedDetailNote(
                  label: 'Lý do',
                  value: reason,
                  color: config.color,
                ),
              ],
            ],
          ),
        ),
      ],
      bottom: bottom,
    );
  }
}

class _MainDutyBody extends StatelessWidget {
  const _MainDutyBody({
    required this.config,
    required this.raw,
    this.status,
    this.stageLabel,
    this.bottom,
  });

  final RequestTypeConfig config;
  final Map<String, dynamic> raw;
  final String? status;
  final String? stageLabel;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final name = typedStr(raw, 'employeeName') ?? '—';
    final formLabel = typedStr(raw, 'formTypeLabel') ??
        switch (typedStr(raw, 'formType')?.toUpperCase()) {
          'DOCTOR' => 'Bác sĩ',
          'NURSE' => 'Điều dưỡng',
          _ => null,
        };
    final from = typedDate(raw, 'accompanyingFrom');
    final to = typedDate(raw, 'accompanyingTo');
    final effective = typedDate(raw, 'effectiveFrom');
    final phone = typedStr(raw, 'phone');
    final gender = switch (typedStr(raw, 'gender')?.toUpperCase()) {
      'MALE' || 'NAM' => 'Nam',
      'FEMALE' || 'NỮ' || 'NU' => 'Nữ',
      final g when g != null => g,
      _ => null,
    };
    final address = typedStr(raw, 'address');
    final degree = typedStr(raw, 'degree');
    final reason = typedStr(raw, 'reason');
    final period = typedStr(raw, 'accompanyingPeriod');

    return TypedDetailScaffold(
      hero: TypedDetailHero(
        icon: config.icon,
        color: config.color,
        title: name,
        subtitle: [
          if (formLabel != null) formLabel,
          if (typedStr(raw, 'departmentName') != null)
            typedStr(raw, 'departmentName')!,
        ].join(' · '),
        status: status,
        statusLabel: typedStatusLabel(config.key, status),
        stageLabel: stageLabel,
        chips: [
          if (formLabel != null) (formLabel, AppColors.info),
          if (effective != null)
            (
              'Hiệu lực ${typedDateLabel(effective)}',
              AppColors.textSecondary,
            ),
        ],
      ),
      sections: [
        ..._employeeSection(
          config,
          raw,
          extra: [
            if (formLabel != null) ('Mẫu đơn', formLabel),
          ],
        ),
        TypedDetailSection(
          title: 'Thời gian trực kèm & hiệu lực',
          icon: Icons.event_available_outlined,
          color: config.color,
          child: Column(
            children: [
              if (from != null)
                TypedDetailKV(
                  label: 'Trực kèm từ',
                  value: typedDateLabel(from),
                ),
              if (to != null)
                TypedDetailKV(
                  label: 'Trực kèm đến',
                  value: typedDateLabel(to),
                ),
              if (period != null)
                TypedDetailKV(label: 'Khoảng thời gian', value: period),
              if (effective != null)
                TypedDetailKV(
                  label: 'Hiệu lực trực chính',
                  value: typedDateLabel(effective),
                ),
            ],
          ),
        ),
        if (phone != null ||
            gender != null ||
            address != null ||
            degree != null)
          TypedDetailSection(
            title: 'Thông tin bổ sung',
            icon: Icons.info_outline_rounded,
            color: config.color,
            child: Column(
              children: [
                if (phone != null) TypedDetailKV(label: 'Điện thoại', value: phone),
                if (gender != null) TypedDetailKV(label: 'Giới tính', value: gender),
                if (address != null) TypedDetailKV(label: 'Địa chỉ', value: address),
                if (degree != null) TypedDetailKV(label: 'Bằng cấp', value: degree),
              ],
            ),
          ),
        if (reason != null)
          TypedDetailSection(
            title: 'Lý do / đề nghị',
            icon: Icons.notes_rounded,
            color: config.color,
            child: TypedDetailNote(
              label: 'Nội dung',
              value: reason,
              color: config.color,
            ),
          ),
      ],
      bottom: bottom,
    );
  }
}

class _TrainingBody extends StatelessWidget {
  const _TrainingBody({
    required this.config,
    required this.raw,
    this.status,
    this.stageLabel,
    this.bottom,
  });

  final RequestTypeConfig config;
  final Map<String, dynamic> raw;
  final String? status;
  final String? stageLabel;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final name = typedStr(raw, 'employeeName') ?? '—';
    final course = typedStr(raw, 'courseName');
    final location = typedStr(raw, 'location');
    final period = typedStr(raw, 'plannedPeriod');
    final tuition = typedStr(raw, 'tuitionFee');
    final support = typedStr(raw, 'monthlySupport');
    final commitment = typedStr(raw, 'postCourseCommitment');
    final goal = typedStr(raw, 'trainingGoal');
    final reason = typedStr(raw, 'reason');
    final proposing = typedStr(raw, 'proposingDepartment');
    final dob = typedDate(raw, 'dateOfBirth');

    return TypedDetailScaffold(
      hero: TypedDetailHero(
        icon: config.icon,
        color: config.color,
        title: name,
        subtitle: _employeeLine(raw),
        status: status,
        statusLabel: typedStatusLabel(config.key, status),
        stageLabel: stageLabel,
        chips: [
          if (typedStr(raw, 'positionTitle') != null)
            (typedStr(raw, 'positionTitle')!, AppColors.textSecondary),
          if (period != null) (period, config.color),
        ],
      ),
      sections: [
        ..._employeeSection(
          config,
          raw,
          extra: [
            if (dob != null) ('Ngày sinh', typedDateLabel(dob)),
            if (proposing != null) ('Khoa/phòng đề xuất', proposing),
          ],
        ),
        TypedDetailSection(
          title: 'Nội dung đào tạo',
          icon: Icons.school_outlined,
          color: config.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (course != null)
                TypedDetailKV(label: 'Tên khóa học', value: course),
              if (location != null)
                TypedDetailKV(label: 'Địa điểm học', value: location),
              if (period != null)
                TypedDetailKV(label: 'Thời gian dự kiến', value: period),
              if (tuition != null)
                TypedDetailKV(label: 'Học phí', value: tuition),
              if (support != null)
                TypedDetailKV(label: 'Hỗ trợ hàng tháng', value: support),
              if (commitment != null)
                TypedDetailKV(label: 'Cam kết sau khóa', value: commitment),
              if (goal != null) ...[
                const SizedBox(height: 4),
                TypedDetailNote(
                  label: 'Mục tiêu đào tạo',
                  value: goal,
                  color: config.color,
                ),
              ],
              if (reason != null) ...[
                const SizedBox(height: 8),
                TypedDetailNote(
                  label: 'Lý do đề xuất',
                  value: reason,
                  color: config.color,
                ),
              ],
            ],
          ),
        ),
      ],
      bottom: bottom,
    );
  }
}

class _SeminarBody extends StatelessWidget {
  const _SeminarBody({
    required this.config,
    required this.raw,
    this.status,
    this.stageLabel,
    this.bottom,
  });

  final RequestTypeConfig config;
  final Map<String, dynamic> raw;
  final String? status;
  final String? stageLabel;
  final Widget? bottom;

  static String _scopeLabel(String? scope) => switch (scope?.toUpperCase()) {
        'MORNING' => 'Buổi sáng',
        'AFTERNOON' => 'Buổi chiều',
        'FULL_DAY' => 'Cả ngày',
        _ => scope ?? '—',
      };

  @override
  Widget build(BuildContext context) {
    final name = typedStr(raw, 'employeeName') ?? '—';
    final seminar = typedStr(raw, 'seminarName');
    final location = typedStr(raw, 'location');
    final start = typedDate(raw, 'startDate');
    final end = typedDate(raw, 'endDate');
    final scope = typedStr(raw, 'attendanceScope');
    final reason = typedStr(raw, 'reason');
    final proposing = typedStr(raw, 'proposingDepartment');
    final withPay = raw['withPay'] as bool?;
    final support = typedStr(raw, 'supportAmount');
    final range = typedDateRange(start, end);

    return TypedDetailScaffold(
      hero: TypedDetailHero(
        icon: config.icon,
        color: config.color,
        title: name,
        subtitle: _employeeLine(raw),
        status: status,
        statusLabel: typedStatusLabel(config.key, status),
        stageLabel: stageLabel,
        chips: [
          if (withPay == true) ('Có công', AppColors.success),
          if (withPay == false) ('Không công', AppColors.textSecondary),
          if (start != null || end != null)
            (range, AppColors.textSecondary),
        ],
      ),
      sections: [
        ..._employeeSection(
          config,
          raw,
          extra: [
            if (proposing != null) ('Khoa/phòng đề xuất', proposing),
          ],
        ),
        TypedDetailSection(
          title: 'Nội dung hội thảo',
          icon: Icons.groups_outlined,
          color: config.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (seminar != null)
                TypedDetailKV(label: 'Tên hội thảo', value: seminar),
              if (location != null)
                TypedDetailKV(label: 'Địa điểm', value: location),
              if (start != null || end != null)
                TypedDetailKV(label: 'Thời gian', value: range),
              if (scope != null)
                TypedDetailKV(
                  label: 'Phạm vi tính công',
                  value: _scopeLabel(scope),
                ),
              if (withPay != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tính công',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                      StatusChip(
                        label: withPay ? 'Có công' : 'Không công',
                        color: withPay
                            ? AppColors.success
                            : AppColors.textSecondary,
                        dense: true,
                        showDot: false,
                      ),
                    ],
                  ),
                ),
              if (support != null)
                TypedDetailKV(label: 'Tiền hỗ trợ', value: support),
              if (reason != null) ...[
                const SizedBox(height: 4),
                TypedDetailNote(
                  label: 'Lý do',
                  value: reason,
                  color: config.color,
                ),
              ],
            ],
          ),
        ),
      ],
      bottom: bottom,
    );
  }
}

class _YoungChildBody extends StatelessWidget {
  const _YoungChildBody({
    required this.config,
    required this.raw,
    this.status,
    this.stageLabel,
    this.bottom,
  });

  final RequestTypeConfig config;
  final Map<String, dynamic> raw;
  final String? status;
  final String? stageLabel;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final name = typedStr(raw, 'employeeName') ?? '—';
    final start = typedDate(raw, 'startDate');
    final end = typedDate(raw, 'endDate');
    final enabled = raw['enabled'] as bool? ?? true;
    final reason = typedStr(raw, 'reason');
    final range = typedDateRange(start, end);

    return TypedDetailScaffold(
      hero: TypedDetailHero(
        icon: config.icon,
        color: config.color,
        title: name,
        subtitle: _employeeLine(raw),
        status: status,
        statusLabel: typedStatusLabel(config.key, status),
        stageLabel: stageLabel,
        chips: [
          (
            enabled ? 'Đề xuất bật' : 'Đề xuất tắt',
            enabled ? AppColors.success : AppColors.warning,
          ),
          if (start != null || end != null)
            (range, AppColors.textSecondary),
        ],
      ),
      sections: [
        ..._employeeSection(config, raw),
        TypedDetailSection(
          title: 'Nội dung đề xuất',
          icon: Icons.child_care_outlined,
          color: config.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (start != null || end != null)
                TypedDetailKV(label: 'Thời gian áp dụng', value: range),
              TypedDetailKV(
                label: 'Nội dung',
                value: enabled
                    ? 'Bật chế độ nuôi con nhỏ'
                    : 'Tắt chế độ nuôi con nhỏ',
              ),
              if (reason != null) ...[
                const SizedBox(height: 4),
                TypedDetailNote(
                  label: 'Lý do',
                  value: reason,
                  color: config.color,
                ),
              ],
            ],
          ),
        ),
      ],
      bottom: bottom,
    );
  }
}

class _ShiftConfigBody extends StatelessWidget {
  const _ShiftConfigBody({
    required this.config,
    required this.raw,
    this.status,
    this.stageLabel,
    this.bottom,
  });

  final RequestTypeConfig config;
  final Map<String, dynamic> raw;
  final String? status;
  final String? stageLabel;
  final Widget? bottom;

  static String _hhmm(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  static String _seasonLabel(String? season, String? label) {
    if (label != null && label.isNotEmpty) return label;
    return switch (season?.toUpperCase()) {
      'SUMMER' => 'Mùa hè',
      'WINTER' => 'Mùa đông',
      'BOTH' => 'Cả năm',
      _ => season ?? '—',
    };
  }

  @override
  Widget build(BuildContext context) {
    final name = typedStr(raw, 'employeeName') ?? '—';
    final season = typedStr(raw, 'season');
    final seasonLabel =
        _seasonLabel(season, typedStr(raw, 'seasonLabel'));
    final reason = typedStr(raw, 'reason');
    final morningUnits = raw['morningUnits'];
    final afternoonUnits = raw['afternoonUnits'];

    return TypedDetailScaffold(
      hero: TypedDetailHero(
        icon: config.icon,
        color: config.color,
        title: name,
        subtitle: _employeeLine(raw),
        status: status,
        statusLabel: typedStatusLabel(config.key, status),
        stageLabel: stageLabel,
        chips: [
          (seasonLabel, config.color),
        ],
      ),
      sections: [
        ..._employeeSection(config, raw),
        TypedDetailSection(
          title: 'Khung giờ đề xuất',
          icon: Icons.schedule_outlined,
          color: config.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TypedDetailKV(label: 'Mùa áp dụng', value: seasonLabel),
              TypedDetailKV(
                label: 'Ca sáng',
                value:
                    '${_hhmm(typedStr(raw, 'morningStart'))} – ${_hhmm(typedStr(raw, 'morningEnd'))}',
              ),
              TypedDetailKV(
                label: 'Ca chiều',
                value:
                    '${_hhmm(typedStr(raw, 'afternoonStart'))} – ${_hhmm(typedStr(raw, 'afternoonEnd'))}',
              ),
              if (typedStr(raw, 'winterMorningStart') != null) ...[
                TypedDetailKV(
                  label: 'Đông · sáng',
                  value:
                      '${_hhmm(typedStr(raw, 'winterMorningStart'))} – ${_hhmm(typedStr(raw, 'winterMorningEnd'))}',
                ),
                TypedDetailKV(
                  label: 'Đông · chiều',
                  value:
                      '${_hhmm(typedStr(raw, 'winterAfternoonStart'))} – ${_hhmm(typedStr(raw, 'winterAfternoonEnd'))}',
                ),
              ],
              if (morningUnits != null)
                TypedDetailKV(
                  label: 'Công buổi sáng',
                  value: morningUnits.toString(),
                ),
              if (afternoonUnits != null)
                TypedDetailKV(
                  label: 'Công buổi chiều',
                  value: afternoonUnits.toString(),
                ),
              if (reason != null) ...[
                const SizedBox(height: 4),
                TypedDetailNote(
                  label: 'Lý do',
                  value: reason,
                  color: config.color,
                ),
              ],
            ],
          ),
        ),
      ],
      bottom: bottom,
    );
  }
}
