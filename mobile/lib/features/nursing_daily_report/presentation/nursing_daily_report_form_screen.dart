import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../data/nursing_daily_report_models.dart';
import '../data/nursing_daily_report_repository.dart';
import 'nursing_integer_stepper.dart';

/// Mô tả một nhóm chỉ số của phiếu báo cáo.
class _SectionSpec {
  const _SectionSpec({
    required this.step,
    required this.title,
    required this.icon,
    required this.accent,
    required this.fields,
    this.subtitle,
    this.alertWhenPositive = false,
  });

  final String step;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final List<(String, String)> fields;
  final bool alertWhenPositive;
}

class NursingDailyReportFormScreen extends ConsumerStatefulWidget {
  const NursingDailyReportFormScreen({
    super.key,
    required this.departmentId,
    required this.departmentName,
    required this.reportDate,
    required this.canEdit,
    this.existing,
  });

  final int departmentId;
  final String departmentName;
  final String reportDate;
  final bool canEdit;
  final NursingDailyReport? existing;

  @override
  ConsumerState<NursingDailyReportFormScreen> createState() =>
      _NursingDailyReportFormScreenState();
}

class _NursingDailyReportFormScreenState
    extends ConsumerState<NursingDailyReportFormScreen> {
  late final Map<String, int> _values;
  late final Map<String, int> _initialValues;
  late bool _readOnly;
  bool _saving = false;
  bool _allowPop = false;

  final ScrollController _scrollController = ScrollController();

  static const List<_SectionSpec> _sections = [
    _SectionSpec(
      step: '01',
      title: 'Nhân lực',
      subtitle: 'Tình hình nhân sự trong ngày.',
      icon: Icons.groups_2_outlined,
      accent: AppColors.primary,
      fields: [
        ('totalStaff', 'Tổng số nhân viên khoa'),
        ('workingStaff', 'Số nhân viên đi làm'),
        ('plannedLeave', 'Nghỉ theo kế hoạch'),
        ('unplannedLeave', 'Nghỉ đột xuất'),
        ('maternityLeave', 'Nghỉ thai sản'),
        ('longLeave', 'Nghỉ phép / không lương dài ngày'),
        ('dutyAfternoonOff', 'Nghỉ trực / nghỉ buổi chiều'),
        ('externalMission', 'Công tác ngoại viện'),
      ],
    ),
    _SectionSpec(
      step: '02',
      title: 'Người bệnh',
      subtitle: 'Nội trú, ngoại trú, CLS và phẫu thuật.',
      icon: Icons.personal_injury_outlined,
      accent: AppColors.info,
      fields: [
        ('inpatients', 'Số người bệnh nội trú'),
        ('outpatients', 'Số người bệnh ngoại trú'),
        ('paraclinical', 'Số người bệnh cận lâm sàng'),
        ('surgery', 'Số người bệnh phẫu thuật'),
        ('dischargedYesterday', 'Số người bệnh ra viện hôm qua'),
      ],
    ),
    _SectionSpec(
      step: '03',
      title: 'Giường bệnh',
      icon: Icons.bed_outlined,
      accent: AppColors.secondaryDark,
      fields: [
        ('actualBeds', 'Số giường thực kê'),
        ('plannedBeds', 'Số giường kế hoạch'),
      ],
    ),
    _SectionSpec(
      step: '04',
      title: 'Hoạt động điều trị',
      icon: Icons.medical_services_outlined,
      accent: AppColors.primaryDark,
      fields: [
        (
          'inpatientTreatmentDays',
          'Tổng ngày điều trị nội trú của người bệnh ra viện hôm qua',
        ),
      ],
    ),
    _SectionSpec(
      step: '05',
      title: 'An toàn người bệnh',
      subtitle: 'Sự cố trong ngày qua — không có thì để 0.',
      icon: Icons.health_and_safety_outlined,
      accent: AppColors.error,
      alertWhenPositive: true,
      fields: [
        ('falls', 'Số ca té ngã ngày qua'),
        ('newPressureUlcers', 'Số ca loét tì đè mới'),
        ('idMixups', 'Số trường hợp nhầm lẫn xác định người bệnh'),
        ('medicationErrors', 'Số người bệnh xảy ra sai sót dùng thuốc'),
      ],
    ),
  ];

  List<(String, String)> get _allFields => [
    for (final section in _sections) ...section.fields,
  ];

  @override
  void initState() {
    super.initState();
    final existingValues = widget.existing?.values ?? const <String, int>{};
    _values = {
      for (final field in _allFields) field.$1: existingValues[field.$1] ?? 0,
    };
    _initialValues = Map<String, int>.from(_values);
    // Đã gửi + không có quyền sửa → chỉ xem (có thể thu hồi trong menu)
    _readOnly = widget.existing != null && !widget.canEdit;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _recall() async {
    final existing = widget.existing;
    if (existing == null || existing.canRecall != true) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Thu hồi báo cáo?',
      message:
          'Báo cáo sẽ về nháp để chỉnh sửa.\nTrưởng khoa chỉ thu hồi được trong vòng 1 ngày kể từ lúc gửi.',
      confirmLabel: 'Thu hồi',
      danger: true,
      icon: Icons.undo_rounded,
    );
    if (!confirmed) return;
    setState(() => _saving = true);
    try {
      await ref.read(nursingDailyReportRepositoryProvider).recall(existing.id);
      if (!mounted) return;
      showAppSnackBar(context, 'Đã thu hồi báo cáo', isSuccess: true);
      _popAfterUnlock(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _dirty {
    if (_readOnly) return false;
    for (final entry in _values.entries) {
      if (_initialValues[entry.key] != entry.value) return true;
    }
    return false;
  }

  Map<String, dynamic> _payload() => {
    'departmentId': widget.departmentId,
    'reportDate': widget.reportDate,
    'submit': true,
    ..._values,
  };

  int get _staffTotal => _values['totalStaff'] ?? 0;

  int get _staffAccounted =>
      (_values['workingStaff'] ?? 0) +
      (_values['plannedLeave'] ?? 0) +
      (_values['unplannedLeave'] ?? 0) +
      (_values['maternityLeave'] ?? 0) +
      (_values['longLeave'] ?? 0) +
      (_values['dutyAfternoonOff'] ?? 0) +
      (_values['externalMission'] ?? 0);

  bool get _staffBalanced =>
      (_staffTotal == 0 && _staffAccounted == 0) ||
      _staffAccounted == _staffTotal;

  int get _incidentTotal {
    var total = 0;
    for (final field in _sections.last.fields) {
      total += _values[field.$1] ?? 0;
    }
    return total;
  }

  void _popAfterUnlock([bool? result]) {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  Future<void> _requestPop() async {
    if (!_dirty) {
      _popAfterUnlock();
      return;
    }
    final discard = await showConfirmDialog(
      context,
      title: 'Bỏ thay đổi?',
      message: 'Các số liệu vừa nhập chưa được lưu.',
      confirmLabel: 'Bỏ thay đổi',
      danger: true,
      icon: Icons.edit_off_outlined,
    );
    if (!discard || !mounted) return;
    _popAfterUnlock();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final repo = ref.read(nursingDailyReportRepositoryProvider);
      if (widget.existing != null) {
        await repo.update(widget.existing!.id, _payload());
      } else {
        await repo.create(_payload());
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showAppSnackBar(
        context,
        'Đã đồng bộ báo cáo lên hệ thống',
        isSuccess: true,
      );
      _popAfterUnlock(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Không lưu được báo cáo', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final parsedDate = DateTime.tryParse(widget.reportDate);
    // Header nêu "khoa nào", thẻ nhận diện nêu "ngày nào" — tránh lặp y hệt
    // chuỗi khoa + ngày ở hai chỗ liền nhau.
    final dateLabel = parsedDate == null
        ? AppFormat.date(parsedDate)
        : AppFormat.longDateVi(parsedDate);

    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestPop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AppAmbientBackground(intensity: 0.45),
            Column(
              children: [
                AppScreenHeader(
                  dense: true,
                  title: editing ? 'Chi tiết báo cáo' : 'Nhập báo cáo',
                  icon: editing
                      ? Icons.fact_check_outlined
                      : Icons.edit_note_rounded,
                  eyebrow: 'Báo cáo ĐD hằng ngày',
                  subtitle: widget.departmentName,
                  onBack: _requestPop,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.sm,
                      AppSpacing.page,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppReveal(
                          child: _ReportIdentityCard(
                            departmentName: widget.departmentName,
                            dateLabel: dateLabel,
                            existing: widget.existing,
                            readOnly: _readOnly,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        NoticeBanner(
                          message: _readOnly
                              ? 'Đây là số liệu đang đồng bộ với web. Chọn “Chỉnh sửa” '
                                    'để cập nhật nếu bạn có quyền.'
                              : 'Nhập số tự nhiên; để 0 nếu không phát sinh. Phiếu '
                                    'sẽ hiển thị ngay trên web sau khi lưu.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (final (index, section) in _sections.indexed) ...[
                          NursingReportSection(
                            step: section.step,
                            title: section.title,
                            subtitle: section.subtitle,
                            icon: section.icon,
                            accent: section.accent,
                            children: [
                              for (final field in section.fields)
                                NursingIntegerStepper(
                                  label: field.$2,
                                  value: _values[field.$1] ?? 0,
                                  enabled: !_readOnly,
                                  alertWhenPositive: section.alertWhenPositive,
                                  onChanged: (value) => setState(
                                    () => _values[field.$1] = value < 0
                                        ? 0
                                        : value,
                                  ),
                                ),
                            ],
                          ),
                          // Đối chiếu nhân lực ngay dưới nhóm 01 để sửa tại chỗ.
                          if (index == 0 && !_readOnly && !_staffBalanced) ...[
                            _StaffBalanceNotice(
                              total: _staffTotal,
                              accounted: _staffAccounted,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                _FormActionBar(
                  readOnly: _readOnly,
                  canEdit: widget.canEdit,
                  canRecall: widget.existing?.canRecall == true,
                  saving: _saving,
                  dirty: _dirty,
                  editing: widget.existing != null,
                  incidentTotal: _incidentTotal,
                  onSave: _save,
                  onRecall: _recall,
                  onEnableEdit: () => setState(() => _readOnly = false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Đối chiếu tổng nhân viên với các nhóm đi làm/nghỉ.
class _StaffBalanceNotice extends StatelessWidget {
  const _StaffBalanceNotice({required this.total, required this.accounted});

  final int total;
  final int accounted;

  @override
  Widget build(BuildContext context) {
    final diff = accounted - total;
    return NoticeBanner.warning(
      title: 'Chênh lệch nhân lực',
      message:
          'Đi làm + các nhóm nghỉ/công tác là $accounted, tổng nhân viên khoa là '
          '$total (chênh ${diff > 0 ? '+' : ''}$diff). Hệ thống vẫn cho phép lưu.',
    );
  }
}

/// Thanh hành động dưới cùng — trạng thái thay đổi theo quyền và thao tác.
class _FormActionBar extends StatelessWidget {
  const _FormActionBar({
    required this.readOnly,
    required this.canEdit,
    required this.canRecall,
    required this.saving,
    required this.dirty,
    required this.editing,
    required this.incidentTotal,
    required this.onSave,
    required this.onRecall,
    required this.onEnableEdit,
  });

  final bool readOnly;
  final bool canEdit;
  final bool canRecall;
  final bool saving;
  final bool dirty;
  final bool editing;
  final int incidentTotal;
  final VoidCallback onSave;
  final VoidCallback onRecall;
  final VoidCallback onEnableEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.borderSoft)),
        boxShadow: AppShadows.nav,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            10,
            AppSpacing.page,
            10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (incidentTotal > 0) ...[
                _IncidentSummary(count: incidentTotal),
                const SizedBox(height: 9),
              ],
              if (readOnly) ...[
                if (canRecall) ...[
                  SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : onRecall,
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: const Text('Thu hồi báo cáo'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: canEdit ? onEnableEdit : null,
                    icon: Icon(
                      canEdit
                          ? Icons.edit_outlined
                          : Icons.lock_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      canEdit ? 'Chỉnh sửa báo cáo' : 'Bạn chỉ có quyền xem',
                    ),
                  ),
                ),
              ] else
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: saving ? null : onSave,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            dirty || !editing
                                ? Icons.cloud_upload_outlined
                                : Icons.cloud_done_outlined,
                            size: 19,
                          ),
                    label: Text(
                      saving
                          ? 'Đang đồng bộ…'
                          : (editing ? 'Cập nhật báo cáo' : 'Gửi báo cáo'),
                      style: AppTypography.style(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncidentSummary extends StatelessWidget {
  const _IncidentSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: AppRadius.brSm,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 17,
            color: AppColors.errorText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Phiếu ghi nhận $count sự cố an toàn người bệnh.',
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.errorText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportIdentityCard extends StatelessWidget {
  const _ReportIdentityCard({
    required this.departmentName,
    required this.dateLabel,
    required this.existing,
    required this.readOnly,
  });

  final String departmentName;
  final String dateLabel;
  final NursingDailyReport? existing;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final report = existing;
    final incidentCount = report?.safetyIncidents ?? 0;
    final statusColor = readOnly ? AppColors.success : AppColors.warning;
    final updatedBy = report?.updatedByUsername ?? report?.createdByUsername;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.13),
            AppColors.surface,
          ],
        ),
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.brMd,
                  boxShadow: AppShadows.tinted(AppColors.primary),
                ),
                child: const Icon(
                  Icons.local_hospital_outlined,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      departmentName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.28,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // w500 của metricMuted bị chìm trên nền gradient teal nhạt.
                      style: AppTypography.style(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        tabular: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.11),
                  borderRadius: AppRadius.brPill,
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  readOnly ? 'Đã nộp' : 'Đang nhập',
                  style: AppTypography.style(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (report != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _MiniMetric(
                  label: 'Đi làm',
                  value: '${report.workingStaff}/${report.totalStaff}',
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                _MiniMetric(
                  label: 'Nội trú',
                  value: '${report.inpatients}',
                  color: AppColors.info,
                ),
                const SizedBox(width: 8),
                _MiniMetric(
                  label: 'Sự cố',
                  value: '$incidentCount',
                  color: incidentCount > 0
                      ? AppColors.error
                      : AppColors.success,
                ),
              ],
            ),
            if (updatedBy != null) ...[
              const SizedBox(height: 11),
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cập nhật bởi $updatedBy',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.brSm,
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: AppTypography.metric(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
