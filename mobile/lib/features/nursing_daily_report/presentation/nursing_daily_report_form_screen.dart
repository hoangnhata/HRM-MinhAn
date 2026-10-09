import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_action_button.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../data/nursing_daily_report_models.dart';
import '../data/nursing_daily_report_repository.dart';
import 'inpatient_care_level_accordion.dart';
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
      subtitle: 'Nội trú theo cấp chăm sóc, ngoại trú, CLS và phẫu thuật.',
      icon: Icons.personal_injury_outlined,
      accent: AppColors.info,
      fields: [
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
    ('inpatients', 'Người bệnh nội trú'),
    ('inpatientsCareLevel1', 'NB chăm sóc cấp 1'),
    ('inpatientsCareLevel2', 'NB chăm sóc cấp 2'),
    ('inpatientsCareLevel3', 'NB chăm sóc cấp 3'),
  ];

  @override
  void initState() {
    super.initState();
    final existingValues = widget.existing?.values ?? const <String, int>{};
    _values = {
      for (final field in _allFields) field.$1: existingValues[field.$1] ?? 0,
    };
    // Đồng bộ tổng nội trú từ 3 cấp (hoặc giữ tổng cũ nếu chưa phân cấp).
    final l1 = _values['inpatientsCareLevel1'] ?? 0;
    final l2 = _values['inpatientsCareLevel2'] ?? 0;
    final l3 = _values['inpatientsCareLevel3'] ?? 0;
    final levelSum = l1 + l2 + l3;
    if (levelSum > 0) {
      _values['inpatients'] = levelSum;
    } else if ((_values['inpatients'] ?? 0) > 0) {
      _values['inpatientsCareLevel1'] = _values['inpatients']!;
    }
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

  Map<String, dynamic> _payload() {
    final l1 = _values['inpatientsCareLevel1'] ?? 0;
    final l2 = _values['inpatientsCareLevel2'] ?? 0;
    final l3 = _values['inpatientsCareLevel3'] ?? 0;
    return {
      'departmentId': widget.departmentId,
      'reportDate': widget.reportDate,
      'submit': true,
      ..._values,
      'inpatients': l1 + l2 + l3,
      'inpatientsCareLevel1': l1,
      'inpatientsCareLevel2': l2,
      'inpatientsCareLevel3': l3,
    };
  }

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
                              if (section.step == '02') ...[
                                // Khối nội trú là thẻ lồng trong nhóm 02 — chừa đệm
                                // để không dính sát đường kẻ và hai mép thẻ cha.
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    6,
                                  ),
                                  child: InpatientCareLevelAccordion(
                                    level1:
                                        _values['inpatientsCareLevel1'] ?? 0,
                                    level2:
                                        _values['inpatientsCareLevel2'] ?? 0,
                                    level3:
                                        _values['inpatientsCareLevel3'] ?? 0,
                                    enabled: !_readOnly,
                                    onChanged: (next) => setState(() {
                                      _values['inpatientsCareLevel1'] =
                                          next.level1;
                                      _values['inpatientsCareLevel2'] =
                                          next.level2;
                                      _values['inpatientsCareLevel3'] =
                                          next.level3;
                                      _values['inpatients'] =
                                          next.level1 +
                                          next.level2 +
                                          next.level3;
                                    }),
                                  ),
                                ),
                              ],
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
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
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
                Row(
                  children: [
                    if (canRecall) ...[
                      Expanded(
                        flex: 2,
                        child: AppActionButton(
                          variant: AppActionVariant.outlineDanger,
                          icon: Icons.undo_rounded,
                          label: 'Thu hồi',
                          onPressed: saving ? null : onRecall,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      flex: 3,
                      child: AppActionButton(
                        variant: canEdit
                            ? AppActionVariant.primary
                            : AppActionVariant.outlineNeutral,
                        icon: canEdit
                            ? Icons.edit_rounded
                            : Icons.lock_outline_rounded,
                        label: canEdit
                            ? 'Chỉnh sửa báo cáo'
                            : 'Bạn chỉ có quyền xem',
                        onPressed: canEdit ? onEnableEdit : null,
                      ),
                    ),
                  ],
                ),
              ] else
                AppActionButton(
                  variant: AppActionVariant.primary,
                  icon: dirty || !editing
                      ? Icons.cloud_upload_rounded
                      : Icons.cloud_done_rounded,
                  label: saving
                      ? 'Đang đồng bộ…'
                      : (editing ? 'Cập nhật báo cáo' : 'Gửi báo cáo'),
                  loading: saving,
                  onPressed: onSave,
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

  /// Tên in hoa toàn bộ → viết hoa đầu chữ ("KHOA SẢN" → "Khoa Sản").
  static String _pretty(String raw) {
    final t = raw.trim();
    final letters = t.replaceAll(RegExp(r'[^A-Za-zÀ-ỹ]'), '');
    if (letters.isEmpty || letters != letters.toUpperCase()) return t;
    return t
        .toLowerCase()
        .split(' ')
        .map(
          (w) => w.isEmpty
              ? w
              : '${w.characters.first.toUpperCase()}${w.substring(w.characters.first.length)}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final report = existing;
    final incidentCount = report?.safetyIncidents ?? 0;
    // Trên nền teal: bạc hà = đã nộp, vàng = đang nhập.
    final statusTone = readOnly
        ? AppColors.onBrandRing
        : const Color(0xFFFCD34D);
    final updatedBy = report?.updatedByUsername ?? report?.createdByUsername;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.brXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brXl,
        child: GradientHeader(
          safeAreaTop: false,
          bottomRadius: 0,
          gradient: AppGradients.brandHero,
          ornamentIcon: Icons.local_hospital_rounded,
          ornamentScale: 0.8,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.30),
                          Colors.white.withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pretty(departmentName),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.35,
                            height: AppTypography.uppercaseHeight,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                dateLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.style(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  tabular: true,
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.16),
                      borderRadius: AppRadius.brPill,
                      border: Border.all(
                        color: statusTone.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusTone,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: statusTone.withValues(alpha: 0.6),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          readOnly ? 'Đã nộp' : 'Đang nhập',
                          style: AppTypography.style(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            height: AppTypography.uppercaseHeight,
                            color: Colors.white,
                          ),
                        ),
                      ],
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
                      color: AppColors.onBrandRing,
                    ),
                    const SizedBox(width: 8),
                    _MiniMetric(
                      label: 'Nội trú',
                      value: '${report.inpatients}',
                      color: const Color(0xFF93C5FD),
                    ),
                    const SizedBox(width: 8),
                    _MiniMetric(
                      label: 'Sự cố',
                      value: '$incidentCount',
                      color: incidentCount > 0
                          ? const Color(0xFFFCA5A5)
                          : AppColors.onBrandRing,
                    ),
                  ],
                ),
                if (updatedBy != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.65),
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
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ô chỉ số kính trên nền brand: chấm sắc + nhãn in hoa, số lớn bên dưới.
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
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.14),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: AppRadius.brBase,
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.uppercase(
                      fontSize: 8.5,
                      letterSpacing: 0.5,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: AppTypography.display(fontSize: 19, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
