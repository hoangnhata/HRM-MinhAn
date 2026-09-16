import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_shell.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/list_section_title.dart';
import '../../../shared/models/app_notification.dart';
import '../application/notification_controller.dart';
import 'notification_ui.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationControllerProvider);
    final controller = ref.read(notificationControllerProvider.notifier);
    final topInset = MediaQuery.paddingOf(context).top;

    final items = _unreadOnly
        ? state.items.where((n) => !n.read).toList()
        : state.items;
    final groups = _groupByDay(items);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.85)),
          RefreshIndicator(
            edgeOffset: topInset,
            color: AppColors.primary,
            onRefresh: controller.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: _NotificationsHeader(
                    unreadCount: state.unreadCount,
                    unreadOnly: _unreadOnly,
                    onToggleFilter: (value) =>
                        setState(() => _unreadOnly = value),
                    onMarkAllRead: state.unreadCount > 0
                        ? controller.markAllRead
                        : null,
                  ),
                ),
                if (state.error != null && state.items.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      12,
                      AppSpacing.page,
                      4,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: NoticeBanner.error(
                        title: 'Chưa cập nhật được thông báo',
                        message: state.error!,
                        action: TextButton.icon(
                          onPressed: controller.refresh,
                          icon: const Icon(Icons.refresh_rounded, size: 17),
                          label: const Text('Thử lại'),
                        ),
                      ),
                    ),
                  ),
                if (state.loading && state.items.isEmpty)
                  const SliverSkeletonList(
                    itemCount: 8,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.sm,
                      AppSpacing.page,
                      0,
                    ),
                  )
                else if (state.error != null && state.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorState(
                      message: state.error!,
                      onRetry: controller.refresh,
                    ),
                  )
                else if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: _unreadOnly
                          ? Icons.mark_email_read_outlined
                          : Icons.notifications_none_rounded,
                      title: _unreadOnly
                          ? 'Không có thông báo chưa đọc'
                          : 'Chưa có thông báo nào',
                      message: _unreadOnly
                          ? 'Bạn đã xử lý hết thông báo mới.'
                          : 'Thông báo về đơn từ, công và lương sẽ xuất hiện ở đây.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      14,
                      AppSpacing.page,
                      0,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          var cursor = 0;
                          for (final group in groups) {
                            if (index == cursor) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
                                child: ListSectionTitle(
                                  title: group.$1,
                                  count: group.$2.length,
                                  showRail: false,
                                  uppercase: false,
                                ),
                              );
                            }
                            cursor += 1;
                            final local = index - cursor;
                            if (local >= 0 && local < group.$2.length) {
                              return _NotificationCard(
                                item: group.$2[local],
                                index: local,
                              );
                            }
                            cursor += group.$2.length;
                          }
                          return const SizedBox.shrink();
                        },
                        childCount: groups.fold<int>(
                          0,
                          (sum, g) => sum + 1 + g.$2.length,
                        ),
                      ),
                    ),
                  ),
                if (state.hasMore && state.items.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        6,
                        AppSpacing.page,
                        0,
                      ),
                      child: _LoadMoreButton(
                        loading: state.loadingMore,
                        onTap: controller.loadMore,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tải trang thông báo kế tiếp — danh sách chỉ kéo 20 tin mỗi lần.
class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Xem thông báo cũ hơn',
                        style: AppTypography.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
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

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.unreadCount,
    required this.unreadOnly,
    required this.onToggleFilter,
    required this.onMarkAllRead,
  });

  final int unreadCount;
  final bool unreadOnly;
  final ValueChanged<bool> onToggleFilter;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return AppScreenHeader(
      eyebrow: 'Hộp thư nội bộ',
      title: 'Thông báo',
      icon: Icons.notifications_active_rounded,
      dense: true,
      onBack: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go(RoutePaths.dashboard);
        }
      },
      subtitle: unreadCount > 0
          ? '$unreadCount thông báo chưa đọc'
          : 'Bạn đã đọc hết thông báo',
      trailing: onMarkAllRead == null
          ? null
          : Semantics(
              button: true,
              label: 'Đánh dấu tất cả là đã đọc',
              child: Tooltip(
                message: 'Đánh dấu đã đọc hết',
                child: Material(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onMarkAllRead,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.done_all_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      footer: BrandHeaderSegment(
        dense: true,
        selectedIndex: unreadOnly ? 1 : 0,
        onChanged: (i) => onToggleFilter(i == 1),
        items: [
          const BrandSegmentItem(label: 'Tất cả', icon: Icons.inbox_rounded),
          BrandSegmentItem(
            label: 'Chưa đọc',
            icon: Icons.mark_email_unread_rounded,
            count: unreadCount,
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.item, required this.index});

  final AppNotification item;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = NotificationUi.colorFor(item.category, title: item.title);
    final unread = !item.read;

    final card = AppCard(
      onTap: () => _open(context, ref),
      borderRadius: AppRadius.brCard,
      accentColor: unread ? color : null,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.16),
                  color.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Icon(
              NotificationUi.iconFor(item.category, title: item.title),
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontWeight: unread
                              ? FontWeight.w800
                              : FontWeight.w700,
                          fontSize: 14.5,
                          height: 1.25,
                          letterSpacing: -0.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 8, top: 5),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                    fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MetaChip(
                      label: NotificationUi.labelFor(
                        item.category,
                        title: item.title,
                      ),
                      color: color,
                    ),
                    if (item.sensitive) ...[
                      const SizedBox(width: 6),
                      const _MetaChip(
                        label: 'Nhạy cảm',
                        color: AppColors.error,
                      ),
                    ],
                    const Spacer(),
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppFormat.relativeFromNow(item.createdAt),
                      style: AppTypography.style(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );

    return AppReveal(
      delay: AppStagger.delayFor(index),
      offset: 8,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: unread
            ? Slidable(
                key: ValueKey('notification-${item.id}'),
                endActionPane: ActionPane(
                  motion: const StretchMotion(),
                  extentRatio: 0.28,
                  children: [
                    SlidableAction(
                      onPressed: (_) => ref
                          .read(notificationControllerProvider.notifier)
                          .markRead(item.id),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      icon: Icons.mark_email_read_outlined,
                      label: 'Đã đọc',
                      borderRadius: AppRadius.brCard,
                    ),
                  ],
                ),
                child: card,
              )
            : card,
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    await ref.read(notificationControllerProvider.notifier).markRead(item.id);
    if (!context.mounted) return;

    final target = NotificationUi.resolveTarget(
      item.actionPath,
      category: item.category,
      relatedRequestId: item.relatedRequestId,
      title: item.title,
    );

    if (target.tab != null) {
      ref.read(shellTabProvider.notifier).state = target.tab!;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    if (target.route != null) {
      context.push(target.route!);
    }
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        label,
        style: AppTypography.style(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

List<(String, List<AppNotification>)> _groupByDay(List<AppNotification> items) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final week = today.subtract(const Duration(days: 7));

  final buckets = <String, List<AppNotification>>{
    'HÔM NAY': [],
    'HÔM QUA': [],
    'TUẦN NÀY': [],
    'TRƯỚC ĐÓ': [],
  };

  for (final item in items) {
    final raw = item.createdAt;
    if (raw == null) {
      buckets['TRƯỚC ĐÓ']!.add(item);
      continue;
    }
    final local = raw.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) {
      buckets['HÔM NAY']!.add(item);
    } else if (day == yesterday) {
      buckets['HÔM QUA']!.add(item);
    } else if (!day.isBefore(week)) {
      buckets['TUẦN NÀY']!.add(item);
    } else {
      buckets['TRƯỚC ĐÓ']!.add(item);
    }
  }

  return [
    for (final entry in buckets.entries)
      if (entry.value.isNotEmpty) (entry.key, entry.value),
  ];
}
