import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/employee.dart';
import '../../employees/data/employee_repository.dart';
import '../application/generic_request_controller.dart';
import '../data/generic_request_repository.dart';
import '../data/request_type_config.dart';

/// Đề xuất chế độ nuôi con nhỏ — API đồng bộ web, UI theo pattern đơn đề xuất mobile.
class YoungChildProposeScreen extends ConsumerStatefulWidget {
  const YoungChildProposeScreen({
    super.key,
    required this.employeeId,
    this.requestId,
  });

  final int employeeId;
  final int? requestId;

  @override
  ConsumerState<YoungChildProposeScreen> createState() =>
      _YoungChildProposeScreenState();
}

class _YoungChildProposeScreenState
    extends ConsumerState<YoungChildProposeScreen> {
  final _reason = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  EmployeeDetail? _employee;
  DateTime? _start;
  DateTime? _end;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.requestId != null;

  static const _accent = Color(0xFFC2410C);

  static const _flowSteps = [
    _FlowStepData(
      Icons.edit_note_rounded,
      'Đề xuất',
      'Trưởng khoa / Admin lập phiếu',
    ),
    _FlowStepData(
      Icons.verified_rounded,
      'HCNS duyệt',
      'Áp dụng chế độ & tính lại công',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, 1);
    _end = DateTime(now.year, now.month + 1, 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail =
          await ref.read(employeeRepositoryProvider).detail(widget.employeeId);
      Map<String, dynamic>? existing;
      if (_isEdit) {
        existing = await ref
            .read(genericRequestRepositoryProvider)
            .byId(RequestTypeConfig.byKey('young-child'), widget.requestId!);
        if (existing.isEmpty) {
          throw StateError('empty');
        }
      }
      if (!mounted) return;
      setState(() {
        _employee = detail;
        if (existing != null) {
          _start = DateTime.tryParse(existing['startDate']?.toString() ?? '');
          _end = DateTime.tryParse(existing['endDate']?.toString() ?? '');
          _reason.text = existing['reason']?.toString() ?? '';
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppSnackBar(
        context,
        _isEdit ? 'Không tải được đơn để chỉnh sửa' : 'Không tải được hồ sơ nhân viên',
        isError: true,
      );
      if (_isEdit) context.pop();
    }
  }

  String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int? get _daySpan {
    final start = _start;
    final end = _end;
    if (start == null || end == null || end.isBefore(start)) return null;
    return end.difference(start).inDays + 1;
  }

  Future<void> _pickStart() async {
    final picked = await showAppDatePicker(
      context,
      title: 'Ngày bắt đầu',
      initialDate: _start ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked == null) return;
    setState(() {
      _start = picked;
      if (_end != null && _end!.isBefore(picked)) _end = picked;
    });
  }

  Future<void> _pickEnd() async {
    final start = _start ?? DateTime.now();
    final picked = await showAppDatePicker(
      context,
      title: 'Ngày kết thúc',
      initialDate: _end ?? start,
      firstDate: start,
      lastDate: DateTime(start.year + 1, start.month, start.day)
          .subtract(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() => _end = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final start = _start;
    final end = _end;
    if (start == null || end == null) {
      showAppSnackBar(context, 'Chọn đủ khoảng ngày', isError: true);
      return;
    }
    if (end.isBefore(start)) {
      showAppSnackBar(
        context,
        'Ngày kết thúc không được trước ngày bắt đầu',
        isError: true,
      );
      return;
    }
    final maxEnd = DateTime(start.year + 1, start.month, start.day)
        .subtract(const Duration(days: 1));
    if (end.isAfter(maxEnd)) {
      showAppSnackBar(
        context,
        'Khoảng thời gian áp dụng không được quá 1 năm',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final config = RequestTypeConfig.byKey('young-child');
      final body = {
        'employeeId': widget.employeeId,
        'startDate': _iso(start),
        'endDate': _iso(end),
        'enabled': true,
        'reason': _reason.text.trim(),
      };
      final Map<String, dynamic> result;
      if (_isEdit) {
        result = await ref.read(genericRequestRepositoryProvider).update(
              config,
              widget.requestId!,
              body,
            );
      } else {
        result = await ref.read(genericRequestRepositoryProvider).create(
              config,
              body,
            );
      }
      if (!mounted) return;
      final id = _isEdit
          ? widget.requestId
          : (result['id'] as num?)?.toInt();
      ref.invalidate(genericRequestControllerProvider('young-child'));
      showAppSnackBar(
        context,
        _isEdit ? 'Đã lưu thay đổi' : 'Đã gửi đề xuất nuôi con nhỏ',
        isSuccess: true,
      );
      context.pop();
      if (id != null) {
        context.push(RoutePaths.requestDetailPath('young-child', id));
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Không gửi được. Kiểm tra quyền hoặc đề xuất đang chờ duyệt.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = _employee;
    if (_loading || emp == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const Positioned.fill(child: AppAmbientBackground(intensity: 0.7)),
            Column(
              children: [
                AppScreenHeader(
                  dense: true,
                  title: 'Nuôi con nhỏ',
                  icon: Icons.child_care_rounded,
                  eyebrow: 'Chế độ',
                  onBack: () => context.pop(),
                ),
                const Expanded(child: SkeletonList(itemCount: 5)),
              ],
            ),
          ],
        ),
      );
    }

    final s = emp.summary;
    final span = _daySpan;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.85)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: _isEdit
                    ? 'Chỉnh sửa nuôi con nhỏ'
                    : 'Đề xuất nuôi con nhỏ',
                icon: Icons.child_care_rounded,
                eyebrow: _isEdit ? 'Chỉnh sửa phiếu' : 'Phiếu đề xuất',
                subtitle: s.fullName,
                onBack: () => context.pop(),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      12,
                      AppSpacing.page,
                      120,
                    ),
                    children: [
                      _ProposalFlowStrip(
                        accent: _accent,
                        steps: _flowSteps,
                      ),
                      const SizedBox(height: 10),
                      NoticeBanner(
                        color: _accent,
                        icon: Icons.info_outline_rounded,
                        message:
                            'Sau khi HCNS duyệt, hệ thống áp dụng đúng khoảng ngày đã chọn và tính lại bảng công liên quan.',
                      ),
                      const SizedBox(height: 12),
                      _PolicyChips(accent: _accent),
                      const SizedBox(height: 12),
                      _EmployeeCard(
                        employee: emp,
                        accent: _accent,
                        periodLabel: (_start != null && _end != null)
                            ? '${_dmy(_start!)} – ${_dmy(_end!)}'
                            : null,
                        onChange: _isEdit
                            ? null
                            : () => context.pushReplacement(
                                  RoutePaths.requestCreatePath('young-child'),
                                ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        accentColor: _accent,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        margin: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(
                              icon: Icons.date_range_rounded,
                              title: 'Thời gian áp dụng',
                              accent: _accent,
                              trailing: span == null
                                  ? null
                                  : '$span ngày',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Chọn khoảng ngày, tối đa 1 năm',
                              style: AppTypography.style(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _DateTile(
                                    label: 'Bắt đầu *',
                                    value: _start == null
                                        ? 'Chọn ngày'
                                        : _dmy(_start!),
                                    accent: _accent,
                                    onTap: _pickStart,
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: _accent.withValues(alpha: 0.7),
                                  ),
                                ),
                                Expanded(
                                  child: _DateTile(
                                    label: 'Kết thúc *',
                                    value: _end == null
                                        ? 'Chọn ngày'
                                        : _dmy(_end!),
                                    accent: _accent,
                                    onTap: _pickEnd,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        accentColor: _accent,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        margin: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(
                              icon: Icons.notes_rounded,
                              title: 'Nội dung đề xuất',
                              accent: _accent,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _reason,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                labelText: 'Lý do đề xuất *',
                                hintText:
                                    'VD: Nhân viên nuôi con dưới 12 tháng, đề nghị giảm 1 giờ/ngày…',
                                alignLabelWithHint: true,
                                filled: true,
                                fillColor: AppColors.surfaceMuted,
                                border: OutlineInputBorder(
                                  borderRadius: AppRadius.brMd,
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: AppRadius.brMd,
                                  borderSide: const BorderSide(
                                    color: AppColors.borderSoft,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: AppRadius.brMd,
                                  borderSide: BorderSide(
                                    color: _accent,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Nhập lý do đề xuất'
                                      : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        accent: _accent,
        saving: _saving,
        submitLabel: _isEdit ? 'Lưu thay đổi' : 'Gửi đề xuất',
        onCancel: () => context.pop(),
        onSubmit: _submit,
      ),
    );
  }
}

class _FlowStepData {
  const _FlowStepData(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

class _ProposalFlowStrip extends StatefulWidget {
  const _ProposalFlowStrip({required this.accent, required this.steps});

  final Color accent;
  final List<_FlowStepData> steps;

  @override
  State<_ProposalFlowStrip> createState() => _ProposalFlowStripState();
}

class _ProposalFlowStripState extends State<_ProposalFlowStrip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    final accent = widget.accent;
    final current = steps.first;

    return AppCard(
      accentColor: accent,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: AppRadius.brCard,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: AppRadius.brSm,
                      ),
                      child: Icon(
                        Icons.account_tree_rounded,
                        size: 15,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Luồng duyệt',
                            style: AppTypography.style(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            _expanded
                                ? '${steps.length} bước'
                                : 'Bước 1/${steps.length} · ${current.title}',
                            style: AppTypography.style(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: AppDurations.fast,
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: AppDurations.normal,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _CurrentStepChip(
                accent: accent,
                step: current,
                onExpand: () => setState(() => _expanded = true),
              ),
            ),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  for (var i = 0; i < steps.length; i++)
                    _ExpandedStep(
                      accent: accent,
                      step: steps[i],
                      index: i,
                      active: i == 0,
                      isLast: i == steps.length - 1,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentStepChip extends StatelessWidget {
  const _CurrentStepChip({
    required this.accent,
    required this.step,
    required this.onExpand,
  });

  final Color accent;
  final _FlowStepData step;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExpand,
        borderRadius: AppRadius.brMd,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: AppRadius.brMd,
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
                child: Icon(step.icon, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    Text(
                      step.subtitle,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: AppRadius.brPill,
                ),
                child: Text(
                  'Hiện tại',
                  style: AppTypography.style(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

class _ExpandedStep extends StatelessWidget {
  const _ExpandedStep({
    required this.accent,
    required this.step,
    required this.index,
    required this.active,
    required this.isLast,
  });

  final Color accent;
  final _FlowStepData step;
  final int index;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? accent : AppColors.surfaceMuted,
                    border: Border.all(
                      color: active ? accent : AppColors.borderSoft,
                    ),
                  ),
                  child: active
                      ? Icon(step.icon, size: 14, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: AppTypography.style(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textTertiary,
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.borderSoft,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: AppTypography.style(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: active ? accent : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    step.subtitle,
                    style: AppTypography.style(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyChips extends StatelessWidget {
  const _PolicyChips({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.schedule_rounded, 'Giảm 1 giờ/ngày'),
      (Icons.fact_check_rounded, 'Tối thiểu 7h = 1 công'),
      (Icons.event_available_rounded, 'Tối đa 1 năm'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.brPill,
                border: Border.all(color: accent.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.$1, size: 15, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    item.$2,
                    style: AppTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.accent,
    this.onChange,
    this.periodLabel,
  });

  final EmployeeDetail employee;
  final Color accent;
  final VoidCallback? onChange;
  final String? periodLabel;

  @override
  Widget build(BuildContext context) {
    final s = employee.summary;
    return AppCard(
      accentColor: accent,
      padding: const EdgeInsets.all(14),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          AppAvatar(
            name: s.fullName,
            imageUrl: s.avatarUrl,
            size: 52,
            borderColor: accent.withValues(alpha: 0.25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                if ((s.positionTitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    s.positionTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
                if ((s.departmentName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    s.departmentName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (periodLabel != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Text(
                      periodLabel!,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onChange != null) ...[
            const SizedBox(width: 8),
            Material(
              color: accent.withValues(alpha: 0.1),
              borderRadius: AppRadius.brPill,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChange!();
                },
                borderRadius: AppRadius.brPill,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 16, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        'Đổi',
                        style: AppTypography.style(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.accent,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: AppRadius.brSm,
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: AppTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: AppRadius.brPill,
            ),
            child: Text(
              trailing!,
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.style(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(Icons.calendar_today_rounded, size: 15, color: accent),
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
    required this.accent,
    required this.saving,
    required this.submitLabel,
    required this.onCancel,
    required this.onSubmit,
  });

  final Color accent;
  final bool saving;
  final String submitLabel;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: AppColors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            10,
            AppSpacing.page,
            12,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: accent.withValues(alpha: 0.45)),
                    foregroundColor: accent,
                  ),
                  child: const Text('Huỷ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: saving ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: const Size.fromHeight(48),
                    elevation: 0,
                  ),
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          submitLabel == 'Lưu thay đổi'
                              ? Icons.save_outlined
                              : Icons.send_rounded,
                          size: 18,
                        ),
                  label: Text(saving ? 'Đang lưu…' : submitLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
