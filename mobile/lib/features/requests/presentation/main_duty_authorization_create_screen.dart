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
import 'request_create_flow_strip.dart';

/// Lập đơn chuyển trực chính — API đồng bộ web, bố cục tối ưu mobile.
class MainDutyAuthorizationCreateScreen extends ConsumerStatefulWidget {
  const MainDutyAuthorizationCreateScreen({
    super.key,
    required this.employeeId,
    this.requestId,
  });

  final int employeeId;
  final int? requestId;

  @override
  ConsumerState<MainDutyAuthorizationCreateScreen> createState() =>
      _MainDutyAuthorizationCreateScreenState();
}

class _MainDutyAuthorizationCreateScreenState
    extends ConsumerState<MainDutyAuthorizationCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  EmployeeDetail? _employee;
  DateTime? _accompanyingFrom;
  DateTime? _accompanyingTo;
  DateTime? _effectiveFrom;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.requestId != null;

  static const _accent = Color(0xFF5B4BB4);

  bool get _nursingFlow =>
      isNursingBlockTitle(_employee?.summary.positionTitle);

  String get _formLabel {
    final p = (_employee?.summary.positionTitle ?? '').toLowerCase();
    if (p.contains('bác sĩ') ||
        p.contains('bac si') ||
        RegExp(r'\bbs\b').hasMatch(p)) {
      return 'Bác sĩ';
    }
    if (p.contains('điều dưỡng') ||
        p.contains('dieu duong') ||
        p.contains('y tá') ||
        p.contains('y ta')) {
      return 'Điều dưỡng';
    }
    return 'Bác sĩ / Điều dưỡng';
  }

  List<RequestFlowStep> get _flowSteps => requestCreateFlowSteps(
        mainDutyFlowLabels(_employee?.summary.positionTitle),
      );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _accompanyingTo = now;
    _effectiveFrom = now;
    _accompanyingFrom = DateTime(now.year, now.month - 3, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _normalizeGender(String? raw) {
    final g = (raw ?? '').trim().toLowerCase();
    if (g == 'nam' || g == 'male' || g == 'm') return 'Nam';
    if (g == 'nữ' || g == 'nu' || g == 'female' || g == 'f') return 'Nữ';
    if (raw == 'Nam' || raw == 'Nữ') return raw!;
    return (raw ?? '').trim();
  }

  Future<void> _load() async {
    try {
      final emp = await ref
          .read(employeeRepositoryProvider)
          .detail(widget.employeeId);
      Map<String, dynamic>? existing;
      if (_isEdit) {
        existing = await ref.read(genericRequestRepositoryProvider).byId(
              RequestTypeConfig.byKey('main-duty-authorization'),
              widget.requestId!,
            );
        if (existing.isEmpty) throw StateError('empty');
      }
      if (!mounted) return;
      final hire = DateTime.tryParse(emp.summary.hireDate ?? '');
      setState(() {
        _employee = emp;
        if (existing != null) {
          _accompanyingFrom =
              DateTime.tryParse(existing['accompanyingFrom']?.toString() ?? '');
          _accompanyingTo =
              DateTime.tryParse(existing['accompanyingTo']?.toString() ?? '');
          _effectiveFrom =
              DateTime.tryParse(existing['effectiveFrom']?.toString() ?? '');
          _reason.text = existing['reason']?.toString() ?? '';
        } else if (hire != null) {
          _accompanyingFrom = hire;
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
            : 'Không tải được hồ sơ nhân viên',
        isError: true,
      );
      context.pop();
    }
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({
    required String title,
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context,
      title: title,
      initialDate: current ?? now,
      firstDate: firstDate ?? DateTime(now.year - 5),
      lastDate: lastDate ?? DateTime(now.year + 2),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final from = _accompanyingFrom;
    final to = _accompanyingTo;
    final effective = _effectiveFrom;
    final emp = _employee;
    if (emp == null || from == null || to == null || effective == null) {
      showAppSnackBar(
        context,
        'Nhập đủ thời gian trực kèm và ngày hiệu lực trực chính.',
        isError: true,
      );
      return;
    }
    if (to.isBefore(from)) {
      showAppSnackBar(
        context,
        'Ngày kết thúc trực kèm phải sau hoặc bằng ngày bắt đầu',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final gender = _normalizeGender(emp.gender);
      final config = RequestTypeConfig.byKey('main-duty-authorization');
      final body = {
        'employeeId': widget.employeeId,
        'accompanyingFrom': _iso(from),
        'accompanyingTo': _iso(to),
        'effectiveFrom': _iso(effective),
        if ((emp.phone ?? '').trim().isNotEmpty) 'phone': emp.phone!.trim(),
        if ((emp.address ?? '').trim().isNotEmpty)
          'address': emp.address!.trim(),
        if (gender.isNotEmpty) 'gender': gender,
        if ((emp.degree ?? '').trim().isNotEmpty) 'degree': emp.degree!.trim(),
        if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
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
      ref.invalidate(
        genericRequestControllerProvider('main-duty-authorization'),
      );
      final id = _isEdit
          ? widget.requestId
          : (result['id'] as num?)?.toInt();
      showAppSnackBar(
        context,
        _isEdit ? 'Đã lưu thay đổi' : 'Đã gửi đơn chuyển trực chính',
        isSuccess: true,
      );
      context.pop();
      if (id != null) {
        context.push(
          RoutePaths.requestDetailPath('main-duty-authorization', id),
        );
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Không gửi được. Kiểm tra quyền hoặc đơn đang chờ duyệt.',
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
                  title: 'Trực chính',
                  icon: Icons.nights_stay_rounded,
                  eyebrow: 'Phiếu đề xuất',
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
    final dob = AppFormat.date(AppFormat.tryParseDate(emp.dateOfBirth));
    final gender = _normalizeGender(emp.gender);

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
                    ? 'Chỉnh sửa đơn trực chính'
                    : 'Chuyển từ trực kèm lên trực chính',
                icon: Icons.nights_stay_rounded,
                eyebrow: _isEdit
                    ? 'Chỉnh sửa phiếu'
                    : 'Đơn được trực chính · $_formLabel',
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
                        icon: Icons.info_outline_rounded,
                        message: _nursingFlow
                            ? 'Mẫu $_formLabel — khối ĐD–KTV–HS–Thư ký. Sau khi gửi: Trưởng phòng Điều dưỡng → Giám đốc. Trước khi duyệt chỉ nhập ca Trực kèm (TK).'
                            : 'Mẫu $_formLabel. Sau khi Giám đốc duyệt, nhân viên được chọn ca trực chính (1, 3, 5) ngoài Trực kèm.',
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        accentColor: _accent,
                        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                        margin: EdgeInsets.zero,
                        child: Row(
                          children: [
                            AppAvatar(
                              name: s.fullName,
                              imageUrl: s.avatarUrl,
                              size: 52,
                              borderColor: _accent.withValues(alpha: 0.25),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.fullName,
                                    style: AppTypography.style(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _MiniChip(
                                        label: 'Trực kèm',
                                        color: AppColors.warning,
                                      ),
                                      if ((s.positionTitle ?? '').isNotEmpty)
                                        _MiniChip(
                                          label: s.positionTitle!,
                                          color: _accent,
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
                                    'main-duty-authorization',
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
                              icon: Icons.badge_outlined,
                              title: 'Thông tin nhân viên',
                              subtitle: 'Lấy từ hồ sơ — không cần nhập lại',
                              accent: _accent,
                            ),
                            const SizedBox(height: 12),
                            _FactGrid(
                              accent: _accent,
                              items: [
                                (Icons.person_outline_rounded, 'Họ và tên', s.fullName),
                                (
                                  Icons.work_outline_rounded,
                                  'Chức danh',
                                  (s.positionTitle ?? '').trim().isEmpty
                                      ? '—'
                                      : s.positionTitle!,
                                ),
                                (
                                  Icons.apartment_rounded,
                                  'Khoa / phòng',
                                  (s.departmentName ?? '').trim().isEmpty
                                      ? '—'
                                      : s.departmentName!,
                                ),
                                (Icons.cake_outlined, 'Ngày sinh', dob),
                                (
                                  Icons.phone_outlined,
                                  'Điện thoại',
                                  (emp.phone ?? '').trim().isEmpty
                                      ? '—'
                                      : emp.phone!.trim(),
                                ),
                                (
                                  Icons.wc_outlined,
                                  'Giới tính',
                                  gender.isEmpty ? '—' : gender,
                                ),
                                (
                                  Icons.home_outlined,
                                  'Địa chỉ',
                                  (emp.address ?? '').trim().isEmpty
                                      ? '—'
                                      : emp.address!.trim(),
                                ),
                                (
                                  Icons.school_outlined,
                                  'Bằng cấp / trình độ',
                                  (emp.degree ?? '').trim().isEmpty
                                      ? '—'
                                      : emp.degree!.trim(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        accentColor: _accent,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        margin: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(
                              icon: Icons.event_available_rounded,
                              title: 'Thời gian & hiệu lực',
                              subtitle:
                                  'Thời gian đã trực kèm và ngày bắt đầu trực chính',
                              accent: _accent,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _DateTile(
                                    label: 'Trực kèm từ *',
                                    value: _accompanyingFrom == null
                                        ? 'Chọn ngày'
                                        : AppFormat.date(_accompanyingFrom),
                                    accent: _accent,
                                    onTap: () => _pickDate(
                                      title: 'Trực kèm từ ngày',
                                      current: _accompanyingFrom,
                                      onPicked: (d) => setState(() {
                                        _accompanyingFrom = d;
                                        if (_accompanyingTo != null &&
                                            _accompanyingTo!.isBefore(d)) {
                                          _accompanyingTo = d;
                                        }
                                      }),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(6, 18, 6, 0),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: _accent.withValues(alpha: 0.55),
                                  ),
                                ),
                                Expanded(
                                  child: _DateTile(
                                    label: 'Trực kèm đến *',
                                    value: _accompanyingTo == null
                                        ? 'Chọn ngày'
                                        : AppFormat.date(_accompanyingTo),
                                    accent: _accent,
                                    onTap: () => _pickDate(
                                      title: 'Trực kèm đến ngày',
                                      current:
                                          _accompanyingTo ?? _accompanyingFrom,
                                      firstDate: _accompanyingFrom,
                                      onPicked: (d) =>
                                          setState(() => _accompanyingTo = d),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _DateTile(
                              label: 'Hiệu lực trực chính từ *',
                              value: _effectiveFrom == null
                                  ? 'Chọn ngày'
                                  : AppFormat.date(_effectiveFrom),
                              accent: _accent,
                              emphasized: true,
                              onTap: () => _pickDate(
                                title: 'Ngày hiệu lực trực chính',
                                current: _effectiveFrom,
                                onPicked: (d) =>
                                    setState(() => _effectiveFrom = d),
                              ),
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
                              icon: Icons.notes_rounded,
                              title: 'Lý do / đề nghị',
                              subtitle: 'Tuỳ chọn — theo mẫu đơn giấy',
                              accent: _accent,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _reason,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText:
                                    'Đề nghị chuyển từ trực kèm lên trực chính…',
                                alignLabelWithHint: true,
                                filled: true,
                                fillColor: AppColors.surfaceMuted,
                                border: OutlineInputBorder(
                                  borderRadius: AppRadius.brMd,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: AppRadius.brMd,
                                  borderSide: const BorderSide(
                                    color: AppColors.borderSoft,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: AppRadius.brMd,
                                  borderSide: const BorderSide(
                                    color: _accent,
                                    width: 1.4,
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

class _FactGrid extends StatelessWidget {
  const _FactGrid({required this.accent, required this.items});

  final Color accent;
  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < items.length ? 8 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _FactTile(accent: accent, item: items[i])),
                const SizedBox(width: 8),
                Expanded(
                  child: i + 1 < items.length
                      ? _FactTile(accent: accent, item: items[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.accent, required this.item});

  final Color accent;
  final (IconData, String, String) item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.$1, size: 13, color: accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  item.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.$3,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized
          ? accent.withValues(alpha: 0.08)
          : AppColors.surfaceMuted,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: emphasized
              ? BoxDecoration(
                  borderRadius: AppRadius.brMd,
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                )
              : null,
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
                        color: emphasized ? accent : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
