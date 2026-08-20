import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/router/shell_tab.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/employee.dart';
import '../../auth/application/auth_controller.dart';
import '../application/employee_list_controller.dart';
import '../data/employee_document_repository.dart';
import '../data/employee_repository.dart';
import '../data/workforce_labels.dart';

final employeeDetailProvider = FutureProvider.autoDispose
    .family<EmployeeDetail, int>((ref, id) {
      return ref.watch(employeeRepositoryProvider).detail(id);
    });

final myEmployeeDetailProvider = FutureProvider.autoDispose<EmployeeDetail>((
  ref,
) {
  return ref.watch(employeeRepositoryProvider).me();
});

const _statusLabels = {
  'OFFICIAL': 'Chính thức',
  'ACTIVE': 'Chính thức',
  'TRIAL': 'Thử việc',
  'PROBATION': 'Thử việc',
  'INTERN': 'Thực tập',
  'TERMINATED': 'Đã nghỉ việc',
  'MATERNITY_LEAVE': 'Nghỉ thai sản',
  'ON_LEAVE': 'Nghỉ phép',
};

Color _statusColor(String? status) {
  switch (status?.toUpperCase()) {
    case 'PROBATION':
    case 'TRIAL':
    case 'INTERN':
      return AppColors.warning;
    case 'TERMINATED':
      return AppColors.error;
    case 'MATERNITY_LEAVE':
    case 'ON_LEAVE':
      return AppColors.info;
    default:
      return AppColors.success;
  }
}

IconData _sectionIcon(String title) {
  switch (title) {
    case 'Chuyên môn & chứng chỉ':
      return Icons.school_rounded;
    case 'Lương & ngân hàng':
      return Icons.account_balance_wallet_rounded;
    case 'Bảo hiểm':
      return Icons.health_and_safety_outlined;
    case 'Ngày thử việc & chính thức':
      return Icons.event_available_rounded;
    case 'Hợp đồng (Excel)':
      return Icons.description_outlined;
    default:
      return Icons.info_outline_rounded;
  }
}

String _pretty(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return trimmed;
  final letters = trimmed.replaceAll(RegExp(r'[^A-Za-zÀ-ỹ]'), '');
  if (letters.isEmpty) return trimmed;
  var upper = 0;
  for (final u in letters.runes) {
    final ch = String.fromCharCode(u);
    if (ch == ch.toUpperCase()) upper++;
  }
  if (upper / letters.length < 0.65) return trimmed;
  return trimmed
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((w) {
        if (w.isEmpty) return w;
        if (w.length <= 3 && RegExp(r'^[a-zà-ỹ]+$').hasMatch(w)) {
          return w.toUpperCase();
        }
        return '${w[0].toUpperCase()}${w.substring(1)}';
      })
      .join(' ');
}

String _formatProfileValue(String key, Object? value) {
  if (value == null) return '—';
  final text = value.toString().trim();
  if (text.isEmpty) return '—';
  if (key.toLowerCase().contains('date') ||
      RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(text)) {
    final parsed = AppFormat.tryParseDate(text);
    if (parsed != null) return AppFormat.date(parsed);
  }
  if (key == 'otherTrainingCertificates') {
    final lines = text
        .split(RegExp(r'[\n;•]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.startsWith('-') ? e : '• $e')
        .toList();
    if (lines.length > 1) return lines.join('\n');
  }
  return text;
}

/// Hồ sơ nhân viên — đầy đủ dữ liệu API, UI mobile chuyên nghiệp.
class EmployeeDetailScreen extends ConsumerWidget {
  const EmployeeDetailScreen({
    super.key,
    this.employeeId,
    this.self = false,
  });

  final int? employeeId;
  final bool self;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = self
        ? ref.watch(myEmployeeDetailProvider)
        : ref.watch(employeeDetailProvider(employeeId!));

    Future<void> refresh() async {
      if (self) {
        final detail = await ref.refresh(myEmployeeDetailProvider.future);
        ref.invalidate(employeeDocumentsProvider(detail.summary.id));
      } else {
        final _ = await ref.refresh(employeeDetailProvider(employeeId!).future);
        ref.invalidate(employeeDocumentsProvider(employeeId!));
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: async.when(
        loading: () => const SafeArea(child: SkeletonList(itemCount: 6)),
        error: (e, _) => SafeArea(
          child: ErrorState(
            message: 'Không tải được hồ sơ nhân viên',
            onRetry: () {
              if (self) {
                ref.invalidate(myEmployeeDetailProvider);
              } else {
                ref.invalidate(employeeDetailProvider(employeeId!));
              }
            },
          ),
        ),
        data: (detail) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: refresh,
          child: _Body(detail: detail, isSelf: self),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail, required this.isSelf});

  final EmployeeDetail detail;
  final bool isSelf;

  Future<void> _openActions(BuildContext context, WidgetRef ref) async {
    final s = detail.summary;
    final role = ref.read(authControllerProvider).role;
    final terminated = (s.status ?? '').toUpperCase() == 'TERMINATED';
    final canEditTerminate = role == UserRole.admin || role == UserRole.hr;
    final canTransfer =
        !terminated && (role == UserRole.admin || role == UserRole.hr);
    final canTrainingSeminar = !terminated &&
        (role == UserRole.admin || role == UserRole.headDepartment);
    final canMainDuty = !terminated &&
        !s.mainDutyAuthorized &&
        (role == UserRole.admin || role == UserRole.headDepartment);
    final canConversion = !terminated &&
        detail.isTrialEmployee &&
        (role == UserRole.admin || role == UserRole.headDepartment);

    final action = await showAppBottomSheet<String>(
      context,
      title: 'Thao tác hồ sơ',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canEditTerminate)
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: const Icon(Icons.edit_rounded, color: AppColors.primary),
              ),
              title: Text(
                'Sửa hồ sơ',
                style: AppTypography.style(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Cập nhật thông tin nhân viên'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
          if (canTransfer)
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  color: AppColors.primary,
                ),
              ),
              title: Text(
                'Luân chuyển phòng ban',
                style: AppTypography.style(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Gửi Giám đốc duyệt · ngày hiệu lực'),
              onTap: () => Navigator.pop(context, 'transfer'),
            ),
          if (canTrainingSeminar) ...[
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  borderRadius: AppRadius.brSm,
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: AppColors.warning,
                ),
              ),
              title: Text(
                'Cử đào tạo / bồi dưỡng',
                style: AppTypography.style(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('HCNS bổ sung hỗ trợ · Giám đốc duyệt'),
              onTap: () => Navigator.pop(context, 'training'),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Color(0xFF7C3AED),
                ),
              ),
              title: Text(
                'Cử hội thảo / công tác',
                style: AppTypography.style(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Gửi thẳng Giám đốc · có/không công'),
              onTap: () => Navigator.pop(context, 'seminar'),
            ),
          ],
          if (canConversion)
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: AppColors.success,
                ),
              ),
              title: Text(
                'Lên chính thức',
                style: AppTypography.style(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Đề nghị ký HĐLĐ chính thức sau thử việc'),
              onTap: () => Navigator.pop(context, 'probation'),
            ),
          if (canMainDuty)
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF5B4BB4).withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: const Icon(
                  Icons.nights_stay_rounded,
                  color: Color(0xFF5B4BB4),
                ),
              ),
              title: Text(
                'Chuyển trực chính',
                style: AppTypography.style(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Đề nghị từ trực kèm lên trực chính'),
              onTap: () => Navigator.pop(context, 'main-duty'),
            ),
          if (canEditTerminate && !terminated)
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: const Icon(
                  Icons.person_off_outlined,
                  color: AppColors.error,
                ),
              ),
              title: Text(
                'Nghỉ việc',
                style: AppTypography.style(
                  fontWeight: FontWeight.w800,
                  color: AppColors.error,
                ),
              ),
              subtitle: const Text('Khóa tài khoản · giải phóng SĐT / CCCD'),
              onTap: () => Navigator.pop(context, 'terminate'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (!context.mounted || action == null) return;

    if (action == 'edit') {
      final updated = await context.push<bool>(
        RoutePaths.employeeEditPath(s.id),
      );
      if (updated == true) {
        ref.invalidate(employeeDetailProvider(s.id));
        ref.invalidate(employeeDocumentsProvider(s.id));
        ref.read(employeeListControllerProvider.notifier).load();
      }
      return;
    }

    if (action == 'transfer' ||
        action == 'training' ||
        action == 'seminar' ||
        action == 'main-duty' ||
        action == 'probation') {
      final typeKey = switch (action) {
        'transfer' => 'department-transfer',
        'training' => 'training-proposal',
        'main-duty' => 'main-duty-authorization',
        'probation' => 'probation-conversion',
        _ => 'seminar-proposal',
      };
      await context.push(
        RoutePaths.requestCreatePath(typeKey, employeeId: s.id),
      );
      return;
    }

    if (action == 'terminate') {
      final ok = await showConfirmDialog(
        context,
        title: 'Xác nhận nghỉ việc',
        message:
            'Ghi nhận nghỉ việc cho ${s.fullName}? Tài khoản sẽ bị khóa; SĐT, CCCD và tên đăng nhập được giải phóng để có thể tạo lại hồ sơ mới nếu cần.',
        confirmLabel: 'Nghỉ việc',
        danger: true,
        icon: Icons.person_off_outlined,
      );
      if (!ok || !context.mounted) return;
      try {
        await ref.read(employeeRepositoryProvider).terminate(s.id);
        if (!context.mounted) return;
        showAppSnackBar(context, 'Đã cập nhật trạng thái nghỉ việc', isSuccess: true);
        ref.invalidate(employeeDetailProvider(s.id));
        ref.read(employeeListControllerProvider.notifier).load();
      } on ApiException catch (e) {
        if (context.mounted) showAppSnackBar(context, e.message, isError: true);
      } catch (_) {
        if (context.mounted) {
          showAppSnackBar(context, 'Không ghi nhận nghỉ việc được', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = detail.summary;
    final auth = ref.watch(authControllerProvider);
    final role = auth.role;
    final canEditTerminate = role == UserRole.admin || role == UserRole.hr;
    final canTransfer = role == UserRole.admin || role == UserRole.hr;
    final canTrainingSeminar =
        role == UserRole.admin || role == UserRole.headDepartment;
    final terminated = (s.status ?? '').toUpperCase() == 'TERMINATED';
    final canMainDuty = !terminated &&
        !s.mainDutyAuthorized &&
        (role == UserRole.admin || role == UserRole.headDepartment);
    final canConversion = !terminated &&
        detail.isTrialEmployee &&
        (role == UserRole.admin || role == UserRole.headDepartment);
    final canShowActions = canEditTerminate ||
        canTransfer ||
        canTrainingSeminar ||
        canMainDuty ||
        canConversion;
    final viewingSelf =
        isSelf ||
        (auth.employeeId != null && auth.employeeId == s.id) ||
        (auth.currentUser?.employeeId != null &&
            auth.currentUser!.employeeId == s.id);
    final trialOnlyView = detail.isTrialEmployee && !viewingSelf;
    final subtitle = [
      if ((s.departmentName ?? '').trim().isNotEmpty)
        _pretty(s.departmentName),
      if ((s.positionTitle ?? '').trim().isNotEmpty) _pretty(s.positionTitle),
    ].join(' · ');

    final profile = detail.workforceProfile;
    final allSectionKeys = <String>{
      for (final section in workforceSections) ...section.keys,
    };
    final orphanKeys = profile.keys
        .where((k) => hasWorkforceValue(profile[k]) && !allSectionKeys.contains(k))
        .toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: _HeroHeader(
            detail: detail,
            subtitle: subtitle,
            onActions: canShowActions ? () => _openActions(context, ref) : null,
          ),
        ),
        if (canConversion)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                4,
                AppSpacing.page,
                8,
              ),
              child: _RequestPromoCard(
                icon: Icons.badge_outlined,
                accent: AppColors.success,
                title: 'Lên chính thức',
                subtitle:
                    'Nhân viên đang thử việc / thực tập. Lập đơn đề nghị ký HĐLĐ chính thức.',
                onTap: () => context.push(
                  RoutePaths.requestCreatePath(
                    'probation-conversion',
                    employeeId: s.id,
                  ),
                ),
              ),
            ),
          ),
        if (canMainDuty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                4,
                AppSpacing.page,
                8,
              ),
              child: _RequestPromoCard(
                icon: Icons.nights_stay_rounded,
                accent: const Color(0xFF5B4BB4),
                title: 'Chuyển trực chính',
                subtitle:
                    'Nhân viên đang trực kèm. Lập đơn đề nghị lên trực chính.',
                onTap: () => context.push(
                  RoutePaths.requestCreatePath(
                    'main-duty-authorization',
                    employeeId: s.id,
                  ),
                ),
              ),
            ),
          ),
        if (detail.isTrialEmployee)
          SliverToBoxAdapter(
            child: _ProfileSection(
              icon: Icons.school_rounded,
              color: AppColors.warning,
              title: 'Thông tin thử việc / thực tập',
              rows: [
                _Row('Họ tên', s.fullName),
                _Row(
                  'Ngày sinh',
                  AppFormat.date(AppFormat.tryParseDate(detail.dateOfBirth)),
                ),
                _Row('Loại', detail.trialTypeLabel ?? 'Thử việc'),
                _Row('Vị trí', s.positionTitle),
                _Row('Bằng cấp', detail.degree),
                _Row('Khoa/Phòng', _pretty(s.departmentName)),
                _Row('Bộ phận', _pretty(detail.workUnitFromProfile)),
                _Row('Số điện thoại', detail.phone),
                _Row('Mã chấm công', detail.attendanceCode),
                _Row('Mức lương', detail.salaryFromNotes),
                _Row(
                  'Từ ngày',
                  AppFormat.date(
                    AppFormat.tryParseDate(
                      s.hireDate ?? detail.probationStartDate,
                    ),
                  ),
                ),
                _Row('Ghi chú', detail.noteOnly),
              ],
            ),
          ),
        if (!trialOnlyView) ...[
          SliverToBoxAdapter(
            child: _ProfileSection(
              icon: Icons.badge_outlined,
              color: AppColors.primary,
              title: 'Liên hệ & giấy tờ',
              rows: [
                _Row('Email', detail.email),
                _Row('Điện thoại', detail.phone),
                _Row('Giới tính', _genderLabel(detail.gender)),
                _Row(
                  'Ngày sinh',
                  AppFormat.date(AppFormat.tryParseDate(detail.dateOfBirth)),
                ),
                _Row('CCCD/CMND', detail.idCardNumber ?? s.employeeCode),
                _Row('Địa chỉ', detail.address),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: _ProfileSection(
              icon: Icons.work_outline_rounded,
              color: const Color(0xFF2A9D8F),
              title: 'Công việc',
              rows: [
                _Row('Phòng ban', _pretty(s.departmentName)),
                _Row('Bộ phận', _pretty(detail.workUnitFromProfile)),
                _Row('Chức vụ', _pretty(s.positionTitle)),
                _Row(
                  'Ngày vào làm',
                  AppFormat.date(AppFormat.tryParseDate(s.hireDate)),
                ),
                if (s.employmentType != null)
                  _Row('Hình thức', _employmentTypeLabel(s.employmentType)),
                if (s.employeeCode != null) _Row('Mã nhân viên', s.employeeCode),
                if (detail.attendanceCode != null)
                  _Row('Mã chấm công', detail.attendanceCode),
                if (!terminated)
                  _Row(
                    'Ca trực',
                    s.mainDutyAuthorized ? 'Trực chính' : 'Trực kèm',
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: _ProfileSection(
              icon: Icons.article_outlined,
              color: const Color(0xFF5C6BC0),
              title: 'Số hợp đồng',
              emptyMessage: detail.contracts.isEmpty ? 'Chưa có hợp đồng' : null,
              rows: [
                for (final c in detail.contracts)
                  _Row(
                    c.contractType,
                    [
                      'Ngày ký: ${AppFormat.date(AppFormat.tryParseDate(c.startDate))}',
                      if ((c.endDate ?? '').isNotEmpty)
                        'Đến: ${AppFormat.date(AppFormat.tryParseDate(c.endDate))}',
                    ].join(' · '),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: _SalaryLockCard(
              canOpenOwnSalary:
                  viewingSelf && (auth.currentUser?.canViewSalary == true),
              onOpenSalary: () {
                ref.read(shellTabProvider.notifier).state = AppShellTab.salary;
                context.go('/');
              },
            ),
          ),
          if (profile.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.md,
                  AppSpacing.page,
                  AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dữ liệu nhân lực',
                      style: AppTypography.style(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Chỉ hiện các mục đã có dữ liệu · đồng bộ hồ sơ web',
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final section in workforceSections)
              Builder(
                builder: (_) {
                  final rows = [
                    for (final key in section.keys)
                      if (hasWorkforceValue(profile[key]))
                        _Row(
                          workforceFieldLabel(key),
                          _formatProfileValue(key, profile[key]),
                          highlight: key == 'insuranceParticipation' &&
                              detail.isMaternityLeave,
                        ),
                  ];
                  if (rows.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  return SliverToBoxAdapter(
                    child: _ProfileSection(
                      icon: _sectionIcon(section.title),
                      color: AppColors.primary,
                      title: section.title,
                      rows: rows,
                    ),
                  );
                },
              ),
            if (orphanKeys.isNotEmpty)
              SliverToBoxAdapter(
                child: _ProfileSection(
                  icon: Icons.more_horiz_rounded,
                  color: AppColors.textSecondary,
                  title: 'Thông tin khác',
                  rows: [
                    for (final key in orphanKeys)
                      _Row(
                        workforceFieldLabel(key),
                        _formatProfileValue(key, profile[key]),
                      ),
                  ],
                ),
              ),
          ],
          SliverToBoxAdapter(
            child: _DocumentsSection(employeeId: s.id),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      ],
    );
  }

  String _genderLabel(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'MALE':
      case 'NAM':
        return 'Nam';
      case 'FEMALE':
      case 'NỮ':
      case 'NU':
        return 'Nữ';
      case null:
      case '':
        return '';
      default:
        return raw!;
    }
  }

  String _employmentTypeLabel(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'FULL_TIME':
        return 'Toàn thời gian (TTG)';
      case 'PART_TIME':
        return 'Bán thời gian (BTG)';
      default:
        return raw ?? '';
    }
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.detail,
    required this.subtitle,
    this.onActions,
  });

  final EmployeeDetail detail;
  final String subtitle;
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        AppSpacing.page,
        topInset + 10,
        AppSpacing.page,
        8,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'HỒ SƠ NHÂN VIÊN',
                style: AppTypography.style(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const Spacer(),
              if (onActions != null) ...[
                Material(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: onActions,
                    borderRadius: BorderRadius.circular(12),
                    child: const SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Material(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: AppRadius.brPill,
                child: InkWell(
                  onTap: () => context.pop(),
                  borderRadius: AppRadius.brPill,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Quay lại',
                          style: AppTypography.style(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                name: s.fullName,
                imageUrl: s.avatarUrl,
                size: 64,
                borderColor: Colors.white.withValues(alpha: 0.9),
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
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: AppTypography.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((s.employeeCode ?? '').isNotEmpty)
                _HeroChip(label: 'Mã NV: ${s.employeeCode}'),
              if (s.status != null)
                _HeroChip(
                  label: _statusLabels[s.status] ?? s.status!,
                  filled: true,
                  color: _statusColor(s.status),
                ),
              if (detail.isMaternityLeave)
                const _HeroChip(
                  label: 'Nghỉ thai sản',
                  filled: true,
                  color: Color(0xFFE85D4C),
                ),
              if (s.mainDutyAuthorized)
                const _HeroChip(label: 'Trực chính', filled: true)
              else if ((s.status ?? '').toUpperCase() != 'TERMINATED')
                const _HeroChip(
                  label: 'Trực kèm',
                  filled: true,
                  color: AppColors.warning,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.label,
    this.filled = false,
    this.color,
  });

  final String label;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? Colors.white.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.14),
        borderRadius: AppRadius.brPill,
        border: Border.all(
          color: Colors.white.withValues(alpha: filled ? 0 : 0.22),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.style(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: filled ? accent : Colors.white,
        ),
      ),
    );
  }
}

class _RequestPromoCard extends StatelessWidget {
  const _RequestPromoCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      accentColor: accent,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTypography.style(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: accent.withValues(alpha: 0.7)),
        ],
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.value, {this.highlight = false});
  final String label;
  final String? value;
  final bool highlight;
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.rows,
    this.emptyMessage,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<_Row> rows;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final visible = rows
        .where((r) => r.value != null && r.value!.trim().isNotEmpty)
        .toList();
    final showEmpty = visible.isEmpty && emptyMessage != null;
    if (visible.isEmpty && emptyMessage == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        0,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.style(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSoft),
            if (showEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  emptyMessage!,
                  style: AppTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              for (var i = 0; i < visible.length; i++)
                _DetailRow(
                  label: visible[i].label,
                  value: visible[i].value!,
                  highlight: visible[i].highlight,
                  isLast: i == visible.length - 1,
                ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.isLast,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool isLast;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: highlight ? const Color(0xFF9D174D) : AppColors.textPrimary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsSection extends ConsumerWidget {
  const _DocumentsSection({required this.employeeId});

  final int employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(employeeDocumentsProvider(employeeId));
    final docs = async.valueOrNull ?? const <EmployeeDocumentMeta>[];
    final loading = async.isLoading && !async.hasValue;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        0,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 18,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hồ sơ PDF',
                      style: AppTypography.style(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSoft),
            if (!loading && docs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Chưa có tệp đính kèm',
                  style: AppTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              for (var i = 0; i < docs.length; i++)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    border: i == docs.length - 1
                        ? null
                        : const Border(
                            bottom: BorderSide(color: AppColors.borderSoft),
                          ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              docs[i].originalName,
                              style: AppTypography.style(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if ((docs[i].createdAt ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                AppFormat.date(
                                  AppFormat.tryParseDate(docs[i].createdAt),
                                ),
                                style: AppTypography.style(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
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

class _SalaryLockCard extends StatelessWidget {
  const _SalaryLockCard({
    required this.canOpenOwnSalary,
    required this.onOpenSalary,
  });

  final bool canOpenOwnSalary;
  final VoidCallback onOpenSalary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.08),
              AppColors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: AppRadius.brSm,
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bảng lương & thâm niên',
                    style: AppTypography.style(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Dữ liệu lương đang được bảo vệ',
                    style: AppTypography.style(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (canOpenOwnSalary)
              TextButton(
                onPressed: onOpenSalary,
                child: const Text('Xem lương'),
              ),
          ],
        ),
      ),
    );
  }
}
