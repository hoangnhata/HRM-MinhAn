import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/widgets/tinted_card_backdrop.dart';
import '../../../core/widgets/app_action_button.dart';

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
      final empFuture = empRepo
          .detail(widget.employeeId)
          .then<void>((d) {
            _employeeLabel ??= d.summary.fullName;
            _deptLabel ??= d.summary.departmentName;
            _positionLabel ??= d.summary.positionTitle;
          })
          .catchError((_) {});

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
        final missing = _roundWu(
          (kEvalStandardMonthWorkUnits - total).clamp(0, 999),
        );
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
      // Sheet tự vẽ thanh kéo — tắt thanh mặc định của theme để không bị trùng.
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSheetTop),
      builder: (ctx) =>
          _PointsPickerSheet(criterion: c, current: _points[c.id]),
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
      await ref
          .read(evaluationRepositoryProvider)
          .submit(
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
        submitForReview ? 'Đã gửi Trưởng phòng ĐD duyệt' : 'Đã lưu nháp',
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
    final progress = _required == 0 ? 0 : ((_filled / _required) * 100).round();
    final periodLabel =
        'Tháng ${widget.month.toString().padLeft(2, '0')}/${widget.year}';

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
                                  dept: (_deptLabel ?? '').trim(),
                                  role: (_positionLabel ?? '').trim(),
                                  status: _existingStatus,
                                ),
                                const SizedBox(height: 10),
                                if (_att != null || _attErr != null)
                                  _AttendanceCard(
                                    stats: _att,
                                    error: _attErr,
                                    expanded: _attExpanded,
                                    onToggle: () => setState(
                                      () => _attExpanded = !_attExpanded,
                                    ),
                                  ),
                                if (template.note.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  _NoteCard(
                                    note: template.note,
                                    expanded: _noteExpanded,
                                    onToggle: () => setState(
                                      () => _noteExpanded = !_noteExpanded,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                for (final section in _sections(template)) ...[
                                  _SectionBlock(
                                    title: section.$1,
                                    maxPoints: section.$2,
                                    children: [
                                      for (final c in section.$3)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: _CriterionTile(
                                            criterion: c,
                                            points: _points[c.id],
                                            onTap: _saving
                                                ? null
                                                : () => _pickPoints(c),
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
                                  style: AppTypography.body(fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Nhận xét của Trưởng khoa / ĐDT…',
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
    return [for (final e in map.entries) (e.key, points[e.key], e.value)];
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.name,
    required this.dept,
    required this.role,
    this.status,
  });

  final String name;
  final String dept;
  final String role;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final isNone = status == null || status!.isEmpty || status == 'NONE';
    final statusLabel = isNone
        ? 'Chưa có phiếu'
        : EvaluationEnums.statusLabel(status!);
    final statusColor = isNone
        ? AppColors.textSecondary
        : EvaluationEnums.statusColor(status!);
    // Chưa có phiếu = đang lập mới → sắc teal; còn lại theo trạng thái phiếu.
    final accent = isNone ? AppColors.primary : statusColor;

    return Container(
      decoration: BoxDecoration(
        gradient: TintedCardBackdrop.gradient(accent),
        borderRadius: AppRadius.brLg,
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: TintedCardBackdrop(
        accent: accent,
        watermarkIcon: Icons.badge_rounded,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 56,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: 0.65),
                            accent.withValues(alpha: 0.12),
                          ],
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                        ),
                        child: AppAvatar(
                          name: name,
                          size: 48,
                          showShadow: false,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NHÂN VIÊN ĐƯỢC ĐÁNH GIÁ',
                      style: AppTypography.uppercase(
                        fontSize: 9,
                        letterSpacing: 0.8,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                        height: AppTypography.uppercaseHeight,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (role.isNotEmpty || dept.isNotEmpty)
                      Text.rich(
                        TextSpan(
                          children: [
                            if (role.isNotEmpty)
                              TextSpan(
                                text: role,
                                style: AppTypography.style(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            if (role.isNotEmpty && dept.isNotEmpty)
                              const TextSpan(text: '  ·  '),
                            if (dept.isNotEmpty) TextSpan(text: dept),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: AppRadius.brChip,
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            statusLabel,
                            style: AppTypography.style(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              height: AppTypography.uppercaseHeight,
                              color: Color.lerp(
                                statusColor,
                                AppColors.textPrimary,
                                0.25,
                              ),
                            ),
                          ),
                        ],
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
    final s = stats;
    final short = s?.isShortWork == true;
    final tone = short ? AppColors.warning : AppColors.primary;
    final ink = short ? AppColors.warningDark : AppColors.primaryDark;
    final ratio = s == null
        ? 0.0
        : (s.totalWorkUnits / kEvalStandardMonthWorkUnits).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: TintedCardBackdrop.gradient(tone),
        borderRadius: AppRadius.brLg,
        border: Border.all(color: tone.withValues(alpha: short ? 0.28 : 0.14)),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        TintedIconTile(
                          icon: short
                              ? Icons.warning_amber_rounded
                              : Icons.calendar_month_rounded,
                          color: tone,
                          size: 36,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                short ? 'Thiếu công trong tháng' : 'Công tháng',
                                style: AppTypography.style(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  height: AppTypography.uppercaseHeight,
                                  color: short ? ink : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                expanded
                                    ? 'Chạm để thu gọn'
                                    : 'Chạm để xem thống kê chi tiết',
                                style: AppTypography.style(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  height: AppTypography.uppercaseHeight,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (s != null) ...[
                          const SizedBox(width: 8),
                          Text.rich(
                            TextSpan(
                              text: AppFormat.workUnits(s.totalWorkUnits),
                              style: AppTypography.display(
                                fontSize: 18,
                                color: ink,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      ' / ${AppFormat.workUnits(kEvalStandardMonthWorkUnits)}',
                                  style: AppTypography.style(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textTertiary,
                                    tabular: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: AppDurations.fast,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: tone.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (s != null) ...[
                      const SizedBox(height: 10),
                      // Số công / chuẩn tháng — thấy ngay mức thiếu khi chưa mở.
                      Container(
                        height: 7,
                        decoration: BoxDecoration(
                          color: tone.withValues(alpha: 0.12),
                          borderRadius: AppRadius.brPill,
                        ),
                        alignment: Alignment.centerLeft,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: ratio),
                          duration: AppDurations.slow,
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => FractionallySizedBox(
                            heightFactor: 1,
                            widthFactor: v <= 0 ? 0 : v.clamp(0.02, 1.0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: AppRadius.brPill,
                                gradient: LinearGradient(
                                  colors: [
                                    Color.lerp(tone, Colors.white, 0.3)!,
                                    tone,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: AppDurations.normal,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !expanded
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: error != null
                          ? _AttNote(text: error!, tone: AppColors.warning)
                          : s == null
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _AttTile(
                                        icon: Icons.timer_outlined,
                                        label: 'Phút muộn',
                                        value: '${s.lateMinutesTotal}',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _AttTile(
                                        icon: Icons.history_toggle_off_rounded,
                                        label: 'Lần muộn/sớm',
                                        value: '${s.lateEarlyTimes}',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _AttTile(
                                        icon: Icons.event_busy_rounded,
                                        label: 'Thiếu công',
                                        value: short
                                            ? AppFormat.workUnits(
                                                s.missingWorkUnits,
                                              )
                                            : '0',
                                        warn: short,
                                      ),
                                    ),
                                  ],
                                ),
                                if (short) ...[
                                  const SizedBox(height: 10),
                                  const _AttNote(
                                    text:
                                        'Lưu ý khi chấm tiêu chí tuân thủ thời gian làm việc (I.1).',
                                    tone: AppColors.warning,
                                  ),
                                ],
                              ],
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô chỉ số công: icon + nhãn in hoa, số lớn; ô cảnh báo pha cam.
class _AttTile extends StatelessWidget {
  const _AttTile({
    required this.icon,
    required this.label,
    required this.value,
    this.warn = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final tone = warn ? AppColors.warning : AppColors.primary;
    final ink = warn ? AppColors.warningDark : AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 10),
      decoration: BoxDecoration(
        color: warn
            ? Color.alphaBlend(
                AppColors.warning.withValues(alpha: 0.10),
                AppColors.surface,
              )
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: AppRadius.brBase,
        border: Border.all(color: tone.withValues(alpha: warn ? 0.3 : 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: tone),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.uppercase(
                    fontSize: 8.5,
                    letterSpacing: 0.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            style: AppTypography.display(fontSize: 18, color: ink),
          ),
        ],
      ),
    );
  }
}

/// Khung lưu ý: icon + chữ trên nền pha màu, vạch nhấn bên trái.
class _AttNote extends StatelessWidget {
  const _AttNote({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: AppRadius.brControl,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: tone),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 8, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: Color.lerp(tone, AppColors.textPrimary, 0.3),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        text,
                        style: AppTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: Color.lerp(tone, AppColors.textPrimary, 0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.brPill,
                ),
                child: Text(
                  'Tối đa ${AppFormat.score(maxPoints)}',
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
                      points == null ? '—' : AppFormat.score(points),
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

/// Sheet chọn mức điểm cho một tiêu chí: header có số thứ tự + điểm tối đa,
/// các mức là thẻ radio — mức đang chọn nổi bằng nền pha teal, viền và bóng.
class _PointsPickerSheet extends StatelessWidget {
  const _PointsPickerSheet({required this.criterion, required this.current});

  final NursingEvalCriterion criterion;
  final double? current;

  @override
  Widget build(BuildContext context) {
    final c = criterion;
    final kind = c.penalty
        ? ('Điểm trừ', AppColors.error, Icons.remove_circle_outline_rounded)
        : c.bonus
        ? ('Điểm cộng', AppColors.success, Icons.add_circle_outline_rounded)
        : null;

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
                decoration: const BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: AppRadius.brPill,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'CHỌN MỨC ĐIỂM',
                  style: AppTypography.uppercase(
                    fontSize: 10,
                    letterSpacing: 0.9,
                    color: AppColors.textTertiary,
                  ),
                ),
                const Spacer(),
                if (kind != null) ...[
                  _SheetPill(label: kind.$1, color: kind.$2, icon: kind.$3),
                  const SizedBox(width: 6),
                ],
                if (c.maxPoints != null)
                  _SheetPill(
                    label: 'Tối đa ${AppFormat.score(c.maxPoints)} đ',
                    color: AppColors.primary,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.no.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppGradients.brand,
                      borderRadius: AppRadius.brChip,
                      boxShadow: AppShadows.tinted(AppColors.primary),
                    ),
                    child: Text(
                      c.no,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        tabular: true,
                        height: AppTypography.uppercaseHeight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    c.title,
                    style: AppTypography.style(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (c.section.isNotEmpty && c.section != 'Khác') ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.folder_outlined,
                    size: 13,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      c.section,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: AppTypography.uppercaseHeight,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final opt in c.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PointsOption(
                        points: opt.points,
                        label: opt.label,
                        selected: current == opt.points,
                        penalty: c.penalty,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context, opt.points);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetPill extends StatelessWidget {
  const _SheetPill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ink = Color.lerp(color, AppColors.textPrimary, 0.2)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: ink),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ink,
              height: AppTypography.uppercaseHeight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Một mức điểm dạng thẻ radio.
class _PointsOption extends StatelessWidget {
  const _PointsOption({
    required this.points,
    required this.label,
    required this.selected,
    required this.penalty,
    required this.onTap,
  });

  final double points;
  final String label;
  final bool selected;
  final bool penalty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = penalty && points > 0 ? AppColors.error : AppColors.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: '${AppFormat.score(points)} điểm, $label',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: selected ? TintedCardBackdrop.gradient(tone) : null,
          color: selected ? null : AppColors.surface,
          borderRadius: AppRadius.brCard,
          border: Border.all(
            color: selected ? tone.withValues(alpha: 0.55) : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? AppShadows.tinted(tone) : AppShadows.soft,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brCard,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: AppDurations.fast,
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: selected
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.lerp(tone, Colors.white, 0.12)!,
                                Color.lerp(tone, Colors.black, 0.12)!,
                              ],
                            )
                          : null,
                      color: selected ? null : tone.withValues(alpha: 0.08),
                      borderRadius: AppRadius.brBase,
                    ),
                    child: Text(
                      '${penalty && points > 0 ? '−' : ''}${AppFormat.score(points)}',
                      style: AppTypography.display(
                        fontSize: 18,
                        color: selected
                            ? Colors.white
                            : Color.lerp(tone, AppColors.textPrimary, 0.2)!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.style(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Radio: vòng rỗng → đĩa đặc có dấu ✓.
                  AnimatedContainer(
                    duration: AppDurations.fast,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? tone : Colors.transparent,
                      border: Border.all(
                        color: selected ? tone : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
            ),
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
    final ratio = (progress / 100).clamp(0.0, 1.0);
    final done = progress >= 100;
    final tone = done ? AppColors.success : AppColors.primary;

    return DecoratedBox(
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Khối tạm tính: điểm hiện tại + tiến độ chấm các tiêu chí.
              Container(
                padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
                decoration: BoxDecoration(
                  gradient: TintedCardBackdrop.gradient(tone),
                  borderRadius: AppRadius.brCard,
                  border: Border.all(color: tone.withValues(alpha: 0.14)),
                ),
                child: Row(
                  children: [
                    TintedIconTile(
                      icon: done
                          ? Icons.task_alt_rounded
                          : Icons.calculate_rounded,
                      color: tone,
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TẠM TÍNH',
                            style: AppTypography.uppercase(
                              fontSize: 9.5,
                              letterSpacing: 0.9,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                AppFormat.score(preview),
                                style: AppTypography.display(
                                  fontSize: 22,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'điểm',
                                style: AppTypography.style(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 104,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: done ? 'Đã chấm đủ ' : 'Đã chấm ',
                              children: [
                                TextSpan(
                                  text: '$progress%',
                                  style: AppTypography.style(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color.lerp(
                                      tone,
                                      AppColors.textPrimary,
                                      0.2,
                                    ),
                                    tabular: true,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            style: AppTypography.style(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: tone.withValues(alpha: 0.12),
                              borderRadius: AppRadius.brPill,
                            ),
                            alignment: Alignment.centerLeft,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: ratio),
                              duration: AppDurations.normal,
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) => FractionallySizedBox(
                                heightFactor: 1,
                                widthFactor: v,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: AppRadius.brPill,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color.lerp(tone, Colors.white, 0.3)!,
                                        tone,
                                      ],
                                    ),
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: AppActionButton(
                      variant: AppActionVariant.outlineNeutral,
                      icon: Icons.save_outlined,
                      label: 'Lưu nháp',
                      onPressed: saving ? null : onDraft,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 3,
                    child: AppActionButton(
                      variant: AppActionVariant.primary,
                      icon: Icons.send_rounded,
                      label: saving ? 'Đang gửi…' : 'Gửi duyệt',
                      loading: saving,
                      onPressed: onSubmit,
                    ),
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
