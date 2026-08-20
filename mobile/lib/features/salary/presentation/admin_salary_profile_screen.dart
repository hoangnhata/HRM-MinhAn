import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/employee.dart';
import '../../../shared/models/salary_models.dart';
import '../../attendance/presentation/attendance_employee_picker.dart';
import '../data/salary_helpers.dart';
import '../data/salary_repository.dart';

class AdminSalaryProfileScreen extends ConsumerStatefulWidget {
  const AdminSalaryProfileScreen({super.key, this.initialEmployee});

  final EmployeeSummary? initialEmployee;

  @override
  ConsumerState<AdminSalaryProfileScreen> createState() =>
      _AdminSalaryProfileScreenState();
}

class _AdminSalaryProfileScreenState
    extends ConsumerState<AdminSalaryProfileScreen> {
  EmployeeSummary? _employee;
  SalaryProfile? _profile;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  String _category = 'EMPLOYEE';
  String _block = 'DIRECT';
  String _qualification = kEmployeeQualifications.last;
  String _doctorCode = 'CCHN';
  DateTime? _scaleStart;
  DateTime? _asOf = DateTime.tryParse(kDefaultSeniorityAsOf);
  final _baseYears = TextEditingController();
  final _degreeYears = TextEditingController(text: '0');
  final _note = TextEditingController();
  bool _ldg = false;
  final _early = <EarlyRaiseConversion>[];

  @override
  void initState() {
    super.initState();
    _employee = widget.initialEmployee;
    if (_employee != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _baseYears.dispose();
    _degreeYears.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickEmployee() async {
    final picked = await showAttendanceEmployeePicker(
      context,
      title: 'Chọn nhân viên xem lương',
      highlightId: _employee?.id,
      statusGroup: 'WORKING',
    );
    if (!mounted || picked == null) return;
    setState(() => _employee = picked);
    await _load();
  }

  Future<void> _load() async {
    final id = _employee?.id;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ref.read(salaryRepositoryProvider).profile(id);
      if (!mounted) return;
      _applyProfile(profile);
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        _profile = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được hồ sơ lương';
        _profile = null;
      });
    }
  }

  void _applyProfile(SalaryProfile p) {
    _category = p.salaryCategory ?? 'EMPLOYEE';
    _block = p.employeeBlock ?? 'DIRECT';
    _qualification = p.qualification ?? kEmployeeQualifications.last;
    _doctorCode = p.doctorQualificationCode ?? 'CCHN';
    _scaleStart = AppFormat.tryParseDate(p.salaryScaleStartDate);
    _asOf = AppFormat.tryParseDate(p.seniorityAsOfDate) ??
        DateTime.tryParse(kDefaultSeniorityAsOf);
    _baseYears.text = p.baseSeniorityYears == null
        ? ''
        : AppFormat.years(p.baseSeniorityYears);
    _degreeYears.text = AppFormat.years(p.degreeConversionYears ?? 0);
    _note.text = p.qualificationNote ?? '';
    _ldg = p.ldg;
    _early
      ..clear()
      ..addAll(p.earlyRaiseConversions);
  }

  num get _priorYears =>
      _early.fold<num>(0, (s, e) => s + e.years);

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    onPicked(picked);
  }

  String _iso(DateTime? d) => d == null
      ? ''
      : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final id = _employee?.id;
    final profile = _profile;
    if (id == null || profile == null || !profile.canEdit || _saving) return;
    final base = num.tryParse(_baseYears.text.replaceAll(',', '.'));
    final startIso = _scaleStart == null ? null : _iso(_scaleStart);
    final hasBase = hasSeniorityMilestone(
      baseSeniorityYears: base,
      salaryScaleStartDate: startIso,
    );
    if (!_ldg && startIso == null && !hasBase) {
      showAppSnackBar(
        context,
        'Nhập thâm niên mốc 30/06 hoặc chọn ngày bắt đầu tính thang.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final conversions = [
        for (final e in _early)
          if ((e.raiseDate ?? '').isNotEmpty)
            {
              'raiseDate': e.raiseDate!.length >= 10
                  ? e.raiseDate!.substring(0, 10)
                  : e.raiseDate,
              'years': e.years,
            },
      ];
      final body = <String, dynamic>{
        'salaryCategory': _category,
        'employeeBlock': _category == 'EMPLOYEE' ? _block : null,
        'qualification': _category == 'EMPLOYEE' ? _qualification : null,
        'tierGroup': tierGroupFromQualification(_qualification),
        'doctorQualificationCode': _category == 'DOCTOR' ? _doctorCode : null,
        'qualificationNote': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'degreeConversionYears':
            num.tryParse(_degreeYears.text.replaceAll(',', '.')) ?? 0,
        'priorRaiseYears': _priorYears,
        'earlyRaiseConversions': conversions,
        'salaryScaleStartDate': startIso,
        'baseSeniorityYears': _ldg || !hasBase ? null : base,
        'seniorityAsOfDate': _ldg || !hasBase
            ? null
            : _iso(_asOf ?? DateTime.tryParse(kDefaultSeniorityAsOf)),
        'ldg': _ldg,
      };
      final updated =
          await ref.read(salaryRepositoryProvider).upsertProfile(id, body);
      if (!mounted) return;
      _applyProfile(updated);
      setState(() {
        _profile = updated;
        _saving = false;
      });
      showAppSnackBar(context, 'Đã lưu hồ sơ lương', isSuccess: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, 'Không lưu được hồ sơ lương', isError: true);
    }
  }

  Future<void> _addEarlyRaise() async {
    final result = await showModalBottomSheet<(DateTime, num)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _EarlyRaiseSheet(),
    );
    if (result == null) return;
    setState(() {
      _early
        ..add(EarlyRaiseConversion(raiseDate: _iso(result.$1), years: result.$2))
        ..sort((a, b) => (a.raiseDate ?? '').compareTo(b.raiseDate ?? ''));
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final preview = liveSeniorityPreview(
      baseSeniorityYears: num.tryParse(_baseYears.text.replaceAll(',', '.')),
      seniorityAsOfDate: _iso(_asOf),
      salaryScaleStartDate: _iso(_scaleStart),
      priorRaiseYears: _priorYears,
      degreeConversionYears:
          num.tryParse(_degreeYears.text.replaceAll(',', '.')),
      ldg: _ldg,
    );
    final onBrand = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.7)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: 'Hồ sơ lương',
                icon: Icons.payments_rounded,
                eyebrow: 'Quản lý',
                subtitle: profile == null
                    ? 'Chọn nhân viên để xem và chỉnh'
                    : profile.objectLabel,
                onBack: () => context.pop(),
                footer: _HeaderEmployeeChip(
                  employee: _employee,
                  onBrand: onBrand,
                  onTap: _pickEmployee,
                ),
              ),
              Expanded(child: _buildBody(profile, preview)),
            ],
          ),
        ],
      ),
      bottomNavigationBar: profile?.canEdit == true
          ? Material(
              color: AppColors.surface,
              elevation: 8,
              shadowColor: AppColors.primaryDark.withValues(alpha: 0.12),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_saving ? 'Đang lưu…' : 'Lưu cấu hình'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.brMd,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(SalaryProfile? profile, String preview) {
    if (_employee == null) {
      return const EmptyState(
        icon: Icons.person_search_rounded,
        title: 'Chọn nhân viên',
        message: 'Chạm dòng trên header để tìm nhân viên và mở hồ sơ lương.',
      );
    }
    if (_loading && profile == null) {
      return const SkeletonList(itemCount: 5, showAvatar: false);
    }
    if (_error != null && profile == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (profile == null) {
      return const EmptyState(
        icon: Icons.info_outline_rounded,
        title: 'Chưa có hồ sơ lương',
        message: 'Nhân viên này chưa được cấu hình đối tượng lương.',
      );
    }

    final bh = profile.insuranceSalary ?? 0;
    final sp = profile.productSalary ?? 0;
    final total = (profile.totalSalary ?? (bh + sp)).toDouble();
    final bhShare = total <= 0 ? 0.0 : (bh / total).clamp(0.0, 1.0);

    final editable = profile.canEdit;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          14,
          AppSpacing.page,
          28,
        ),
        children: [
          AppReveal(
            offset: 10,
            child: _TotalHero(
              total: AppFormat.currency(profile.totalSalary),
              grade: profile.displayGradeLabel,
              objectLabel: profile.objectLabel,
              qualification:
                  _category == 'DOCTOR' ? _doctorLabel : _qualification,
              coefficient: profile.coefficient == null
                  ? null
                  : AppFormat.compactNumber(profile.coefficient),
              ldg: _ldg,
            ),
          ),
          const SizedBox(height: 10),
          _PaySplit(
            insurance: AppFormat.currency(profile.insuranceSalary),
            product: AppFormat.currency(profile.productSalary),
            insuranceShare: bhShare,
          ),
          const SizedBox(height: 10),
          _MetricStrip(
            start: AppFormat.date(_scaleStart),
            seniority: preview,
            coefficient: profile.coefficient == null
                ? '—'
                : AppFormat.compactNumber(profile.coefficient),
          ),
          if (!editable) ...[
            const SizedBox(height: 12),
            const _ReadOnlyBanner(),
          ],
          const SizedBox(height: 18),
          IgnorePointer(
            ignoring: !editable,
            child: Opacity(
              opacity: editable ? 1 : 0.82,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionLabel(text: 'Đối tượng & trình độ'),
                  const SizedBox(height: 8),
                  _ConfigCard(
                    children: [
                      _Segmented(
                        options: const [
                          ('EMPLOYEE', 'Nhân viên'),
                          ('DOCTOR', 'Bác sỹ'),
                        ],
                        selected: _category,
                        onSelected: (v) => setState(() => _category = v),
                      ),
                      if (_category == 'EMPLOYEE') ...[
                        const SizedBox(height: 12),
                        _Segmented(
                          options: const [
                            ('DIRECT', 'Trực tiếp'),
                            ('INDIRECT', 'Gián tiếp'),
                          ],
                          selected: _block,
                          onSelected: (v) => setState(() => _block = v),
                        ),
                        const SizedBox(height: 10),
                        _FieldTile(
                          icon: Icons.school_outlined,
                          label: 'Trình độ',
                          value: _qualification,
                          onTap: () => _pickOption(
                            title: 'Trình độ',
                            options: [
                              for (final q in kEmployeeQualifications) (q, q),
                            ],
                            selected: _qualification,
                            onSelected: (v) =>
                                setState(() => _qualification = v),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 10),
                        _FieldTile(
                          icon: Icons.medical_services_outlined,
                          label: 'Trình độ thang bảng',
                          value: _doctorLabel,
                          onTap: () => _pickOption(
                            title: 'Trình độ bác sỹ',
                            options: kDoctorQualifications,
                            selected: _doctorCode,
                            onSelected: (v) =>
                                setState(() => _doctorCode = v),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _NumberField(
                          controller: _degreeYears,
                          label: 'Quy đổi bằng cấp (năm)',
                          onChanged: () => setState(() {}),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionLabel(text: 'Thâm niên'),
                  const SizedBox(height: 8),
                  _ConfigCard(
                    children: [
                      _LivePreviewBanner(text: preview, ldg: _ldg),
                      const SizedBox(height: 10),
                      _FieldTile(
                        icon: Icons.event_outlined,
                        label: 'Bắt đầu tính thang',
                        value: _scaleStart == null
                            ? 'Chưa chọn'
                            : AppFormat.date(_scaleStart),
                        onTap: () => _pickDate(
                          current: _scaleStart,
                          onPicked: (d) => setState(() => _scaleStart = d),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _NumberField(
                        controller: _baseYears,
                        label: 'Thâm niên mốc 30/06 (năm)',
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      _FieldTile(
                        icon: Icons.flag_outlined,
                        label: 'Ngày chốt mốc',
                        value: _asOf == null
                            ? 'Chưa chọn'
                            : AppFormat.date(_asOf),
                        onTap: () => _pickDate(
                          current: _asOf,
                          onPicked: (d) => setState(() => _asOf = d),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _LdgSwitch(
                        value: _ldg,
                        onChanged: (v) => setState(() => _ldg = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionLabel(
                    text: 'Nâng lương sớm',
                    action: editable
                        ? TextButton.icon(
                            onPressed: _addEarlyRaise,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Thêm'),
                          )
                        : null,
                  ),
                  const SizedBox(height: 4),
                  _ConfigCard(
                    children: [
                      if (_early.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.history_rounded,
                                size: 18,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Chưa có lần quy đổi. Tổng ${_formatYears(_priorYears)} năm.',
                                  style: AppTypography.style(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final (i, e) in _early.indexed)
                          _EarlyRaiseRow(
                            date: AppFormat.date(
                              AppFormat.tryParseDate(e.raiseDate),
                            ),
                            years: '${AppFormat.years(e.years)} năm',
                            onRemove: editable
                                ? () => setState(() => _early.removeAt(i))
                                : null,
                          ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionLabel(text: 'Ghi chú'),
                  const SizedBox(height: 8),
                  _ConfigCard(
                    children: [
                      TextField(
                        controller: _note,
                        maxLines: 3,
                        enabled: editable,
                        decoration: const InputDecoration(
                          hintText: 'Trình độ / ghi chú thêm',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _doctorLabel => kDoctorQualifications
      .firstWhere(
        (e) => e.$1 == _doctorCode,
        orElse: () => (_doctorCode, _doctorCode),
      )
      .$2;

  String _formatYears(num value) => '${AppFormat.years(value)} năm';

  Future<void> _pickOption({
    required String title,
    required List<(String, String)> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTypography.style(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final o in options)
              ListTile(
                title: Text(o.$2),
                trailing: o.$1 == selected
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, o.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) onSelected(picked);
  }
}

class _HeaderEmployeeChip extends StatelessWidget {
  const _HeaderEmployeeChip({
    required this.employee,
    required this.onBrand,
    required this.onTap,
  });

  final EmployeeSummary? employee;
  final Color onBrand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = employee?.fullName ?? 'Chọn nhân viên';
    final meta = [
      if ((employee?.employeeCode ?? '').isNotEmpty) employee!.employeeCode,
      if ((employee?.departmentName ?? '').isNotEmpty) employee!.departmentName,
    ].join(' · ');
    return Material(
      color: onBrand.withValues(alpha: 0.14),
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
            children: [
              AppAvatar(
                name: name,
                imageUrl: employee?.avatarUrl,
                size: 36,
                showShadow: false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: onBrand,
                      ),
                    ),
                    Text(
                      meta.isEmpty ? 'Chạm để đổi nhân viên' : meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        color: onBrand.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.swap_horiz_rounded, color: onBrand, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalHero extends StatelessWidget {
  const _TotalHero({
    required this.total,
    required this.grade,
    required this.objectLabel,
    required this.qualification,
    required this.coefficient,
    required this.ldg,
  });

  final String total;
  final String grade;
  final String objectLabel;
  final String qualification;
  final String? coefficient;
  final bool ldg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.tinted(AppColors.primary),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -34,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 36,
            bottom: -44,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TỔNG LƯƠNG HIỆN TẠI',
                          style: AppTypography.style(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.65,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          objectLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  total,
                  style: AppTypography.metric(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _HeroChip(icon: Icons.military_tech_rounded, label: grade),
                  if (qualification.isNotEmpty)
                    _HeroChip(
                      icon: Icons.school_rounded,
                      label: qualification,
                    ),
                  if (coefficient != null && coefficient != '—')
                    _HeroChip(
                      icon: Icons.functions_rounded,
                      label: 'Hệ số $coefficient',
                    ),
                  if (ldg)
                    const _HeroChip(
                      icon: Icons.lock_clock_rounded,
                      label: 'LĐG',
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.92)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaySplit extends StatelessWidget {
  const _PaySplit({
    required this.insurance,
    required this.product,
    required this.insuranceShare,
  });

  final String insurance;
  final String product;
  final double insuranceShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PayCol(label: 'Lương đóng BH', value: insurance),
              ),
              Container(width: 1, height: 36, color: AppColors.borderSoft),
              Expanded(
                child: _PayCol(label: 'Đảm bảo SP', value: product),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: AppRadius.brPill,
            child: LinearProgressIndicator(
              value: insuranceShare.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.primary.withValues(alpha: 0.18),
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayCol extends StatelessWidget {
  const _PayCol({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.style(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.style(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            tabular: true,
          ),
        ),
      ],
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({
    required this.start,
    required this.seniority,
    required this.coefficient,
  });

  final String start;
  final String seniority;
  final String coefficient;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Metric(
            icon: Icons.calendar_month_rounded,
            label: 'Bắt đầu',
            value: start,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Metric(
            icon: Icons.trending_up_rounded,
            label: 'Thâm niên',
            value: seniority,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Metric(
            icon: Icons.functions_rounded,
            label: 'Hệ số',
            value: coefficient,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: AppColors.warningDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Chỉ xem — tài khoản này không được sửa hồ sơ lương.',
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.warningText,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: AppTypography.style(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: AppColors.primaryDark,
          ),
        ),
        const Spacer(),
        ?action,
      ],
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Material(
                color: o.$1 == selected ? AppColors.surface : Colors.transparent,
                borderRadius: AppRadius.brSm,
                elevation: o.$1 == selected ? 1 : 0,
                shadowColor: AppColors.primaryDark.withValues(alpha: 0.12),
                child: InkWell(
                  onTap: () => onSelected(o.$1),
                  borderRadius: AppRadius.brSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text(
                      o.$2,
                      textAlign: TextAlign.center,
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: o.$1 == selected
                            ? AppColors.primaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: AppRadius.brSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brSm,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.style(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      value,
                      style: AppTypography.style(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surfaceMuted,
      ),
    );
  }
}

class _LivePreviewBanner extends StatelessWidget {
  const _LivePreviewBanner({required this.text, required this.ldg});
  final String text;
  final bool ldg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        children: [
          Icon(
            ldg ? Icons.lock_clock_outlined : Icons.auto_graph_rounded,
            size: 18,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ldg ? 'LĐG — không tính thâm niên theo thang' : 'Xem trước: $text',
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LdgSwitch extends StatelessWidget {
  const _LdgSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(
        'LĐG — bậc cố định',
        style: AppTypography.style(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
      subtitle: Text(
        'Không nhảy bậc theo thâm niên',
        style: AppTypography.style(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}

class _EarlyRaiseRow extends StatelessWidget {
  const _EarlyRaiseRow({
    required this.date,
    required this.years,
    this.onRemove,
  });

  final String date;
  final String years;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: AppRadius.brSm,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_rounded,
                size: 15,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                date,
                style: AppTypography.style(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              years,
              style: AppTypography.style(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            if (onRemove != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _EarlyRaiseSheet extends StatefulWidget {
  const _EarlyRaiseSheet();

  @override
  State<_EarlyRaiseSheet> createState() => _EarlyRaiseSheetState();
}

class _EarlyRaiseSheetState extends State<_EarlyRaiseSheet> {
  DateTime? _date;
  final _years = TextEditingController(text: '1');

  @override
  void dispose() {
    _years.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
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
              'Thêm nâng lương sớm',
              style: AppTypography.style(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded, color: AppColors.primary),
              title: Text(
                _date == null ? 'Chọn ngày nâng lương' : AppFormat.date(_date),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date ?? DateTime.now(),
                  firstDate: DateTime(1990),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked == null) return;
                setState(() => _date = picked);
              },
            ),
            TextField(
              controller: _years,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Hệ số năm'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final years = num.tryParse(_years.text.replaceAll(',', '.'));
                if (_date == null || years == null || years < 0) return;
                Navigator.pop(context, (_date!, years));
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Thêm'),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
