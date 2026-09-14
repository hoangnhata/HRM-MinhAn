import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/app_option_picker.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/qtkt_models.dart';
import '../data/qtkt_repository.dart';

class QtktEvaluationFormScreen extends ConsumerStatefulWidget {
  const QtktEvaluationFormScreen({
    super.key,
    required this.template,
    required this.employees,
    required this.monthEvaluations,
    required this.canEdit,
    this.existing,
  });

  final QtktTemplate template;
  final List<QtktEmployee> employees;
  final List<QtktEvaluation> monthEvaluations;
  final bool canEdit;
  final QtktEvaluation? existing;

  @override
  ConsumerState<QtktEvaluationFormScreen> createState() =>
      _QtktEvaluationFormScreenState();
}

class _QtktEvaluationFormScreenState
    extends ConsumerState<QtktEvaluationFormScreen> {
  QtktEmployee? _employee;
  QtktProcedure? _procedure;
  String? _checkContextCode;
  late DateTime _evalDate;
  late Map<String, double> _scores;
  late Map<String, double> _initialScores;
  late final TextEditingController _noteController;
  late final TextEditingController _patientCodeController;
  late String _initialNote;
  late String _initialPatientCode;
  bool _saving = false;
  bool _allowPop = false;

  bool get _readOnly =>
      !widget.canEdit ||
      widget.existing?.status == QtktEvaluationStatus.cancelled ||
      (widget.existing?.status == QtktEvaluationStatus.submitted &&
          widget.existing?.canEdit != true);

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _evalDate = DateTime.tryParse(existing?.evalDate ?? '') ?? DateTime.now();
    if (existing != null) {
      _employee =
          _findEmployee(existing.employeeId) ??
          QtktEmployee(
            id: existing.employeeId,
            fullName: existing.employeeName,
            employeeCode: existing.employeeCode,
            departmentId: existing.departmentId,
            departmentName: existing.departmentName,
          );
      _procedure = widget.template.procedureByCode(existing.procedureCode);
      _checkContextCode = existing.checkContextCode;
    }
    _scores = _scoresFor(_procedure, existing?.scores);
    _initialScores = Map<String, double>.from(_scores);
    _initialNote = existing?.note ?? '';
    _initialPatientCode = existing?.patientCode ?? '';
    _noteController = TextEditingController(text: _initialNote)
      ..addListener(_onNoteChanged);
    _patientCodeController = TextEditingController(text: _initialPatientCode)
      ..addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteController
      ..removeListener(_onNoteChanged)
      ..dispose();
    _patientCodeController
      ..removeListener(_onNoteChanged)
      ..dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    if (mounted) setState(() {});
  }

  QtktEmployee? _findEmployee(int id) {
    for (final employee in widget.employees) {
      if (employee.id == id) return employee;
    }
    return null;
  }

  Map<String, double> _scoresFor(
    QtktProcedure? procedure, [
    Map<String, double>? existing,
  ]) {
    if (procedure == null) return {};
    return {
      for (final step in procedure.allSteps)
        step.id: (existing?[step.id] ?? 0).clamp(0, step.maxPoints).toDouble(),
    };
  }

  bool get _dirty {
    if (_readOnly) return false;
    if (widget.existing == null) {
      if (_employee != null || _procedure != null) return true;
    }
    if (_checkContextCode != widget.existing?.checkContextCode) return true;
    if (_noteController.text.trim() != _initialNote.trim()) return true;
    if (_patientCodeController.text.trim() != _initialPatientCode.trim()) {
      return true;
    }
    if (_scores.length != _initialScores.length) return true;
    for (final entry in _scores.entries) {
      if ((_initialScores[entry.key] ?? 0) != entry.value) return true;
    }
    return false;
  }

  List<QtktProcedure> get _availableProcedures {
    final employee = _employee;
    if (employee == null) return const [];
    if (widget.existing != null) {
      return widget.template.procedures
          .where(
            (procedure) => procedure.code == widget.existing!.procedureCode,
          )
          .toList();
    }
    return widget.template.procedures
        .where(
          (procedure) =>
              procedure.isAllowedForDepartment(employee.departmentName),
        )
        .toList();
  }

  double get _totalScore =>
      _scores.values.fold(0, (total, score) => total + score);

  int get _scoredSteps => _scores.values.where((score) => score > 0).length;

  double get _progress {
    final max = _procedure?.maxTotal ?? 0;
    return max <= 0 ? 0 : (_totalScore / max).clamp(0, 1).toDouble();
  }

  void _popAfterUnlock([bool? result]) {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  Future<void> _pickDate() async {
    if (_readOnly || widget.existing != null) return;
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context,
      initialDate: _evalDate.isAfter(now) ? now : _evalDate,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) setState(() => _evalDate = picked);
  }

  Future<void> _pickEmployee() async {
    if (_readOnly || widget.existing != null) return;
    final selected = await showModalBottomSheet<QtktEmployee>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QtktEmployeePicker(
        employees: widget.employees,
        evaluations: widget.monthEvaluations,
        selectedId: _employee?.id,
      ),
    );
    if (selected == null) return;
    _selectEmployee('${selected.id}');
  }

  void _selectEmployee(String value) {
    final id = int.tryParse(value);
    if (id == null) return;
    setState(() {
      _employee = _findEmployee(id);
      _procedure = null;
      _scores = {};
      _checkContextCode = null;
      _patientCodeController.text = '';
    });
  }

  void _selectProcedure(String value) {
    final procedure = widget.template.procedureByCode(value);
    setState(() {
      _procedure = procedure;
      _scores = _scoresFor(procedure);
      _checkContextCode = null;
      if (procedure?.requiresPatientCode != true) {
        _patientCodeController.text = '';
      }
    });
  }

  Future<void> _requestPop() async {
    if (!_dirty) {
      _popAfterUnlock();
      return;
    }
    final discard = await showConfirmDialog(
      context,
      title: 'Bỏ phiếu đang chấm?',
      message: 'Điểm và ghi chú chưa được lưu lên hệ thống.',
      confirmLabel: 'Bỏ thay đổi',
      danger: true,
      icon: Icons.fact_check_outlined,
    );
    if (!discard || !mounted) return;
    _popAfterUnlock();
  }

  Future<void> _save({required bool submit}) async {
    final employee = _employee;
    final procedure = _procedure;
    if (employee == null || procedure == null) {
      showAppSnackBar(
        context,
        'Vui lòng chọn nhân viên và quy trình kỹ thuật.',
        isError: true,
      );
      return;
    }
    if (procedure.requiresPatientCode &&
        _patientCodeController.text.trim().isEmpty) {
      showAppSnackBar(context, 'Vui lòng nhập mã bệnh nhân.', isError: true);
      return;
    }
    // Backend trả 400 nếu quy trình có checkOptions mà thiếu checkContextCode.
    final checkOptions = procedure.checkOptions;
    if (checkOptions != null &&
        checkOptions.isNotEmpty &&
        (_checkContextCode ?? '').isEmpty) {
      showAppSnackBar(
        context,
        'Vui lòng chọn ${checkOptions.label.toLowerCase()}.',
        isError: true,
      );
      return;
    }
    if (submit) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Gửi phiếu đánh giá?',
        message:
            'Phiếu ${formatQtktScore(_totalScore)}/${formatQtktScore(procedure.maxTotal)} '
            'điểm sẽ được gửi Trưởng phòng Điều dưỡng.',
        confirmLabel: 'Gửi phiếu',
        icon: Icons.send_rounded,
      );
      if (!confirmed) return;
    }
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'employeeId': employee.id,
      'procedureCode': procedure.code,
      'evalDate': _dateIso(_evalDate),
      'scores': _scores,
      'note': _noteController.text.trim(),
      'submit': submit,
      if (procedure.requiresPatientCode)
        'patientCode': _patientCodeController.text.trim(),
      if (checkOptions != null && checkOptions.isNotEmpty)
        'checkContextCode': _checkContextCode,
    };
    try {
      final repo = ref.read(qtktRepositoryProvider);
      if (widget.existing == null) {
        await repo.create(payload);
      } else {
        await repo.update(widget.existing!.id, payload);
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showAppSnackBar(
        context,
        submit ? 'Đã gửi phiếu đánh giá' : 'Đã lưu phiếu đánh giá',
        isSuccess: true,
      );
      _popAfterUnlock(true);
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Không lưu được phiếu đánh giá',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancelEvaluation() async {
    final existing = widget.existing;
    if (existing == null || !existing.canRecall) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Thu hồi phiếu đánh giá?',
      message:
          'Phiếu sẽ về trạng thái nháp để chỉnh sửa.\nTrưởng khoa chỉ thu hồi được trong vòng 1 ngày kể từ lúc gửi.',
      confirmLabel: 'Thu hồi',
      danger: true,
      icon: Icons.undo_rounded,
    );
    if (!confirmed) return;
    setState(() => _saving = true);
    try {
      await ref.read(qtktRepositoryProvider).recall(existing.id);
      if (!mounted) return;
      showAppSnackBar(context, 'Đã thu hồi phiếu đánh giá', isSuccess: true);
      _popAfterUnlock(true);
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final title = existing == null
        ? 'Lập phiếu QTKT'
        : (_readOnly ? 'Chi tiết phiếu QTKT' : 'Cập nhật phiếu QTKT');

    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestPop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const AppAmbientBackground(intensity: 0.45),
              Column(
                children: [
                  AppScreenHeader(
                    dense: true,
                    title: title,
                    icon: existing == null
                        ? Icons.fact_check_outlined
                        : (_readOnly
                              ? Icons.visibility_outlined
                              : Icons.edit_note_rounded),
                    eyebrow: 'Quy trình kỹ thuật',
                    subtitle: 'Checklist chuẩn viện · thang điểm 10',
                    onBack: _requestPop,
                    trailing: existing != null && existing.canRecall
                        ? PopupMenuButton<String>(
                            enabled: !_saving,
                            tooltip: 'Tùy chọn phiếu',
                            iconColor: Theme.of(context).colorScheme.onPrimary,
                            onSelected: (value) {
                              if (value == 'recall') _cancelEvaluation();
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'recall',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.undo_rounded,
                                      color: AppColors.warning,
                                    ),
                                    SizedBox(width: 10),
                                    Text('Thu hồi phiếu'),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : null,
                    footer: _ScoreHero(
                      procedure: _procedure,
                      total: _totalScore,
                      progress: _progress,
                      scoredSteps: _scoredSteps,
                      status: existing?.status,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.md,
                        AppSpacing.page,
                        AppSpacing.xl,
                      ),
                      children: [
                        if (_readOnly)
                          const NoticeBanner(
                            message:
                                'Phiếu đang ở chế độ chỉ xem. Dữ liệu được lấy trực tiếp '
                                'từ hệ thống dùng chung với web.',
                          )
                        else if (widget.template.note != null)
                          NoticeBanner(message: widget.template.note!),
                        const SizedBox(height: AppSpacing.md),
                        _buildIdentityFields(),
                        if (_procedure != null) ...[
                          if (_procedure!.checkOptions?.isNotEmpty ??
                              false) ...[
                            const SizedBox(height: AppSpacing.md),
                            AppReveal(
                              child: _CheckOptionsCard(
                                options: _procedure!.checkOptions!,
                                selectedCode: _checkContextCode,
                                enabled: !_readOnly,
                                onSelect: (code) =>
                                    setState(() => _checkContextCode = code),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          if (_procedure!.note != null) ...[
                            NoticeBanner(message: _procedure!.note!),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          for (final (index, section)
                              in _procedure!.sections.indexed)
                            AppReveal(
                              delay: AppStagger.delayFor(index),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _QtktSectionCard(
                                  section: section,
                                  scores: _scores,
                                  readOnly: _readOnly,
                                  onChanged: (stepId, score) =>
                                      setState(() => _scores[stepId] = score),
                                ),
                              ),
                            ),
                          _buildNoteField(),
                        ] else ...[
                          const SizedBox(height: AppSpacing.md),
                          _ProcedurePrompt(
                            employeeSelected: _employee != null,
                            noProcedures:
                                _employee != null &&
                                _availableProcedures.isEmpty,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!_readOnly) _buildBottomActions(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityFields() {
    final existing = widget.existing;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          _QtktEmployeeField(
            employee: _employee,
            enabled: !_readOnly && existing == null,
            onTap: _pickEmployee,
          ),
          const SizedBox(height: 10),
          AppOptionField(
            label: 'Quy trình kỹ thuật',
            value: _procedure?.code,
            enabled: !_readOnly && existing == null && _employee != null,
            requiredMark: true,
            hint: _employee == null
                ? 'Chọn nhân viên trước'
                : (_availableProcedures.isEmpty
                      ? 'Không có quy trình phù hợp khoa này'
                      : 'Chọn quy trình cần chấm'),
            pickerTitle: 'Chọn quy trình kỹ thuật',
            pickerSubtitle:
                'Chỉ hiện quy trình được phép theo khoa của nhân viên.',
            options: [
              for (final procedure in _availableProcedures)
                AppOptionItem(
                  value: procedure.code,
                  label: procedure.name,
                  subtitle:
                      '${procedure.durationMinutes} phút · ${procedure.stepCount} bước · tối đa ${formatQtktScore(procedure.maxTotal)} điểm',
                  icon: Icons.biotech_outlined,
                ),
            ],
            onChanged: _selectProcedure,
          ),
          const SizedBox(height: 10),
          Material(
            color: AppColors.surfaceAlt,
            borderRadius: AppRadius.brControl,
            child: InkWell(
              onTap: !_readOnly && existing == null ? _pickDate : null,
              borderRadius: AppRadius.brControl,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.brControl,
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ngày đánh giá *',
                            style: AppTypography.style(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormat.date(_evalDate),
                            style: AppTypography.style(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      existing == null
                          ? Icons.event_outlined
                          : Icons.lock_outline_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_procedure?.requiresPatientCode == true) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _patientCodeController,
              enabled: !_readOnly && existing == null,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Mã bệnh nhân *',
                hintText: 'Nhập mã BN được tư vấn',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          // Ghi chú quy trình đã hiện ở NoticeBanner ngay dưới thẻ này —
          // không lặp lại lần thứ hai tại đây.
        ],
      ),
    );
  }

  Widget _buildNoteField() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: TextField(
        controller: _noteController,
        enabled: !_readOnly,
        minLines: 3,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Ghi chú',
          hintText: 'Nhận xét thêm về buổi đánh giá (nếu có)…',
          alignLabelWithHint: true,
          prefixIcon: Icon(Icons.notes_rounded),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    final existingSubmitted =
        widget.existing?.status == QtktEvaluationStatus.submitted;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          10,
          AppSpacing.page,
          10,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.borderSoft)),
          boxShadow: AppShadows.nav,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_procedure != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Tổng điểm',
                    style: AppTypography.style(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: AppRadius.brPill,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: _progress),
                        duration: AppDurations.fast,
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 5,
                          backgroundColor: _scoreTone(
                            _progress,
                            scored: _totalScore > 0,
                          ).withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation(
                            _scoreTone(_progress, scored: _totalScore > 0),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatQtktScore(_totalScore),
                          style: AppTypography.metric(
                            fontSize: 18,
                            color: _scoreTone(
                              _progress,
                              scored: _totalScore > 0,
                            ),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: ' / ${formatQtktScore(_procedure!.maxTotal)}',
                          style: AppTypography.metricMuted(
                            fontSize: 11.5,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _save(submit: false),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      existingSubmitted ? 'Lưu thay đổi' : 'Lưu nháp',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _save(submit: true),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 17),
                    label: Text(
                      existingSubmitted ? 'Cập nhật & gửi' : 'Gửi phiếu',
                    ),
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

/// Nhóm lựa chọn bắt buộc của quy trình — ví dụ "Thời điểm rửa tay".
///
/// Dựng dạng thẻ chọn cả dòng thay vì `Radio` nhỏ: vùng chạm rộng, đọc được
/// nhãn dài, và trạng thái chưa chọn được nhấn rõ vì backend bắt buộc trường này.
class _CheckOptionsCard extends StatelessWidget {
  const _CheckOptionsCard({
    required this.options,
    required this.selectedCode,
    required this.enabled,
    required this.onSelect,
  });

  final QtktCheckOptions options;
  final String? selectedCode;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final missing = enabled && (selectedCode ?? '').isEmpty;
    final accent = missing ? AppColors.warning : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(
          color: missing
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.borderSoft,
        ),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: accent.withValues(alpha: 0.18)),
                  ),
                  child: Icon(Icons.schedule_rounded, size: 18, color: accent),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              options.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.15,
                              ),
                            ),
                          ),
                          Text(
                            ' *',
                            style: AppTypography.style(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      if (options.hint != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          options.hint!,
                          style: AppTypography.style(
                            fontSize: 11.5,
                            height: 1.32,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (missing) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: AppRadius.brPill,
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Chưa chọn',
                      style: AppTypography.style(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warningText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          for (final (index, option) in options.options.indexed) ...[
            if (index > 0)
              const Padding(
                padding: EdgeInsets.only(left: 14),
                child: Divider(height: 1, color: AppColors.borderSoft),
              ),
            _CheckOptionRow(
              option: option,
              selected: option.code == selectedCode,
              enabled: enabled,
              onTap: () => onSelect(option.code),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckOptionRow extends StatelessWidget {
  const _CheckOptionRow({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final QtktCheckOption option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: enabled,
      label: option.label,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onTap();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppDurations.fast,
                  curve: Curves.easeOutCubic,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 1 : 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.label,
                    style: AppTypography.style(
                      fontSize: 12.8,
                      height: 1.4,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: enabled
                          ? (selected
                                ? AppColors.primaryDark
                                : AppColors.textPrimary)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QtktEmployeeField extends StatelessWidget {
  const _QtktEmployeeField({
    required this.employee,
    required this.enabled,
    required this.onTap,
  });

  final QtktEmployee? employee;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = employee != null;
    return Material(
      color: enabled ? AppColors.surfaceAlt : AppColors.surfaceHigh,
      borderRadius: AppRadius.brControl,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.brControl,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brControl,
            border: Border.all(
              color: hasValue
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : AppColors.borderSoft,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 37,
                height: 37,
                decoration: BoxDecoration(
                  color: hasValue
                      ? AppColors.primaryContainer
                      : AppColors.surface,
                  borderRadius: AppRadius.brSm,
                ),
                alignment: Alignment.center,
                child: hasValue
                    ? Text(
                        _initials(employee!.fullName),
                        style: AppTypography.style(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      )
                    : const Icon(
                        Icons.person_search_outlined,
                        size: 19,
                        color: AppColors.textTertiary,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nhân viên được đánh giá *',
                      style: AppTypography.style(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      employee?.fullName ?? 'Tìm và chọn nhân viên',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: hasValue
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                    if (hasValue && employee!.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        employee!.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 10.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                enabled
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.lock_outline_rounded,
                color: hasValue ? AppColors.primary : AppColors.textTertiary,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtktEmployeePicker extends StatefulWidget {
  const _QtktEmployeePicker({
    required this.employees,
    required this.evaluations,
    required this.selectedId,
  });

  final List<QtktEmployee> employees;
  final List<QtktEvaluation> evaluations;
  final int? selectedId;

  @override
  State<_QtktEmployeePicker> createState() => _QtktEmployeePickerState();
}

class _QtktEmployeePickerState extends State<_QtktEmployeePicker> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()..addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  List<QtktEmployee> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.employees;
    return widget.employees.where((employee) {
      final text = [
        employee.fullName,
        employee.employeeCode ?? '',
        employee.departmentName ?? '',
        employee.positionTitle ?? '',
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  (String, Color) _statusFor(int employeeId) {
    final rows = widget.evaluations
        .where(
          (item) =>
              item.employeeId == employeeId &&
              item.status != QtktEvaluationStatus.cancelled,
        )
        .toList();
    if (rows.isEmpty) return ('Chưa có', AppColors.textTertiary);
    final hasDraft = rows.any(
      (item) => item.status == QtktEvaluationStatus.draft,
    );
    final hasSubmitted = rows.any(
      (item) => item.status == QtktEvaluationStatus.submitted,
    );
    if (hasDraft && hasSubmitted) return ('Nháp + đã gửi', AppColors.info);
    if (hasDraft) return ('Nháp · ${rows.length}', AppColors.warning);
    return ('Đã gửi · ${rows.length}', AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.82;
    final rows = _filtered;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brSheetTop,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.35),
              borderRadius: AppRadius.brPill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chọn nhân viên',
                        style: AppTypography.style(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.employees.length} nhân viên trong phạm vi phụ trách',
                        style: AppTypography.style(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 11),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm tên, mã NV, chức danh hoặc khoa…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          Expanded(
            child: rows.isEmpty
                ? const EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'Không tìm thấy nhân viên',
                    message: 'Hãy thử từ khóa ngắn hơn.',
                  )
                : ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final employee = rows[index];
                      final selected = employee.id == widget.selectedId;
                      final status = _statusFor(employee.id);
                      return Material(
                        color: selected
                            ? AppColors.primaryContainer
                            : AppColors.surfaceAlt,
                        borderRadius: AppRadius.brMd,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, employee),
                          borderRadius: AppRadius.brMd,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(11, 10, 10, 10),
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.brMd,
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary.withValues(alpha: 0.35)
                                    : AppColors.borderSoft,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 19,
                                  backgroundColor: AppColors.primary.withValues(
                                    alpha: selected ? 0.16 : 0.09,
                                  ),
                                  child: Text(
                                    _initials(employee.fullName),
                                    style: AppTypography.style(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        employee.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.style(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (employee.subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          employee.subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.style(
                                            fontSize: 11.3,
                                            color: AppColors.textSecondary,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusChip(
                                  label: status.$1,
                                  color: status.$2,
                                  dense: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Panel tóm tắt điểm nằm trong header brand — vòng tiến độ + tên quy trình.
class _ScoreHero extends StatelessWidget {
  const _ScoreHero({
    required this.procedure,
    required this.total,
    required this.progress,
    required this.scoredSteps,
    required this.status,
  });

  final QtktProcedure? procedure;
  final double total;
  final double progress;
  final int scoredSteps;
  final QtktEvaluationStatus? status;

  static const Color _gold = Color(0xFFF5D77D);
  static const Color _mint = Color(0xFFB8F0D8);

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final procedure = this.procedure;
    final complete = progress >= 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: onBrand.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: onBrand.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: AppDurations.slow,
              curve: Curves.easeOutCubic,
              builder: (context, animated, _) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: animated,
                      strokeWidth: 5.5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: onBrand.withValues(alpha: 0.18),
                      valueColor: AlwaysStoppedAnimation(
                        complete ? _mint : _gold,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            formatQtktScore(total),
                            maxLines: 1,
                            style: AppTypography.metric(
                              fontSize: 17,
                              color: onBrand,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '/ ${formatQtktScore(procedure?.maxTotal ?? 10)}',
                        style: AppTypography.metricMuted(
                          fontSize: 10,
                          color: onBrand.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  procedure?.name ?? 'Phiếu đánh giá kỹ thuật',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: onBrand,
                    height: 1.28,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  procedure == null
                      ? 'Chọn nhân viên và quy trình để bắt đầu.'
                      : '$scoredSteps/${procedure.stepCount} bước đã chấm · '
                            '${procedure.durationMinutes} phút',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.32,
                    color: onBrand.withValues(alpha: 0.84),
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(height: 8),
                  _BrandStatusChip(status: status!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip trạng thái đọc được trên nền brand tối.
class _BrandStatusChip extends StatelessWidget {
  const _BrandStatusChip({required this.status});

  final QtktEvaluationStatus status;

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final color = switch (status) {
      QtktEvaluationStatus.draft => const Color(0xFFF5D77D),
      QtktEvaluationStatus.submitted => const Color(0xFFB8F0D8),
      QtktEvaluationStatus.cancelled => onBrand.withValues(alpha: 0.7),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: onBrand.withValues(alpha: 0.14),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: AppTypography.style(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcedurePrompt extends StatelessWidget {
  const _ProcedurePrompt({
    required this.employeeSelected,
    required this.noProcedures,
  });

  final bool employeeSelected;
  final bool noProcedures;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          Icon(
            noProcedures
                ? Icons.task_alt_rounded
                : (employeeSelected
                      ? Icons.biotech_outlined
                      : Icons.person_search_outlined),
            size: 34,
            color: noProcedures ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(height: 10),
          Text(
            noProcedures
                ? 'Nhân viên đã có đủ phiếu trong tháng'
                : (employeeSelected
                      ? 'Chọn quy trình cần đánh giá'
                      : 'Chọn nhân viên để bắt đầu'),
            textAlign: TextAlign.center,
            style: AppTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            noProcedures
                ? 'Bạn có thể mở phiếu hiện có từ danh sách để xem hoặc cập nhật.'
                : 'Checklist và mức điểm được tải trực tiếp từ mẫu trên máy chủ.',
            textAlign: TextAlign.center,
            style: AppTypography.style(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtktSectionCard extends StatelessWidget {
  const _QtktSectionCard({
    required this.section,
    required this.scores,
    required this.readOnly,
    required this.onChanged,
  });

  final QtktSection section;
  final Map<String, double> scores;
  final bool readOnly;
  final void Function(String stepId, double score) onChanged;

  @override
  Widget build(BuildContext context) {
    final score = section.steps.fold<double>(
      0,
      (total, step) => total + (scores[step.id] ?? 0),
    );
    final progress = section.maxPoints <= 0
        ? 0.0
        : (score / section.maxPoints).clamp(0, 1).toDouble();
    final tone = _scoreTone(progress, scored: score > 0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        backgroundColor: AppColors.surface,
        collapsedBackgroundColor: AppColors.surface,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.1),
            borderRadius: AppRadius.brSm,
          ),
          child: Icon(Icons.checklist_rounded, color: tone, size: 20),
        ),
        title: Text(
          section.title,
          style: AppTypography.style(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        // Tiến độ nằm ở phần tiêu đề để vẫn thấy được khi mục đã thu gọn.
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatQtktScore(score)} / ${formatQtktScore(section.maxPoints)} điểm',
                style: AppTypography.metric(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: tone,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: AppRadius.brPill,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: AppDurations.fast,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor: tone.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(tone),
                  ),
                ),
              ),
            ],
          ),
        ),
        children: [
          for (final (index, step) in section.steps.indexed) ...[
            _QtktScoreStepCard(
              step: step,
              value: scores[step.id] ?? 0,
              readOnly: readOnly,
              onChanged: (value) => onChanged(step.id, value),
            ),
            if (index != section.steps.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _QtktScoreStepCard extends StatefulWidget {
  const _QtktScoreStepCard({
    required this.step,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  final QtktStep step;
  final double value;
  final bool readOnly;
  final ValueChanged<double> onChanged;

  @override
  State<_QtktScoreStepCard> createState() => _QtktScoreStepCardState();
}

class _QtktScoreStepCardState extends State<_QtktScoreStepCard> {
  bool _expanded = false;

  void _change(double value) {
    final normalized = (value * 4).round() / 4;
    widget.onChanged(normalized.clamp(0, widget.step.maxPoints).toDouble());
  }

  /// Chạm ô đầu dòng: đủ điểm ⇄ 0. Phần lớn bước là checklist đạt/không đạt nên
  /// đây là đường tắt một chạm; nút −/+ vẫn dùng để chấm lẻ 0.25.
  void _toggleFull() {
    if (widget.readOnly) return;
    HapticFeedback.selectionClick();
    final max = widget.step.maxPoints;
    _change(widget.value >= max ? 0 : max);
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.step.maxPoints;
    final full = max > 0 && widget.value >= max;
    final active = widget.value > 0;
    final color = full
        ? AppColors.success
        : (active ? AppColors.primary : AppColors.textTertiary);
    final progress = max <= 0
        ? 0.0
        : (widget.value / max).clamp(0, 1).toDouble();
    final detail = widget.step.detail;
    final hasDetail =
        detail != null &&
        detail.trim().isNotEmpty &&
        detail.trim() != widget.step.title.trim();

    return AnimatedContainer(
      duration: AppDurations.fast,
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.055 : 0.025),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: color.withValues(alpha: active ? 0.22 : 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: !widget.readOnly,
                checked: full,
                label: full ? 'Bỏ đủ điểm' : 'Cho đủ điểm',
                child: Material(
                  color: color.withValues(alpha: full ? 1 : 0.12),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.readOnly ? null : _toggleFull,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Center(
                        child: full
                            ? const Icon(
                                Icons.check_rounded,
                                size: 17,
                                color: Colors.white,
                              )
                            : Text(
                                '${widget.step.no}',
                                style: AppTypography.metric(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        widget.step.title,
                        style: AppTypography.style(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      if (widget.step.required)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Bắt buộc',
                            style: AppTypography.style(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.warningText,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (hasDetail) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: AppRadius.brSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _expanded ? 'Thu gọn' : 'Nội dung đầy đủ',
                          style: AppTypography.style(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: AppDurations.fast,
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(left: 40, top: 2, bottom: 2),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: AppRadius.brSm,
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Text(
                  detail,
                  style: AppTypography.style(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              _ScoreButton(
                icon: Icons.remove_rounded,
                enabled: !widget.readOnly && widget.value > 0,
                onTap: () => _change(widget.value - 0.25),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${formatQtktScore(widget.value)} / ${formatQtktScore(max)}',
                      style:
                          AppTypography.metric(
                            fontSize: 15,
                            color: color,
                            fontWeight: FontWeight.w800,
                          ).copyWith(
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: AppRadius.brPill,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: AppDurations.fast,
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 5,
                          backgroundColor: color.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              _ScoreButton(
                icon: Icons.add_rounded,
                enabled: !widget.readOnly && widget.value < max,
                onTap: () => _change(widget.value + 0.25),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nút chấm lẻ 0.25 — hai nút cùng sức nặng để không tạo dải khối chạy dọc.
class _ScoreButton extends StatelessWidget {
  const _ScoreButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = enabled
        ? AppColors.primary.withValues(alpha: 0.1)
        : AppColors.textPrimary.withValues(alpha: 0.04);
    final foreground = enabled
        ? AppColors.primary
        : AppColors.textTertiary.withValues(alpha: 0.5);

    return Material(
      color: background,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: foreground),
        ),
      ),
    );
  }
}

/// Màu theo mức đạt. [scored] = false khi chưa chấm điểm nào: lúc đó 0 điểm
/// nghĩa là "chưa nhập" chứ không phải "kém", nên dùng màu trung tính thay vì
/// tô đỏ cả phiếu vừa mở.
Color _scoreTone(double progress, {bool scored = true}) {
  if (!scored) return AppColors.textTertiary;
  if (progress >= 0.9) return AppColors.success;
  if (progress >= 0.7) return AppColors.primary;
  if (progress >= 0.5) return AppColors.warning;
  return AppColors.error;
}

String _dateIso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'NV';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
