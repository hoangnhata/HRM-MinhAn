import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/nursing_block.dart';
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
import 'probation_conversion_detail_body.dart';
import 'probation_score_sheet.dart';
import 'request_create_flow_strip.dart';

/// Lập đơn chuyển chính thức — API đồng bộ web, bố cục tối ưu mobile.
class ProbationConversionCreateScreen extends ConsumerStatefulWidget {
  const ProbationConversionCreateScreen({
    super.key,
    required this.employeeId,
    this.requestId,
  });

  final int employeeId;
  final int? requestId;

  @override
  ConsumerState<ProbationConversionCreateScreen> createState() =>
      _ProbationConversionCreateScreenState();
}

class _ProbationConversionCreateScreenState
    extends ConsumerState<ProbationConversionCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _mentor = TextEditingController();
  final _headDept = TextEditingController();
  final _wardNurse = TextEditingController();
  final _hospitalNurse = TextEditingController();

  EmployeeDetail? _employee;
  String _formType = 'STAFF';
  String _formTypeLabel = 'Nhân viên';
  int _maxScore = 100;
  List<ProbationCriterion> _criteria = const [];
  final Map<String, int> _scores = {};

  DateTime? _officialDate;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.requestId != null;

  static const _accent = AppColors.success;

  bool get _isNurse => _formType == 'NURSE';
  bool get _nursingFlow =>
      isNursingBlockTitle(_employee?.summary.positionTitle);

  List<RequestFlowStep> get _flowSteps => requestCreateFlowSteps(
        probationFlowLabels(_employee?.summary.positionTitle),
      );

  String get _statusPhrase {
    final s = (_employee?.summary.status ?? '').toUpperCase();
    return switch (s) {
      'INTERN' => 'thực tập',
      'PROBATION' => 'thử việc',
      _ => 'thử việc / thực tập',
    };
  }

  @override
  void initState() {
    super.initState();
    _officialDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _reason.dispose();
    _phone.dispose();
    _email.dispose();
    _mentor.dispose();
    _headDept.dispose();
    _wardNurse.dispose();
    _hospitalNurse.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final emp = await ref
          .read(employeeRepositoryProvider)
          .detail(widget.employeeId);
      Map<String, dynamic>? existing;
      if (_isEdit) {
        existing = await ref.read(genericRequestRepositoryProvider).byId(
              RequestTypeConfig.byKey('probation-conversion'),
              widget.requestId!,
            );
        if (existing.isEmpty) throw StateError('empty');
      }
      final meta = await ref
          .read(genericRequestRepositoryProvider)
          .probationFormType(widget.employeeId);
      if (!mounted) return;

      final formType = _isEdit
          ? ((existing!['formType'] as String?)?.toUpperCase() ??
              (meta['formType'] as String?)?.toUpperCase() ??
              'STAFF')
          : ((meta['formType'] as String?)?.toUpperCase() ?? 'STAFF');
      final criteria = ProbationScoreCatalog.fromApi(meta['criteria'], formType);
      final formTypeLabel = _isEdit &&
              (existing!['formTypeLabel'] as String?)?.trim().isNotEmpty == true
          ? (existing['formTypeLabel'] as String).trim()
          : (meta['formTypeLabel'] as String?)?.trim().isNotEmpty == true
          ? (meta['formTypeLabel'] as String).trim()
          : ProbationScoreCatalog.formTypeLabel(formType);
      final maxScore = _isEdit
          ? ((existing!['maxScore'] as num?)?.toInt() ??
              ProbationScoreCatalog.maxScoreOf(formType))
          : ((meta['maxScore'] as num?)?.toInt() ??
              ProbationScoreCatalog.maxScoreOf(formType));

      setState(() {
        _employee = emp;
        _phone.text = (emp.phone ?? '').trim();
        _email.text = (emp.email ?? '').trim();
        _formType = formType;
        _formTypeLabel = formTypeLabel;
        _maxScore = maxScore;
        _criteria = criteria;
        _scores
          ..clear()
          ..addEntries(criteria.map((c) => MapEntry(c.code, 0)));
        if (existing != null) {
          _officialDate =
              DateTime.tryParse(existing['officialDate']?.toString() ?? '');
          _reason.text = existing['reason']?.toString() ?? '';
          _mentor.text = existing['mentorComment']?.toString() ?? '';
          _headDept.text = existing['headDeptComment']?.toString() ?? '';
          _wardNurse.text = existing['wardNurseHeadComment']?.toString() ?? '';
          _hospitalNurse.text =
              existing['hospitalNurseHeadComment']?.toString() ?? '';
          final parsed = ProbationConversionDetailBody.parseScores(
            existing['scoresJson'] ?? existing['scores'],
          );
          for (final entry in parsed.entries) {
            _scores[entry.key] = entry.value.toInt();
          }
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppSnackBar(
        context,
        _isEdit
            ? 'Không tải được đơn để chỉnh sửa'
            : 'Không tải được hồ sơ / mẫu đánh giá',
        isError: true,
      );
      context.pop();
    }
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickOfficialDate() async {
    final picked = await showAppDatePicker(
      context,
      title: 'Ngày lên chính thức',
      initialDate: _officialDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked != null) setState(() => _officialDate = picked);
  }

  Future<void> _trySyncContact(EmployeeDetail emp) async {
    try {
      await ref.read(employeeRepositoryProvider).updateContact(
            emp.summary.id,
            status: emp.summary.status ?? 'PROBATION',
            fullName: emp.summary.fullName,
            phone: _phone.text.trim(),
            email: _email.text.trim(),
          );
    } catch (_) {
      // Trưởng khoa có thể không có quyền HR — HCNS bổ sung sau.
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final date = _officialDate;
    final emp = _employee;
    if (emp == null || date == null) {
      showAppSnackBar(context, 'Chọn ngày lên chính thức', isError: true);
      return;
    }
    for (final c in _criteria) {
      final v = _scores[c.code];
      if (v == null) {
        showAppSnackBar(context, 'Nhập điểm: ${c.label}', isError: true);
        return;
      }
      if (v < 0 || v > c.maxScore) {
        showAppSnackBar(
          context,
          '${c.label} phải từ 0 đến ${c.maxScore}',
          isError: true,
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await _trySyncContact(emp);
      final config = RequestTypeConfig.byKey('probation-conversion');
      final body = {
        'employeeId': widget.employeeId,
        'officialDate': _iso(date),
        'reason': _reason.text.trim(),
        'formType': _formType,
        if (_mentor.text.trim().isNotEmpty)
          'mentorComment': _mentor.text.trim(),
        if (_headDept.text.trim().isNotEmpty)
          'headDeptComment': _headDept.text.trim(),
        if (_isNurse && _wardNurse.text.trim().isNotEmpty)
          'wardNurseHeadComment': _wardNurse.text.trim(),
        if (_isNurse && _hospitalNurse.text.trim().isNotEmpty)
          'hospitalNurseHeadComment': _hospitalNurse.text.trim(),
        'scores': _scores,
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
      ref.invalidate(genericRequestControllerProvider('probation-conversion'));
      final id = _isEdit
          ? widget.requestId
          : (result['id'] as num?)?.toInt();
      showAppSnackBar(
        context,
        _isEdit ? 'Đã lưu thay đổi' : 'Đã gửi đơn chuyển chính thức',
        isSuccess: true,
      );
      context.pop();
      if (id != null) {
        context.push(
          RoutePaths.requestDetailPath('probation-conversion', id),
        );
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Không gửi được. Kiểm tra quyền, điểm đánh giá hoặc đơn đang chờ duyệt.',
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
                  title: 'Lên chính thức',
                  icon: Icons.badge_outlined,
                  eyebrow: 'Phiếu đề xuất',
                  onBack: () => context.pop(),
                ),
                const Expanded(child: SkeletonList(itemCount: 6)),
              ],
            ),
          ],
        ),
      );
    }

    final s = emp.summary;
    final deptPos = [
      if ((s.departmentName ?? '').trim().isNotEmpty) s.departmentName!.trim(),
      if ((s.positionTitle ?? '').trim().isNotEmpty) s.positionTitle!.trim(),
    ].join(' · ');

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
                    ? 'Chỉnh sửa đề nghị ký HĐLĐ'
                    : 'Đề nghị ký HĐLĐ chính thức',
                icon: Icons.badge_outlined,
                eyebrow: _isEdit ? 'Chỉnh sửa phiếu' : 'Lập đơn chuyển chính thức',
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
                      RequestCreateFlowStrip(
                        accent: _accent,
                        steps: _flowSteps,
                      ),
                      const SizedBox(height: 10),
                      NoticeBanner(
                        color: _accent,
                        icon: Icons.route_rounded,
                        message: _nursingFlow
                            ? 'Khối ĐD–KTV–HS–Thư ký: sau khi gửi, đơn chuyển Trưởng phòng Điều dưỡng → HCNS → Giám đốc.'
                            : 'Sau khi gửi, đơn chuyển HCNS rồi Ban Giám đốc duyệt.',
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        accentColor: _accent,
                        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                        margin: EdgeInsets.zero,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppAvatar(
                              name: s.fullName,
                              imageUrl: s.avatarUrl,
                              size: 56,
                              borderColor: _accent.withValues(alpha: 0.28),
                              borderWidth: 2,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.fullName,
                                    style: AppTypography.style(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.25,
                                      height: 1.2,
                                    ),
                                  ),
                                  if (deptPos.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      deptPos,
                                      style: AppTypography.style(
                                        fontSize: 12.5,
                                        height: 1.35,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _MiniChip(
                                        label: 'Mẫu $_formTypeLabel',
                                        color: _accent,
                                      ),
                                      _MiniChip(
                                        label: _statusPhrase,
                                        color: AppColors.warning,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (!_isEdit)
                              TextButton(
                                onPressed: () => context.pushReplacement(
                                  RoutePaths.requestCreatePath(
                                    'probation-conversion',
                                  ),
                                ),
                                child: const Text('Đổi NV'),
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
                            const _SectionHeader(
                              icon: Icons.edit_note_rounded,
                              title: 'Nội dung đề nghị',
                              subtitle: 'Ngày chính thức và lý do gửi duyệt',
                              accent: _accent,
                            ),
                            const SizedBox(height: 12),
                            _DateTile(
                              label: 'Ngày lên chính thức *',
                              value: _officialDate == null
                                  ? 'Chọn ngày'
                                  : AppFormat.date(_officialDate),
                              accent: _accent,
                              onTap: _pickOfficialDate,
                            ),
                            const SizedBox(height: 10),
                            _MultilineField(
                              controller: _reason,
                              label: 'Lý do đề nghị / nội dung đơn *',
                              hint:
                                  'VD: Hoàn thành thời gian thử việc, đề nghị ký HĐLĐ chính thức…',
                              accent: _accent,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Nhập lý do đề nghị'
                                      : null,
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
                            const _SectionHeader(
                              icon: Icons.contact_phone_outlined,
                              title: 'Bổ sung thông tin chính thức',
                              subtitle: 'Đồng bộ hồ sơ — có thể hoàn thiện sau',
                              accent: _accent,
                            ),
                            const SizedBox(height: 12),
                            _Field(
                              controller: _phone,
                              label: 'Điện thoại',
                              accent: _accent,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 10),
                            _Field(
                              controller: _email,
                              label: 'Email',
                              accent: _accent,
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ],
                        ),
                      ),
                      if (_criteria.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ProbationScoreSheet(
                          accent: _accent,
                          formType: _formType,
                          formLabel: _formTypeLabel,
                          maxScore: _maxScore,
                          criteria: _criteria,
                          scores: _scores,
                          onChanged: (code, value) =>
                              setState(() => _scores[code] = value),
                        ),
                      ],
                      const SizedBox(height: 12),
                      AppCard(
                        accentColor: _accent,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        margin: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(
                              icon: Icons.comment_outlined,
                              title: 'Nhận xét chuyên môn',
                              subtitle: 'Không bắt buộc',
                              accent: _accent,
                            ),
                            const SizedBox(height: 12),
                            _MultilineField(
                              controller: _mentor,
                              label: 'Ý kiến người hướng dẫn',
                              accent: _accent,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 10),
                            _MultilineField(
                              controller: _headDept,
                              label: _formType == 'STAFF'
                                  ? 'Đánh giá Trưởng khoa/phòng'
                                  : 'Đánh giá Trưởng khoa',
                              accent: _accent,
                              maxLines: 3,
                            ),
                            if (_isNurse) ...[
                              const SizedBox(height: 10),
                              _MultilineField(
                                controller: _wardNurse,
                                label: 'Ý kiến ĐD trưởng khoa',
                                accent: _accent,
                                maxLines: 3,
                              ),
                              const SizedBox(height: 10),
                              _MultilineField(
                                controller: _hospitalNurse,
                                label: 'Ý kiến Trưởng phòng Điều dưỡng',
                                accent: _accent,
                                maxLines: 3,
                              ),
                            ],
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
        submitLabel: _isEdit
            ? 'Lưu thay đổi'
            : (_nursingFlow ? 'Gửi Trưởng phòng ĐD duyệt' : 'Gửi đơn'),
        onCancel: () => context.pop(),
        onSubmit: _submit,
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.style(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.accent,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: AppRadius.brSm,
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.style(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppTypography.style(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
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
      color: accent.withValues(alpha: 0.08),
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: AppTypography.style(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.calendar_today_rounded, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.accent,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final Color accent;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(borderRadius: AppRadius.brMd),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
      ),
    );
  }
}

class _MultilineField extends StatelessWidget {
  const _MultilineField({
    required this.controller,
    required this.label,
    required this.accent,
    this.hint,
    this.maxLines = 4,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final Color accent;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(borderRadius: AppRadius.brMd),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: accent, width: 1.4),
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
                  label: Text(
                    saving
                        ? (submitLabel == 'Lưu thay đổi'
                            ? 'Đang lưu…'
                            : 'Đang gửi…')
                        : submitLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
