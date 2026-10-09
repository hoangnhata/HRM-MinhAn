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
    this.gradient = AppGradients.header,
    this.ornamentIcon,
    this.ornamentScale = 1,
    this.ornamentIconOnTop = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double bottomRadius;
  final bool safeAreaTop;
  final Gradient gradient;

  /// Icon chìm cỡ lớn ở góc phải kèm vòng sáng đồng tâm — tạo chiều sâu cho
  /// header tab cấp một. `null` thì chỉ giữ nền gradient + vệt sáng.
  final IconData? ornamentIcon;

  /// Thu nhỏ lớp trang trí cho header thấp (dense).
  final double ornamentScale;

  /// Đặt icon chìm ở góc trên phải thay vì góc dưới — cho header có
  /// tab/segment ở chân, để icon không lấp ló sau thanh chọn.
  final bool ornamentIconOnTop;

  @override
  Widget build(BuildContext context) {
    final topInset = safeAreaTop ? MediaQuery.paddingOf(context).top : 0.0;

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
                  color: AppColors.primaryDark.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.10),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Vệt sáng mềm góc trên trái — chiều sâu thay cho mảng màu phẳng.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppGradients.headerGlow),
              ),
            ),
          ),
          if (ornamentIcon != null)
            Positioned.fill(
              child: IgnorePointer(
                child: _HeaderOrnament(
                  icon: ornamentIcon!,
                  scale: ornamentScale,
                  topInset: topInset,
                  iconOnTop: ornamentIconOnTop,
                ),
              ),
            ),
          // Ánh sáng mảnh ở mép trên (hiệu ứng kính) và đường chỉ mảnh ở mép dưới.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.14),
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

/// Lớp trang trí header: vòng sáng đồng tâm + icon chìm ở góc phải.
/// Độ mờ thấp để chữ trắng luôn đủ tương phản trên nền teal.
class _HeaderOrnament extends StatelessWidget {
  const _HeaderOrnament({
    required this.icon,
    required this.scale,
    required this.topInset,
    this.iconOnTop = false,
  });

  final IconData icon;
  final double scale;
  final double topInset;
  final bool iconOnTop;

  @override
  Widget build(BuildContext context) {
    final ring = 180.0 * scale;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -ring * 0.34,
          top: topInset - ring * 0.42,
          child: CustomPaint(size: Size.square(ring), painter: _RingsPainter()),
        ),
        Positioned(
          right: -14 * scale,
          bottom: iconOnTop ? null : -22 * scale,
          top: iconOnTop ? topInset - 10 * scale : null,
          child: Transform.rotate(
            angle: -0.18,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.13),
                  Colors.white.withValues(alpha: 0.02),
                ],
              ).createShader(bounds),
              child: Icon(icon, size: 118 * scale),
            ),
          ),
        ),
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    // Đĩa sáng mềm ở tâm, rồi các vòng chỉ mảnh nhạt dần ra ngoài.
    canvas.drawCircle(
      center,
      r * 0.62,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r * 0.62)),
    );
    for (final (factor, alpha) in [(0.62, 0.14), (0.86, 0.09), (1.0, 0.05)]) {
      canvas.drawCircle(
        center,
        r * factor,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    final iconBox = dense ? 36.0 : 50.0;
    // Màn con dense đã có nút trở về: bỏ ô icon để hàng đầu không bị hai khối
    // tròn/vuông na ná nhau — icon chuyển thành hoạ tiết chìm phía sau.
    final showBadge = !(dense && isNested);
    final titleShadow = [
      Shadow(
        color: AppColors.primaryDark.withValues(alpha: 0.35),
        blurRadius: 12,
        offset: const Offset(0, 2),
      ),
    ];
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
      bottomRadius: dense ? 0 : 28,
      ornamentIcon: icon,
      ornamentIconOnTop: footer != null,
      ornamentScale: dense ? (footer != null ? 0.72 : 0.62) : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isNested) ...[
                _HeaderBackButton(
                  onBack: onBack!,
                  dense: dense,
                  onBrand: onBrand,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (showBadge) ...[
                _HeaderIconBadge(
                  icon: icon,
                  size: iconBox,
                  iconSize: dense ? 18 : 24,
                  onBrand: onBrand,
                  elevated: !dense,
                ),
                SizedBox(width: dense ? 12 : 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showEyebrow) ...[
                      _HeaderEyebrow(text: eyebrow!, pill: !dense || isNested),
                      SizedBox(height: dense ? (isNested ? 6 : 3) : 7),
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
                                fontSize: isNested ? 20 : 17.5,
                                fontWeight: FontWeight.w800,
                                height: AppTypography.uppercaseHeight,
                                letterSpacing: isNested ? -0.4 : -0.1,
                              ).copyWith(shadows: isNested ? titleShadow : null)
                            : AppTypography.style(
                                color: onBrand,
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                height: AppTypography.uppercaseHeight,
                                letterSpacing: -0.7,
                              ).copyWith(shadows: titleShadow),
                      ),
                    ),
                    if (showSubtitle) ...[
                      SizedBox(height: dense ? (isNested ? 6 : 4) : 3),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: dense ? 12.5 : 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: onBrand.withValues(alpha: 0.8),
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
        color: onBrand.withValues(alpha: 0.16),
        shape: CircleBorder(
          side: BorderSide(color: onBrand.withValues(alpha: 0.24)),
        ),
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

/// Nhãn nhỏ phía trên tiêu đề: chấm vàng đồng + chữ in hoa. Header lớn dùng
/// dạng pill kính mờ; header dense giữ dạng chữ để không tăng chiều cao.
class _HeaderEyebrow extends StatelessWidget {
  const _HeaderEyebrow({required this.text, required this.pill});

  final String text;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.secondaryLight,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.secondaryLight.withValues(alpha: 0.6),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.uppercase(
              // Điểm nhấn vàng đồng thương hiệu — thay cho vạch vàng cũ ở mép header.
              color: AppColors.secondaryLight,
              fontSize: 10.5,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
    if (!pill) return label;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: AppRadius.brPill,
        border: Border.all(
          color: AppColors.secondaryLight.withValues(alpha: 0.28),
        ),
      ),
      child: label,
    );
  }
}

class _HeaderIconBadge extends StatelessWidget {
  const _HeaderIconBadge({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onBrand,
    this.elevated = false,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color onBrand;

  /// Ô kính nổi có bóng + vệt sáng nửa trên — dùng cho header lớn.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(size * 0.32);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            onBrand.withValues(alpha: elevated ? 0.30 : 0.24),
            onBrand.withValues(alpha: elevated ? 0.08 : 0.12),
          ],
        ),
        borderRadius: BorderRadius.all(radius),
        border: Border.all(color: onBrand.withValues(alpha: 0.28)),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (elevated)
              // Vệt sáng nửa trên — giả lập mặt kính cong.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: size / 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: radius),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            Icon(
              icon,
              color: onBrand,
              size: iconSize,
              shadows: elevated
                  ? [
                      Shadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ],
        ),
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
        gradient: AppGradients.header,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        gradient: AppGradients.headerGlow,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
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

  bool get _hasBadge => count != null && (showZeroCount || count! > 0);
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
/// Phong cách kính mờ: rãnh gần như trong suốt, con trỏ chọn là một tấm kính
/// trắng mờ có viền sáng trượt giữa các ô; chữ luôn trắng, ô chọn đậm và sáng
/// hơn. Đồng bộ với nút kính, eyebrow và ô icon trên cùng header.
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
    // Rãnh và con trỏ đồng tâm (rãnh = con trỏ + đệm) nên hai lớp luôn song song.
    final tileRadius = dense ? 12.0 : 13.0;
    const trackPad = 3.0;
    final index = selectedIndex.clamp(0, items.length - 1);
    final slot = items.length == 1 ? 0.0 : -1 + 2 * index / (items.length - 1);

    return Container(
      height: tileHeight + trackPad * 2,
      padding: const EdgeInsets.all(trackPad),
      decoration: BoxDecoration(
        color: onBrand.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(tileRadius + trackPad),
        border: Border.all(color: onBrand.withValues(alpha: 0.12)),
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
              child: _GlassThumb(radius: tileRadius, onBrand: onBrand),
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

/// Tấm kính trắng mờ: nền sáng dần lên mép trên, viền sáng, vệt phản quang
/// nửa trên và bóng mềm để tách khỏi rãnh.
class _GlassThumb extends StatelessWidget {
  const _GlassThumb({required this.radius, required this.onBrand});

  final double radius;
  final Color onBrand;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            onBrand.withValues(alpha: 0.28),
            onBrand.withValues(alpha: 0.14),
          ],
        ),
        border: Border.all(color: onBrand.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            heightFactor: 0.5,
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    onBrand.withValues(alpha: 0.16),
                    onBrand.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    final foreground = onBrand.withValues(alpha: selected ? 1 : 0.64);

    return Semantics(
      button: true,
      selected: selected,
      label: item.semanticsLabel ?? item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: onBrand.withValues(alpha: 0.12),
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
                            size: dense ? 16 : 17,
                            color: color ?? foreground,
                          ),
                        ),
                        const SizedBox(width: 7),
                      ],
                      AnimatedDefaultTextStyle(
                        duration: AppDurations.normal,
                        curve: Curves.easeOutCubic,
                        style:
                            AppTypography.style(
                              fontSize: dense ? 13 : 13.5,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: foreground,
                              letterSpacing: -0.1,
                              height: AppTypography.uppercaseHeight,
                            ).copyWith(
                              shadows: selected
                                  ? [
                                      Shadow(
                                        color: AppColors.primaryDark.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : const [],
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
        // Ô chọn: badge vàng đồng nổi trên kính; ô thường: kính mờ.
        gradient: selected ? AppGradients.gold : null,
        color: selected ? null : onBrand.withValues(alpha: 0.16),
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: AppTypography.style(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: onBrand,
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
              Icon(item.icon, size: dense ? 15 : 16, color: fg),
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
