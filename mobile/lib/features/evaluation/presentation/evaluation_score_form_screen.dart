import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../shared/models/nursing_evaluation.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../employees/data/employee_repository.dart';
import '../application/evaluation_controller.dart';
import '../data/evaluation_repository.dart';
import 'evaluation_enums.dart';

class EvaluationScoreFormScreen extends ConsumerStatefulWidget {
  const EvaluationScoreFormScreen({
    super.key,
    required this.employeeId,
    required this.year,
    required this.month,
    this.employeeName,
  });

  final int employeeId;
  final int year;
  final int month;
  final String? employeeName;

  @override
  ConsumerState<EvaluationScoreFormScreen> createState() =>
      _EvaluationScoreFormScreenState();
}

class _EvaluationScoreFormScreenState
    extends ConsumerState<EvaluationScoreFormScreen> {
  NursingEvalTemplate? _template;
  final Map<String, double?> _points = {};
  final _comments = TextEditingController();
  NursingEvalAttendanceStats? _att;
  String? _attErr;
  String? _employeeLabel;
  String? _deptLabel;
  String? _positionLabel;
  String? _existingStatus;
  bool _loading = true;
  bool _saving = false;
  bool _noteExpanded = false;
  bool _attExpanded = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _employeeLabel = widget.employeeName;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _comments.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final evalRepo = ref.read(evaluationRepositoryProvider);
      final attRepo = ref.read(attendanceRepositoryProvider);
      final empRepo = ref.read(employeeRepositoryProvider);

      final templateFuture = evalRepo.template();
      final historyFuture = evalRepo.forEmployee(widget.employeeId);
      final empFuture = empRepo.detail(widget.employeeId).then<void>((d) {
        _employeeLabel ??= d.summary.fullName;
        _deptLabel ??= d.summary.departmentName;
        _positionLabel ??= d.summary.positionTitle;
      }).catchError((_) {});

      final template = await templateFuture;
      await empFuture;
      final history = await historyFuture;

      NursingEvaluationRecord? match;
      for (final r in history) {
        if (r.periodYear == widget.year &&
            r.periodMonth == widget.month &&
            r.templateCode == template.code) {
          match = r;
          break;
        }
      }

      for (final c in template.criteriaGroups) {
        _points[c.id] = c.isExtra ? 0 : null;
      }
      if (match != null) {
        for (final c in template.criteriaGroups) {
          final p = match.scorePoints(c.id);
          if (p != null) _points[c.id] = p;
        }
        _comments.text = match.comments ?? '';
        _existingStatus = match.status;
        _employeeLabel ??= match.employeeName;
        _deptLabel ??= match.departmentName;
        _positionLabel ??= match.positionTitle;
      }

      NursingEvalAttendanceStats? att;
      String? attErr;
      try {
        final detail = await attRepo.monthDetail(
          widget.employeeId,
          widget.year,
          widget.month,
        );
        final days = detail.days;
        final lateEarlyTimes = days
            .where((d) => !d.lateMinutesExempt && d.lateMinutes > 0)
            .length;
        final total = _roundWu(detail.summary.totalWorkUnits);
        final missing =
            _roundWu((kEvalStandardMonthWorkUnits - total).clamp(0, 999));
        att = NursingEvalAttendanceStats(
          totalWorkUnits: total,
          lateMinutesTotal: detail.summary.lateMinutesTotal,
          lateEarlyTimes: lateEarlyTimes,
          missingWorkUnits: missing,
          isShortWork: total < kEvalStandardMonthWorkUnits - 0.001,
        );
      } catch (_) {
        attErr = 'Không tải được thống kê công tháng này.';
      }

      if (!mounted) return;
      setState(() {
        _template = template;
        _att = att;
        _attErr = attErr;
        _attExpanded = att?.isShortWork == true;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được mẫu đánh giá';
      });
    }
  }

  double _roundWu(num n) => (n * 100).round() / 100;

  List<NursingEvalCriterion> get _groups =>
      _template?.criteriaGroups ?? const [];

  int get _filled {
    var n = 0;
    for (final g in _groups) {
      if (g.isExtra) continue;
      if (_points[g.id] != null) n++;
    }
    return n;
  }

  int get _required {
    var n = 0;
    for (final g in _groups) {
      if (!g.isExtra) n++;
    }
    return n;
  }

  double get _previewTotal {
    var base = 0.0;
    var bonus = 0.0;
    var penalty = 0.0;
    for (final g in _groups) {
      final v = _points[g.id];
      if (v == null) continue;
      if (g.bonus) {
        bonus += v;
      } else if (g.penalty) {
        penalty += v;
      } else {
        base += v;
      }
    }
    return (base + bonus - penalty).clamp(0, 999);
  }

  Future<void> _pickPoints(NursingEvalCriterion c) async {
    final selected = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: AppRadius.brPill,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Chọn mức điểm',
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.title,
                  style: AppTypography.style(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final opt in c.options)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: (_points[c.id] == opt.points)
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : AppColors.surfaceMuted,
                            borderRadius: AppRadius.brMd,
                            child: InkWell(
                              onTap: () => Navigator.pop(ctx, opt.points),
                              borderRadius: AppRadius.brMd,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: AppRadius.brSm,
                                      ),
                                      child: Text(
                                        AppFormat.compactNumber(opt.points),
                                        style: AppTypography.metric(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        opt.label,
                                        style: AppTypography.style(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                    if (_points[c.id] == opt.points)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    setState(() => _points[c.id] = selected);
  }

  Future<void> _save(bool submitForReview) async {
    final auth = ref.read(authControllerProvider);
    if (!RoleGroups.canScoreNursingEval(auth.role)) {
      showAppSnackBar(
        context,
        'Chỉ Trưởng khoa / ĐDT khoa được lập phiếu đánh giá.',
        isError: true,
      );
      return;
    }
    if (submitForReview && auth.currentUser?.hasSignature != true) {
      final go = await showConfirmDialog(
        context,
        title: 'Cần chữ ký số',
        message:
            'Gửi duyệt yêu cầu chữ ký số. Vào Hồ sơ để thiết lập chữ ký trước.',
        confirmLabel: 'Đến chữ ký',
        icon: Icons.draw_outlined,
      );
      if (go && mounted) context.push(RoutePaths.profileSignature);
      return;
    }

    for (final g in _groups) {
      if (_points[g.id] == null) {
        showAppSnackBar(context, 'Thiếu điểm: ${g.title}', isError: true);
        return;
      }
    }

    if (submitForReview) {
      final ok = await showConfirmDialog(
        context,
        title: 'Gửi Trưởng phòng ĐD duyệt',
        message:
            'Chữ ký của bạn sẽ được gắn vào phiếu và chuyển sang bước duyệt tiếp theo.',
        confirmLabel: 'Gửi duyệt',
        icon: Icons.send_rounded,
      );
      if (!ok) return;
    }

    setState(() => _saving = true);
    try {
      final scores = <String, num>{
        for (final g in _groups) g.id: _points[g.id]!,
      };
      await ref.read(evaluationRepositoryProvider).submit(
            employeeId: widget.employeeId,
            periodYear: widget.year,
            periodMonth: widget.month,
            scores: scores,
            comments: _comments.text.trim().isEmpty
                ? null
                : _comments.text.trim(),
            submitForReview: submitForReview,
          );
      await ref.read(evaluationControllerProvider.notifier).refreshQuietly();
      if (!mounted) return;
      showAppSnackBar(
        context,
        submitForReview
            ? 'Đã gửi Trưởng phòng ĐD duyệt'
            : 'Đã lưu nháp',
        isSuccess: true,
      );
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Lưu phiếu thất bại', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = _template;
    final progress =
        _required == 0 ? 0 : ((_filled / _required) * 100).round();
    final periodLabel =
        'Tháng ${widget.month.toString().padLeft(2, '0')}/${widget.year}';
    final onBrand = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.5)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: 'Chấm đánh giá',
                icon: Icons.edit_note_rounded,
                eyebrow: 'Mẫu MA 2026',
                subtitle: periodLabel,
                onBack: () => context.pop(),
                footer: _HeaderProgress(
                  filled: _filled,
                  requiredCount: _required,
                  progress: progress,
                  preview: _previewTotal,
                  onBrand: onBrand,
                ),
              ),
              Expanded(
                child: _loading
                    ? const LoadingState(label: 'Đang tải mẫu đánh giá…')
                    : _error != null
                        ? ErrorState(message: _error!, onRetry: _bootstrap)
                        : template == null
                            ? const EmptyState(
                                icon: Icons.fact_check_outlined,
                                title: 'Không có mẫu',
                                message: 'Không tải được tiêu chí đánh giá.',
                              )
                            : Column(
                                children: [
                                  Expanded(
                                    child: ListView(
                                      padding: const EdgeInsets.fromLTRB(
                                        AppSpacing.page,
                                        12,
                                        AppSpacing.page,
                                        20,
                                      ),
                                      children: [
                                        _EmployeeCard(
                                          name: _employeeLabel ?? 'Nhân viên',
                                          meta: [
                                            if ((_deptLabel ?? '').isNotEmpty)
                                              _deptLabel!,
                                            if ((_positionLabel ?? '')
                                                .isNotEmpty)
                                              _positionLabel!,
                                          ].join(' · '),
                                          status: _existingStatus,
                                        ),
                                        const SizedBox(height: 10),
                                        if (_att != null || _attErr != null)
                                          _AttendanceCard(
                                            stats: _att,
                                            error: _attErr,
                                            expanded: _attExpanded,
                                            onToggle: () => setState(
                                              () => _attExpanded =
                                                  !_attExpanded,
                                            ),
                                          ),
                                        if (template.note.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          _NoteCard(
                                            note: template.note,
                                            expanded: _noteExpanded,
                                            onToggle: () => setState(
                                              () => _noteExpanded =
                                                  !_noteExpanded,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 16),
                                        for (final section
                                            in _sections(template)) ...[
                                          _SectionBlock(
                                            title: section.$1,
                                            maxPoints: section.$2,
                                            children: [
                                              for (final c in section.$3)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    bottom: 8,
                                                  ),
                                                  child: _CriterionTile(
                                                    criterion: c,
                                                    points: _points[c.id],
                                                    onTap: _saving
                                                        ? null
                                                        : () =>
                                                            _pickPoints(c),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        Text(
                                          'NHẬN XÉT CHUNG',
                                          style: AppTypography.style(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.7,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: _comments,
                                          minLines: 3,
                                          maxLines: 5,
                                          enabled: !_saving,
                                          style: AppTypography.body(
                                            fontSize: 14,
                                          ),
                                          decoration: InputDecoration(
                                            hintText:
                                                'Nhận xét của Trưởng khoa / ĐDT…',
                                            filled: true,
                                            fillColor: AppColors.surface,
                                            border: OutlineInputBorder(
                                              borderRadius: AppRadius.brMd,
                                              borderSide: const BorderSide(
                                                color: AppColors.borderSoft,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: AppRadius.brMd,
                                              borderSide: const BorderSide(
                                                color: AppColors.borderSoft,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _BottomBar(
                                    preview: _previewTotal,
                                    progress: progress,
                                    saving: _saving,
                                    onDraft: () => _save(false),
                                    onSubmit: () => _save(true),
                                  ),
                                ],
                              ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<(String, double?, List<NursingEvalCriterion>)> _sections(
    NursingEvalTemplate template,
  ) {
    final map = <String, List<NursingEvalCriterion>>{};
    final points = <String, double?>{};
    for (final c in template.criteriaGroups) {
      map.putIfAbsent(c.section, () => []).add(c);
      points.putIfAbsent(c.section, () => c.sectionPoints);
    }
    return [
      for (final e in map.entries) (e.key, points[e.key], e.value),
    ];
  }
}

class _HeaderProgress extends StatelessWidget {
  const _HeaderProgress({
    required this.filled,
    required this.requiredCount,
    required this.progress,
    required this.preview,
    required this.onBrand,
  });

  final int filled;
  final int requiredCount;
  final int progress;
  final double preview;
  final Color onBrand;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: onBrand.withValues(alpha: 0.14),
        borderRadius: AppRadius.brMd,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                AppFormat.compactNumber(preview),
                style: AppTypography.metric(
                  fontSize: 22,
                  color: onBrand,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'điểm · $filled/$requiredCount tiêu chí',
                style: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: onBrand.withValues(alpha: 0.88),
                ),
              ),
              const Spacer(),
              Text(
                '$progress%',
                style: AppTypography.style(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: onBrand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: AppRadius.brPill,
            child: LinearProgressIndicator(
              value: requiredCount == 0 ? 0 : filled / requiredCount,
              minHeight: 5,
              backgroundColor: onBrand.withValues(alpha: 0.18),
              color: onBrand,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.name,
    required this.meta,
    this.status,
  });

  final String name;
  final String meta;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final statusLabel = (status == null || status!.isEmpty || status == 'NONE')
        ? 'Chưa có phiếu'
        : EvaluationEnums.statusLabel(status!);
    final statusColor = EvaluationEnums.statusColor(status ?? 'NONE');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          AppAvatar(name: name, size: 48, showShadow: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.stats,
    required this.error,
    required this.expanded,
    required this.onToggle,
  });

  final NursingEvalAttendanceStats? stats;
  final String? error;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final short = stats?.isShortWork == true;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(
          color: short
              ? AppColors.warning.withValues(alpha: 0.35)
              : AppColors.borderSoft,
        ),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                child: Row(
                  children: [
                    Icon(
                      short
                          ? Icons.warning_amber_rounded
                          : Icons.calendar_month_rounded,
                      size: 18,
                      color: short
                          ? AppColors.warningDark
                          : AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        short
                            ? 'Thiếu công — xem thống kê'
                            : 'Thống kê công tháng',
                        style: AppTypography.style(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: short
                              ? AppColors.warningDark
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (stats != null)
                      Text(
                        AppFormat.workUnits(stats!.totalWorkUnits),
                        style: AppTypography.metric(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: AppDurations.fast,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: AppColors.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: error != null
                  ? Text(
                      error!,
                      style: AppTypography.style(
                        fontSize: 13,
                        color: AppColors.warningDark,
                      ),
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _AttTile(
                                label: 'Số công',
                                value:
                                    '${AppFormat.workUnits(stats!.totalWorkUnits)} / ${AppFormat.workUnits(kEvalStandardMonthWorkUnits)}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _AttTile(
                                label: 'Phút muộn',
                                value: '${stats!.lateMinutesTotal}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _AttTile(
                                label: 'Lần muộn',
                                value: '${stats!.lateEarlyTimes}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _AttTile(
                                label: 'Thiếu công',
                                value: short
                                    ? AppFormat.workUnits(
                                        stats!.missingWorkUnits,
                                      )
                                    : '0',
                                warn: short,
                              ),
                            ),
                          ],
                        ),
                        if (short) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Lưu ý khi chấm tiêu chí tuân thủ thời gian làm việc (I.1).',
                            style: AppTypography.style(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warningDark,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttTile extends StatelessWidget {
  const _AttTile({
    required this.label,
    required this.value,
    this.warn = false,
  });

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: warn ? AppColors.warningLight : AppColors.surfaceMuted,
        borderRadius: AppRadius.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: warn ? AppColors.warningDark : AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.expanded,
    required this.onToggle,
  });

  final String note;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.infoLight,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onToggle,
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.infoDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lưu ý khi xếp loại',
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.infoDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      note,
                      maxLines: expanded ? 12 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.infoDark.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expanded ? 'Thu gọn' : 'Xem đầy đủ',
                      style: AppTypography.style(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    required this.maxPoints,
    required this.children,
  });

  final String title;
  final double? maxPoints;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: AppTypography.style(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            if (maxPoints != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.brPill,
                ),
                child: Text(
                  'Tối đa ${AppFormat.compactNumber(maxPoints)}',
                  style: AppTypography.style(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _CriterionTile extends StatelessWidget {
  const _CriterionTile({
    required this.criterion,
    required this.points,
    required this.onTap,
  });

  final NursingEvalCriterion criterion;
  final double? points;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    String? selectedLabel;
    if (points != null) {
      for (final o in criterion.options) {
        if ((o.points - points!).abs() < 0.001) {
          selectedLabel = o.label;
          break;
        }
      }
    }
    final filled = points != null && !criterion.isExtra
        ? true
        : points != null && criterion.isExtra;

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: filled && !criterion.isExtra
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.borderSoft,
            ),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (filled && !criterion.isExtra)
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  criterion.no.isEmpty ? '•' : criterion.no,
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: (filled && !criterion.isExtra)
                        ? Colors.white
                        : AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      criterion.title,
                      style: AppTypography.style(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedLabel ??
                          (criterion.isExtra
                              ? 'Mặc định 0 — chạm để đổi'
                              : 'Chạm để chọn điểm'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 12,
                        height: 1.35,
                        color: selectedLabel == null
                            ? AppColors.textTertiary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: points == null && !criterion.isExtra
                          ? AppColors.surfaceMuted
                          : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Text(
                      points == null
                          ? '—'
                          : AppFormat.compactNumber(points),
                      textAlign: TextAlign.center,
                      style: AppTypography.metric(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: points == null && !criterion.isExtra
                            ? AppColors.textTertiary
                            : AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.unfold_more_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.preview,
    required this.progress,
    required this.saving,
    required this.onDraft,
    required this.onSubmit,
  });

  final double preview;
  final int progress;
  final bool saving;
  final VoidCallback onDraft;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.98),
          boxShadow: AppShadows.nav,
          border: const Border(
            top: BorderSide(color: AppColors.borderSoft),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Tạm tính',
                  style: AppTypography.style(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${AppFormat.compactNumber(preview)} điểm',
                  style: AppTypography.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                Text(
                  '  ·  $progress%',
                  style: AppTypography.style(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : onDraft,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Lưu nháp'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: saving ? null : onSubmit,
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(saving ? 'Đang gửi…' : 'Gửi duyệt'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
