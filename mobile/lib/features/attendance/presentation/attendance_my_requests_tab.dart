import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_segmented_control.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/attendance_models.dart';
import '../../auth/application/auth_controller.dart';
import '../application/attendance_requests_controller.dart';
import 'attendance_enums.dart';
import 'attendance_request_card.dart';
import 'attendance_request_list_filters.dart';
import 'attendance_request_toolbar.dart';

class AttendanceMyRequestsTab extends ConsumerStatefulWidget {
  const AttendanceMyRequestsTab({
    super.key,
    required this.scope,
    this.highlightRequestId,
  });

  final AttendanceRequestScope scope;
  final int? highlightRequestId;

  @override
  ConsumerState<AttendanceMyRequestsTab> createState() =>
      _AttendanceMyRequestsTabState();
}

class _AttendanceMyRequestsTabState
    extends ConsumerState<AttendanceMyRequestsTab> {
  AttendanceRequestListFilters _filters = AttendanceRequestListFilters.empty;
  final GlobalKey _highlightKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  int? _scrolledForId;

  /// null | __pending__ | __done__
  String? _quickStatus;

  List<({String value, String label})> get _typeOptions {
    return switch (widget.scope) {
      AttendanceRequestScope.leave => const [
        (value: 'LEAVE', label: 'Nghỉ phép'),
        (value: 'UNPAID_LEAVE', label: 'Không lương'),
        (value: 'PERSONAL_LEAVE', label: 'Nghỉ chế độ'),
      ],
      AttendanceRequestScope.work => const [
        (value: 'EXPLANATION', label: 'Giải trình'),
        (value: 'UPDATE', label: 'Cập nhật công'),
      ],
      AttendanceRequestScope.deployment =>
        const <({String value, String label})>[],
    };
  }

  List<AttendanceWorkRequest> _applyQuick(List<AttendanceWorkRequest> items) {
    if (_quickStatus == '__pending__') {
      return items.where((r) => AttendanceEnums.isPending(r.status)).toList();
    }
    if (_quickStatus == '__done__') {
      return items.where((r) => !AttendanceEnums.isPending(r.status)).toList();
    }
    return items;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceRequestsControllerProvider);
    final controller = ref.read(attendanceRequestsControllerProvider.notifier);
    final scope = widget.scope;

    if (state.loading && state.mine.isEmpty) {
      return const SkeletonList(itemCount: 5, showAvatar: false);
    }
    if (state.error != null && state.mine.isEmpty) {
      return ErrorState(message: state.error!, onRetry: controller.refreshAll);
    }

    final scoped = state.mine
        .where((r) => scope.matches(r.requestType))
        .toList();
    final afterQuick = _applyQuick(scoped);
    var filtered = _filters.apply(afterQuick);
    final highlightId = widget.highlightRequestId;

    if (highlightId != null &&
        scoped.any((r) => r.id == highlightId) &&
        !filtered.any((r) => r.id == highlightId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _quickStatus = null;
          _filters = AttendanceRequestListFilters.empty;
        });
      });
      filtered = scoped;
    }

    if (highlightId != null &&
        _scrolledForId != highlightId &&
        filtered.any((r) => r.id == highlightId)) {
      _scrolledForId = highlightId;
      final cardIndex = filtered.indexWhere((r) => r.id == highlightId);
      scheduleScrollToHighlight(
        _highlightKey,
        controller: _scroll,
        index: (state.error != null ? 1 : 0) + 2 + cardIndex,
      );
    }

    final auth = ref.watch(authControllerProvider);
    final canApprove = scope.canApprove(
      role: auth.role,
      directorApprovalEnabled:
          auth.currentUser?.directorApprovalEnabled ?? false,
    );

    final emptyTitle = switch (scope) {
      AttendanceRequestScope.leave => 'Bạn chưa gửi đơn nghỉ nào',
      AttendanceRequestScope.work => 'Bạn chưa gửi đơn công nào',
      AttendanceRequestScope.deployment =>
        canApprove
            ? 'Chưa có đơn điều động gắn hồ sơ bạn'
            : 'Bạn chưa có đơn điều động nào',
    };
    final emptyMessage = switch (scope) {
      AttendanceRequestScope.leave =>
        'Dùng nút "Xin nghỉ" để gửi đơn nghỉ phép, không lương hoặc nghỉ chế độ.',
      AttendanceRequestScope.work =>
        'Dùng nút "Tạo đơn" để giải trình muộn/sớm hoặc cập nhật công.',
      AttendanceRequestScope.deployment =>
        canApprove
            ? 'Tab này chỉ hiện đơn điều động liên quan đến bạn. Duyệt đơn ở tab Chờ duyệt.'
            : 'Khi có đơn điều động liên quan đến bạn, chúng sẽ hiện tại đây.',
    };

    return RefreshIndicator(
      onRefresh: controller.refreshAll,
      child: scoped.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                EmptyState(
                  icon: scope.icon,
                  title: emptyTitle,
                  message: emptyMessage,
                ),
              ],
            )
          : ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                8,
                AppSpacing.page,
                90,
              ),
              children: [
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: NoticeBanner.error(
                      title: 'Dữ liệu có thể chưa mới nhất',
                      message: state.error!,
                      action: TextButton.icon(
                        onPressed: controller.refreshAll,
                        icon: const Icon(Icons.refresh_rounded, size: 17),
                        label: const Text('Thử lại'),
                      ),
                    ),
                  ),
                AttendanceRequestToolbar(
                  filters: _filters,
                  onFiltersChanged: (f) => setState(() => _filters = f),
                  resultCount: filtered.length,
                  sourceItems: scoped,
                  typeOptions: _typeOptions,
                  searchHint: scope == AttendanceRequestScope.leave
                      ? 'Tìm lý do, loại nghỉ…'
                      : 'Tìm tên, nội dung…',
                  leading: scope == AttendanceRequestScope.deployment
                      ? null
                      : AppSegmentedControl(
                          expand: false,
                          style: AppSegmentStyle.soft,
                          selectedIndex: switch (_quickStatus) {
                            '__pending__' => 1,
                            '__done__' => 2,
                            _ => 0,
                          },
                          onChanged: (i) => setState(() {
                            _quickStatus = switch (i) {
                              1 => '__pending__',
                              2 => '__done__',
                              _ => null,
                            };
                          }),
                          items: const [
                            AppSegmentItem(label: 'Tất cả'),
                            AppSegmentItem(label: 'Chờ'),
                            AppSegmentItem(label: 'Xong'),
                          ],
                        ),
                ),
                const SizedBox(height: 4),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: EmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'Không có đơn phù hợp',
                      message: 'Thử chọn bộ lọc khác hoặc tạo đơn mới.',
                    ),
                  )
                else
                  for (final request in filtered)
                    AttendanceRequestCard(
                      key: request.id == highlightId ? _highlightKey : null,
                      request: request,
                      highlighted: request.id == highlightId,
                      onTap: () => context.push(
                        RoutePaths.attendanceRequestDetailPath(request.id),
                      ),
                    ),
              ],
            ),
    );
  }
}
