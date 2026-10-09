import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'gradient_header.dart';

/// Vỏ thẻ hero kính mờ dùng chung (báo cáo, công, lương, hồ sơ): gradient thương hiệu, vòng sáng, icon chìm,
/// bo đủ bốn góc và bóng teal — cùng ngôn ngữ với header phía trên.
class BrandHeroCard extends StatelessWidget {
  const BrandHeroCard({
    super.key,
    required this.ornamentIcon,
    required this.child,
    this.ornamentOnTop = false,
  });

  final IconData ornamentIcon;
  final Widget child;

  /// Đặt icon chìm ở góc trên — dùng khi đáy thẻ có hàng nút để icon không
  /// lấp sau nút.
  final bool ornamentOnTop;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.brXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brXl,
        child: GradientHeader(
          safeAreaTop: false,
          bottomRadius: 0,
          gradient: AppGradients.brandHero,
          ornamentIcon: ornamentIcon,
          ornamentScale: 0.9,
          ornamentIconOnTop: ornamentOnTop,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: child,
        ),
      ),
    );
  }
}

/// Nhãn đầu thẻ trên nền teal: chấm vàng đồng + chữ in hoa trong viên kính tối.
class BrandHeroEyebrow extends StatelessWidget {
  const BrandHeroEyebrow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: AppRadius.brPill,
        border: Border.all(
          color: AppColors.secondaryLight.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
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
                fontSize: 10.5,
                letterSpacing: 1.0,
                color: AppColors.secondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô icon kính trắng mờ trên nền brand.
class BrandGlassIconTile extends StatelessWidget {
  const BrandGlassIconTile({super.key, required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.46, color: Colors.white),
    );
  }
}

/// Rãnh thanh tiến độ trên nền brand: lõm tối, viền sáng mảnh; nội dung mọc
/// dần từ trái sang khi thẻ xuất hiện.
class BrandGlassTrack extends StatelessWidget {
  const BrandGlassTrack({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brPill,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppDurations.slow,
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(widthFactor: t, child: child),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Ô chỉ số bấm được trên nền brand — kiểu thẻ KPI tối giản.
///
/// Nhãn nhỏ in hoa ở trên, số lớn ở dưới; sắc riêng của chỉ số chỉ xuất hiện
/// ở vạch mảnh bên trái và chấm cạnh nhãn, icon lùi thành hoạ tiết chìm. Không
/// còn khối màu đặc tranh với nền teal nên ô gọn và sang hơn.
class BrandHeroStat extends StatelessWidget {
  const BrandHeroStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  /// `null`: ô chỉ hiển thị, ẩn mũi tên và không có hiệu ứng bấm.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = AppRadius.brCard;
    return Semantics(
      button: onTap != null,
      label: '$label: $value',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
          ),
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            splashColor: Colors.white.withValues(alpha: 0.10),
            highlightColor: Colors.white.withValues(alpha: 0.05),
            child: Stack(
              children: [
                Positioned(
                  right: -8,
                  bottom: -10,
                  child: Icon(
                    icon,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 14,
                  bottom: 14,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.uppercase(
                                fontSize: 10,
                                letterSpacing: 0.8,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                          ),
                          if (onTap != null)
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        maxLines: 1,
                        style: AppTypography.display(
                          fontSize: 28,
                          color: Colors.white,
                        ),
                      ),
                    ],
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
