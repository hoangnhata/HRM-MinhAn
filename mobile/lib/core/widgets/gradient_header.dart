import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Header brand gradient — trang trí tối giản, phù hợp app nội bộ chuyên nghiệp.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.xl,
    ),
    this.bottomRadius = 24,
    this.safeAreaTop = true,
    this.gradient = AppGradients.brand,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double bottomRadius;
  final bool safeAreaTop;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final topInset = safeAreaTop ? MediaQuery.paddingOf(context).top : 0.0;
    final onBrand = Theme.of(context).colorScheme.onPrimary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: bottomRadius > 0
            ? BorderRadius.only(
                bottomLeft: Radius.circular(bottomRadius),
                bottomRight: Radius.circular(bottomRadius),
              )
            : null,
        boxShadow: bottomRadius > 0
            ? [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: -40,
            right: -24,
            child: _SoftOrb(size: 132, alpha: 0.1),
          ),
          Positioned(
            bottom: -52,
            left: -40,
            child: _SoftOrb(size: 150, alpha: 0.06),
          ),
          Positioned(
            top: 18,
            left: 72,
            child: _SoftOrb(size: 56, alpha: 0.05),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 1,
                color: onBrand.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: topInset).add(padding),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ],
      ),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.size, required this.alpha});
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: alpha),
      ),
    );
  }
}

/// Header chuẩn cho tab cấp một (Công, Đơn từ, Thông báo…)
/// và màn đơn con (tạo/duyệt) khi có [onBack].
class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.trailing,
    this.footer,
    this.eyebrow,
    this.onBack,
    this.dense = false,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? trailing;
  final Widget? footer;
  final String? eyebrow;

  /// Khi có giá trị, hiện nút trở về (bên trái — chuẩn mobile).
  final VoidCallback? onBack;

  /// Header thấp hơn — màn danh sách ưu tiên không gian cho nội dung.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final isNested = onBack != null;
    // Nested (đơn từ / form): luôn hiện eyebrow & subtitle gọn nếu có.
    final showEyebrow = eyebrow != null && (!dense || isNested);
    final showSubtitle = subtitle != null && (!dense || isNested);
    final iconBox = dense ? (isNested ? 40.0 : 36.0) : 42.0;
    final topPad = dense ? (isNested ? 14.0 : 8.0) : AppSpacing.sm;
    final bottomPad = footer == null
        ? (dense ? (isNested ? 22.0 : AppSpacing.md) : AppSpacing.xl)
        : (dense ? (isNested ? 16.0 : AppSpacing.sm) : AppSpacing.md);

    return GradientHeader(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        topPad,
        AppSpacing.page,
        bottomPad,
      ),
      // Dense + nội dung sát dưới: cắt thẳng để không lộ khoảng trắng ở góc bo.
      bottomRadius: dense ? 0 : 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isNested) ...[
                _HeaderBackButton(onBack: onBack!, dense: dense, onBrand: onBrand),
                const SizedBox(width: 10),
              ],
              _HeaderIconBadge(
                icon: icon,
                size: iconBox,
                iconSize: dense ? (isNested ? 20 : 18) : 21,
                onBrand: onBrand,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showEyebrow) ...[
                      Text(
                        eyebrow!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.uppercase(
                          color: onBrand.withValues(alpha: 0.72),
                          fontSize: 10.5,
                          letterSpacing: 0.85,
                        ),
                      ),
                      SizedBox(height: dense ? (isNested ? 5 : 3) : 5),
                    ],
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        maxLines: dense && !isNested ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: dense
                            ? AppTypography.style(
                                color: onBrand,
                                fontSize: isNested ? 18.5 : 17.5,
                                fontWeight: FontWeight.w800,
                                height: AppTypography.uppercaseHeight,
                                letterSpacing: -0.1,
                              )
                            : AppTypography.pageTitle(color: onBrand),
                      ),
                    ),
                    if (showSubtitle) ...[
                      SizedBox(height: dense ? (isNested ? 6 : 4) : 4),
                      Text(
                        subtitle!,
                        maxLines: dense && !isNested ? 2 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: AppTypography.uppercaseHeight,
                          color: onBrand.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: Align(child: trailing),
                ),
              ],
            ],
          ),
          if (footer != null) ...[
            SizedBox(height: dense ? (isNested ? 14 : 12) : AppSpacing.md),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton({
    required this.onBack,
    required this.dense,
    required this.onBrand,
  });

  final VoidCallback onBack;
  final bool dense;
  final Color onBrand;

  @override
  Widget build(BuildContext context) {
    final size = dense ? 40.0 : 42.0;
    return Semantics(
      button: true,
      label: 'Trở về',
      child: Material(
        color: onBrand.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onBack,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.arrow_back_rounded,
              color: onBrand,
              size: dense ? 20 : 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconBadge extends StatelessWidget {
  const _HeaderIconBadge({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onBrand,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color onBrand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onBrand.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: onBrand.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ExcludeSemantics(
        child: Icon(icon, color: onBrand, size: iconSize),
      ),
    );
  }
}

/// AppBar gradient cho trang chi tiết đơn / hồ sơ.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  double get _toolbarHeight => subtitle == null ? 64 : 72;

  @override
  Size get preferredSize =>
      Size.fromHeight(_toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final semanticsLabel = subtitle == null ? title : '$title. $subtitle';

    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        toolbarHeight: _toolbarHeight,
        titleSpacing: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: onBrand),
        actionsIconTheme: IconThemeData(color: onBrand),
        title: Semantics(
          header: true,
          label: semanticsLabel,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      color: onBrand,
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      height: AppTypography.uppercaseHeight,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: onBrand.withValues(alpha: 0.8),
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: actions
            ?.map(
              (action) => ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Center(child: action),
              ),
            )
            .toList(),
        bottom: bottom,
      ),
    );
  }
}

/// Tab bar dạng segment — rõ ràng, ít “đồ chơi” hơn pill đầy đủ.
class PillTabBar extends StatelessWidget implements PreferredSizeWidget {
  const PillTabBar({super.key, required this.tabs, this.controller});

  final List<String> tabs;
  final TabController? controller;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: AppRadius.brSm,
        ),
        child: TabBar(
          controller: controller,
          isScrollable: false,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(3),
          padding: EdgeInsets.zero,
          labelPadding: EdgeInsets.zero,
          indicator: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.brXs,
            boxShadow: AppShadows.soft,
            border: Border.all(color: AppColors.borderSoft),
          ),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTypography.style(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: AppTypography.style(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            for (final t in tabs)
              Tab(
                height: 34,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(t, maxLines: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Một tab trên nền brand — nhãn + badge số (tuỳ chọn) + icon.
class BrandHeaderTabItem {
  const BrandHeaderTabItem({
    required this.label,
    this.count,
    this.showZeroCount = false,
    this.icon,
  });

  final String label;
  final int? count;
  final bool showZeroCount;
  final IconData? icon;

  bool get _hasBadge =>
      count != null && (showZeroCount || count! > 0);
}

/// Tab bar segment trên [AppScreenHeader] — trắng nổi, chữ teal khi chọn.
class BrandHeaderTabBar extends StatelessWidget {
  const BrandHeaderTabBar({
    super.key,
    required this.controller,
    required this.items,
    this.dense = false,
  });

  final TabController controller;
  final List<BrandHeaderTabItem> items;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final height = dense ? 46.0 : 50.0;

    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onBrand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: onBrand.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        isScrollable: false,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        splashBorderRadius: BorderRadius.circular(12),
        indicator: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: AppColors.primaryDark,
        unselectedLabelColor: onBrand.withValues(alpha: 0.82),
        labelStyle: AppTypography.style(
          fontSize: dense ? 12.5 : 13,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.05,
          height: AppTypography.uppercaseHeight,
        ),
        unselectedLabelStyle: AppTypography.style(
          fontSize: dense ? 12.5 : 13,
          fontWeight: FontWeight.w600,
          height: AppTypography.uppercaseHeight,
        ),
        tabs: [
          for (final (index, item) in items.indexed)
            Tab(
              height: dense ? 38 : 42,
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final selected = controller.index == index;
                  return _BrandTabLabel(
                    item: item,
                    selected: selected,
                    unselectedColor: onBrand.withValues(alpha: 0.86),
                    dense: dense,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Một lựa chọn trên [BrandHeaderSegment].
class BrandSegmentItem {
  const BrandSegmentItem({
    required this.label,
    this.icon,
    this.count,
    this.semanticsLabel,
  });

  final String label;
  final IconData? icon;

  /// Badge số bên phải nhãn — bỏ qua khi null hoặc 0.
  final int? count;

  /// Nhãn đọc cho screen reader khi [label] viết tắt.
  final String? semanticsLabel;

  bool get _hasBadge => (count ?? 0) > 0;
}

/// Segmented control trên nền brand — dùng cho [AppScreenHeader.footer] khi màn
/// hình có hai/ba chế độ xem ngang hàng (không phải tab có nội dung riêng).
///
/// Con trỏ chọn là một thẻ trắng trượt mượt giữa các ô thay vì tô lại từng ô,
/// nên chuyển chế độ trông liền mạch và giữ nhịp gọn của header.
class BrandHeaderSegment extends StatelessWidget {
  const BrandHeaderSegment({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.dense = false,
  }) : assert(items.length >= 2, 'Segment cần tối thiểu hai lựa chọn');

  final List<BrandSegmentItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final tileHeight = dense ? 40.0 : 44.0;
    // Pill lồng pill: con trỏ chọn và rãnh đồng tâm nên hai ô luôn cân nhau.
    final tileRadius = tileHeight / 2;
    const trackPad = 4.0;
    final index = selectedIndex.clamp(0, items.length - 1);
    final slot = items.length == 1
        ? 0.0
        : -1 + 2 * index / (items.length - 1);

    return Container(
      height: tileHeight + trackPad * 2,
      padding: const EdgeInsets.all(trackPad),
      decoration: BoxDecoration(
        color: onBrand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tileRadius + trackPad),
        border: Border.all(color: onBrand.withValues(alpha: 0.18)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: AppDurations.normal,
            curve: Curves.easeOutCubic,
            alignment: Alignment(slot, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / items.length,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(tileRadius),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (i, item) in items.indexed)
                Expanded(
                  child: _BrandSegmentTile(
                    item: item,
                    selected: i == index,
                    onBrand: onBrand,
                    dense: dense,
                    radius: tileRadius,
                    onTap: () {
                      if (i == index) return;
                      HapticFeedback.selectionClick();
                      onChanged(i);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandSegmentTile extends StatelessWidget {
  const _BrandSegmentTile({
    required this.item,
    required this.selected,
    required this.onBrand,
    required this.dense,
    required this.radius,
    required this.onTap,
  });

  final BrandSegmentItem item;
  final bool selected;
  final Color onBrand;
  final bool dense;
  final double radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.primaryDark
        : onBrand.withValues(alpha: 0.86);

    return Semantics(
      button: true,
      selected: selected,
      label: item.semanticsLabel ?? item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : onBrand.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          // Row co theo nội dung rồi mới căn giữa: icon + nhãn + badge luôn là
          // một khối cân giữa ô, không lệch khi nhãn dài ngắn khác nhau.
          child: ExcludeSemantics(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.icon != null) ...[
                        TweenAnimationBuilder(
                          tween: ColorTween(end: foreground),
                          duration: AppDurations.normal,
                          curve: Curves.easeOutCubic,
                          builder: (context, color, _) => Icon(
                            item.icon,
                            size: dense ? 15 : 16,
                            color: color ?? foreground,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      AnimatedDefaultTextStyle(
                        duration: AppDurations.normal,
                        curve: Curves.easeOutCubic,
                        style: AppTypography.style(
                          fontSize: dense ? 12.5 : 13,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: foreground,
                          letterSpacing: -0.1,
                          height: AppTypography.uppercaseHeight,
                        ),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (item._hasBadge) ...[
                        const SizedBox(width: 6),
                        _BrandSegmentBadge(
                          count: item.count!,
                          selected: selected,
                          onBrand: onBrand,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandSegmentBadge extends StatelessWidget {
  const _BrandSegmentBadge({
    required this.count,
    required this.selected,
    required this.onBrand,
  });

  final int count;
  final bool selected;
  final Color onBrand;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.normal,
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : onBrand.withValues(alpha: 0.2),
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: AppTypography.style(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: selected ? AppColors.primary : onBrand,
          height: 1.1,
          tabular: true,
        ),
      ),
    );
  }
}

class _BrandTabLabel extends StatelessWidget {
  const _BrandTabLabel({
    required this.item,
    required this.selected,
    required this.unselectedColor,
    required this.dense,
  });

  final BrandHeaderTabItem item;
  final bool selected;
  final Color unselectedColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.primaryDark : unselectedColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: dense ? 15 : 16,
                color: fg,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              item.label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                height: AppTypography.uppercaseHeight,
              ),
            ),
            if (item._hasBadge) ...[
              const SizedBox(width: 6),
              AnimatedContainer(
                duration: AppDurations.fast,
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : const Color(0x33FFFFFF),
                  borderRadius: AppRadius.brPill,
                  border: selected
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.18),
                        )
                      : null,
                ),
                child: Text(
                  item.count! > 99 ? '99+' : '${item.count}',
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? AppColors.primary : Colors.white,
                    height: 1.1,
                    tabular: true,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
