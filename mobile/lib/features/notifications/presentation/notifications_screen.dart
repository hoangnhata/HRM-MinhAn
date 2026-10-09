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
import '../../../core/widgets/app_action_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';
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
    return AppActionButton(
      variant: AppActionVariant.tonalPrimary,
      compact: true,
      icon: Icons.expand_more_rounded,
      label: 'Xem thông báo cũ hơn',
      loading: loading,
      onPressed: onTap,
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

    final icon = NotificationUi.iconFor(item.category, title: item.title);
    // Chưa đọc: nền pha sắc loại tin + icon đặc; đã đọc: nền trắng, icon nhạt
    // để mắt dừng ở tin mới khi lướt.
    final card = AppCard(
      onTap: () => _open(context, ref),
      borderRadius: AppRadius.brCard,
      gradient: unread ? TintedCardBackdrop.gradient(color) : null,
      padding: EdgeInsets.zero,
      child: TintedCardBackdrop(
        accent: unread ? color : AppColors.textTertiary,
        watermarkIcon: unread ? icon : null,
        glowOffset: const Offset(-40, -44),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (unread)
                TintedIconTile(icon: icon, color: color, size: 46)
              else
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(46 * 0.3),
                    border: Border.all(color: color.withValues(alpha: 0.14)),
                  ),
                  child: Icon(
                    icon,
                    color: color.withValues(alpha: 0.8),
                    size: 22,
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
                                  : FontWeight.w600,
                              fontSize: 14.5,
                              height: 1.25,
                              letterSpacing: -0.2,
                              color: unread
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 1.5,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondary.withValues(
                                    alpha: 0.4,
                                  ),
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
                        Flexible(
                          child: _MetaChip(
                            label: NotificationUi.labelFor(
                              item.category,
                              title: item.title,
                            ),
                            color: color,
                            solid: unread,
                          ),
                        ),
                        if (item.sensitive) ...[
                          const SizedBox(width: 6),
                          const _MetaChip(
                            label: 'Nhạy cảm',
                            color: AppColors.error,
                            icon: Icons.lock_rounded,
                          ),
                        ],
                        const SizedBox(width: 8),
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
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: TintedChevron(
                  accent: unread ? color : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
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
  const _MetaChip({
    required this.label,
    required this.color,
    this.solid = false,
    this.icon,
  });

  final String label;
  final Color color;

  /// Tin chưa đọc: viên nền trắng viền sắc, nổi trên nền pha màu của thẻ.
  final bool solid;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
      decoration: BoxDecoration(
        color: solid ? AppColors.surface : color.withValues(alpha: 0.08),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: solid ? 0.28 : 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 10, color: color)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                height: AppTypography.uppercaseHeight,
                color: Color.lerp(color, AppColors.textPrimary, 0.15)!,
              ),
            ),
          ),
        ],
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
