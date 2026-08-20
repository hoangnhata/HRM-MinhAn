import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/session/session_epoch.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../shared/models/attendance_models.dart';
import '../../auth/application/auth_controller.dart';
import '../application/attendance_requests_controller.dart';
import '../data/attendance_repository.dart';
import 'attendance_enums.dart';
import 'attendance_my_requests_tab.dart';
import 'attendance_pending_tab.dart';
import 'bulk_deployment_sheet.dart';

final attendanceLeaveBalanceProvider =
    FutureProvider.autoDispose<LeaveBalance>((ref) {
  ref.watch(sessionEpochProvider);
  return ref.watch(attendanceRepositoryProvider).leaveBalance();
});

/// Màn danh sách đơn nghỉ phép hoặc đơn công (giải trình / cập nhật).
class AttendanceRequestsScreen extends ConsumerStatefulWidget {
  const AttendanceRequestsScreen({
    super.key,
    required this.scope,
    this.highlightRequestId,
    this.initialTab,
  });

  final AttendanceRequestScope scope;

  /// ID đơn cần khoanh khi mở từ thông báo.
  final int? highlightRequestId;

  /// `mine` | `approve` — tab ban đầu (từ query thông báo).
  final String? initialTab;

  @override
  ConsumerState<AttendanceRequestsScreen> createState() =>
      _AttendanceRequestsScreenState();
}

class _AttendanceRequestsScreenState
    extends ConsumerState<AttendanceRequestsScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  late bool _canApprove;
  bool _selectMode = false;

  @override
  void initState() {
    super.initState();
    _canApprove = RoleGroups.isIn(
      ref.read(authControllerProvider).role,
      RoleGroups.approvalManagers,
    );
    if (_canApprove) {
      var initial = widget.scope == AttendanceRequestScope.deployment ? 1 : 0;
      final tab = widget.initialTab?.toLowerCase();
      if (tab == 'approve' || tab == 'deployments') {
        initial = 1;
      } else if (tab == 'mine') {
        initial = 0;
      } else if (widget.highlightRequestId != null) {
        // Thông báo có ID mà không rõ tab → ưu tiên Chờ duyệt.
        initial = 1;
      }
      _tabController = TabController(
        length: 2,
        vsync: this,
        initialIndex: initial,
      );
      _tabController!.addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    if (!mounted || _tabController == null) return;
    if (_tabController!.indexIsChanging) return;
    // Rebuild để cập nhật isActive của tab chờ duyệt; tắt chọn nếu đang bật.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        if (_selectMode) _selectMode = false;
      });
    });
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    final scope = widget.scope;
    if (scope == AttendanceRequestScope.deployment) {
      final now = DateTime.now();
      final picked = await showAppDatePicker(
        context,
        title: 'Ngày điều động',
        initialDate: now,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 1),
      );
      if (picked == null || !mounted) return;
      final created = await showBulkDeploymentSheet(
        context,
        workDate: picked,
      );
      if (created == true && mounted) {
        await ref
            .read(attendanceRequestsControllerProvider.notifier)
            .refreshAll();
      }
      return;
    }
    final prefill = scope.createPrefill();
    if (prefill == null) return;
    context.push(RoutePaths.attendanceRequestNew, extra: prefill);
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    final role = ref.watch(authControllerProvider).role;
    final canCreate = scope.canCreate(role);
    final state = ref.watch(attendanceRequestsControllerProvider);
    final pendingCount =
        state.pending.where((r) => scope.matches(r.requestType)).length;
    final leaveAsync = scope == AttendanceRequestScope.leave
        ? ref.watch(attendanceLeaveBalanceProvider)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      // Giữ FAB trong tree để Scaffold/TabBarView không remount khi ẩn.
      floatingActionButton: canCreate
          ? IgnorePointer(
              ignoring: _selectMode,
              child: AnimatedOpacity(
                opacity: _selectMode ? 0 : 1,
                duration: AppDurations.fast,
                child: FloatingActionButton.extended(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    scope == AttendanceRequestScope.leave
                        ? 'Xin nghỉ'
                        : 'Tạo đơn',
                  ),
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.85)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: scope.title,
                icon: scope.icon,
                eyebrow: 'Đơn từ',
                subtitle: scope.subtitle,
                onBack: () => context.pop(),
                footer: _canApprove && _tabController != null
                    ? BrandHeaderTabBar(
                        dense: true,
                        controller: _tabController!,
                        items: [
                          BrandHeaderTabItem(
                            label: 'Đơn của tôi',
                            icon: Icons.folder_shared_outlined,
                          ),
                          BrandHeaderTabItem(
                            label: 'Chờ duyệt',
                            icon: Icons.pending_actions_rounded,
                            count: pendingCount,
                          ),
                        ],
                      )
                    : null,
              ),
              if (leaveAsync != null && leaveAsync.hasValue)
                _LeaveBalanceCard(leave: leaveAsync.requireValue),
              if (scope == AttendanceRequestScope.deployment && !_canApprove)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    0,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.14),
                      ),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.brSm,
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            scope.employeeListIntro(false),
                            style: AppTypography.style(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: _canApprove && _tabController != null
                    ? TabBarView(
                        controller: _tabController,
                        children: [
                          AttendanceMyRequestsTab(
                            scope: scope,
                            highlightRequestId: widget.highlightRequestId,
                          ),
                          AttendancePendingTab(
                            scope: scope,
                            isActive: _tabController!.index == 1,
                            highlightRequestId: widget.highlightRequestId,
                            onSelectModeChanged: (v) {
                              if (!mounted || _selectMode == v) return;
                              setState(() => _selectMode = v);
                            },
                          ),
                        ],
                      )
                    : AttendanceMyRequestsTab(
                        scope: scope,
                        highlightRequestId: widget.highlightRequestId,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaveBalanceCard extends StatelessWidget {
  const _LeaveBalanceCard({required this.leave});

  final LeaveBalance leave;

  @override
  Widget build(BuildContext context) {
    final entitlement = leave.entitlementDays;
    final used = leave.usedDays;
    final remaining = leave.remainingDays;
    final pending = leave.pendingDays;
    final depleted = remaining <= 0 && entitlement > 0;
    final remainRatio =
        entitlement == 0 ? 0.0 : (remaining / entitlement).clamp(0.0, 1.0);
    final accent = depleted ? AppColors.error : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        0,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.brCard,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.12),
              AppColors.surface,
              AppColors.surface,
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
          boxShadow: AppShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _LeaveRing(
                    progress: remainRatio,
                    color: accent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$remaining',
                          style: AppTypography.style(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            height: 1,
                          ),
                        ),
                        Text(
                          'còn',
                          style: AppTypography.style(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accent.withValues(alpha: 0.8),
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: AppRadius.brPill,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.beach_access_rounded,
                                    size: 13,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Phép ${leave.year}',
                                    style: AppTypography.style(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: accent == AppColors.error
                                          ? AppColors.errorDark
                                          : AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              depleted ? 'Hết phép' : 'Còn khả dụng',
                              style: AppTypography.style(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: depleted
                                    ? AppColors.error
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          depleted
                              ? 'Bạn đã dùng hết hạn mức phép năm này.'
                              : 'Còn $remaining/$entitlement ngày phép trong năm.',
                          style: AppTypography.style(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Đồng bộ hạn mức với hệ thống web.',
                          style: AppTypography.style(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _LeaveMetric(
                    label: 'Định mức',
                    value: '$entitlement',
                    icon: Icons.flag_outlined,
                  ),
                  _LeaveMetric(
                    label: 'Đã dùng',
                    value: '$used',
                    icon: Icons.event_busy_outlined,
                  ),
                  _LeaveMetric(
                    label: 'Chờ duyệt',
                    value: '$pending',
                    icon: Icons.hourglass_top_rounded,
                    tint: pending > 0 ? AppColors.warning : null,
                  ),
                ],
              ),
              if (leave.warning != null && leave.warning!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: AppRadius.brSm,
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    leave.warning!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 11.5,
                      color: AppColors.warningText,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveRing extends StatelessWidget {
  const _LeaveRing({
    required this.progress,
    required this.color,
    required this.child,
  });

  final double progress;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 68,
      child: CustomPaint(
        painter: _LeaveRingPainter(
          progress: progress,
          color: color,
          trackColor: color.withValues(alpha: 0.14),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _LeaveRingPainter extends CustomPainter {
  _LeaveRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 8) / 2;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * progress.clamp(0.0, 1.0),
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _LeaveRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

class _LeaveMetric extends StatelessWidget {
  const _LeaveMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.primary;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.85),
          borderRadius: AppRadius.brMd,
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.style(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: tint ?? AppColors.textPrimary,
                height: 1.1,
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
