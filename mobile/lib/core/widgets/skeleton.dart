import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Khối "xương" nhấp nháy khi đang tải — cho cảm giác nhanh hơn vòng xoay.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadius.xs,
    this.margin,
  });

  /// Dòng chữ giả với chiều rộng theo tỉ lệ khung cha.
  const Skeleton.line({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  const Skeleton.circle({super.key, double size = 40, this.margin})
    : width = size,
      height = size,
      radius = 999;

  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final bone = RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) return bone;
    return bone
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1250),
          color: Colors.white.withValues(alpha: 0.68),
          size: 1.2,
        );
  }
}

/// Danh sách thẻ giả — dùng khi đang tải danh sách đơn/nhân viên/thông báo.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 5, this.showAvatar = true});

  final int itemCount;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.page),
      itemCount: itemCount,
      itemBuilder: (context, index) =>
          _SkeletonListCard(showAvatar: showAvatar),
    );
  }
}

/// Biến thể sliver của [SkeletonList] dành cho [CustomScrollView].
///
/// Không lồng một `ListView` vào `SliverToBoxAdapter`, vì viewport con sẽ nhận
/// chiều cao không giới hạn và có thể gây lỗi layout khi màn hình đang tải.
class SliverSkeletonList extends StatelessWidget {
  const SliverSkeletonList({
    super.key,
    this.itemCount = 5,
    this.showAvatar = true,
    this.padding = const EdgeInsets.all(AppSpacing.page),
  });

  final int itemCount;
  final bool showAvatar;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverList.builder(
        itemCount: itemCount,
        itemBuilder: (context, index) =>
            _SkeletonListCard(showAvatar: showAvatar),
      ),
    );
  }
}

class _SkeletonListCard extends StatelessWidget {
  const _SkeletonListCard({required this.showAvatar});

  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: const Border.fromBorderSide(
          BorderSide(color: AppColors.borderSoft),
        ),
      ),
      child: Row(
        children: [
          if (showAvatar) ...[
            const Skeleton.circle(size: 44),
            const SizedBox(width: AppSpacing.sm),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton.line(width: 150),
                Skeleton.line(width: 210, height: 10),
                Skeleton.line(width: 90, height: 10, margin: EdgeInsets.zero),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lưới thẻ thống kê giả — dùng cho Dashboard khi đang tải.
class SkeletonStatGrid extends StatelessWidget {
  const SkeletonStatGrid({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: AppSpacing.pageH,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.5,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brMd,
          border: const Border.fromBorderSide(
            BorderSide(color: AppColors.borderSoft),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Skeleton(width: 36, height: 36, radius: AppRadius.sm),
            Spacer(),
            Skeleton.line(width: 54, height: 20),
            Skeleton.line(width: 90, height: 10, margin: EdgeInsets.zero),
          ],
        ),
      ),
    );
  }
}
