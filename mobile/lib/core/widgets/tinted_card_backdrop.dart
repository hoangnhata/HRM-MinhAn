import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Nền thẻ danh sách pha nhẹ theo một sắc nhận diện (trạng thái / loại đơn).
///
/// Dùng cặp với [AppCard]: truyền [TintedCardBackdrop.gradient] vào
/// `AppCard.gradient`, bọc nội dung bằng [TintedCardBackdrop] để có quầng sáng
/// góc trên trái và icon chìm góc dưới phải. Độ pha thấp để danh sách dài vẫn
/// đồng nhất, chỉ đủ phân biệt từng thẻ khi lướt.
class TintedCardBackdrop extends StatelessWidget {
  const TintedCardBackdrop({
    super.key,
    required this.accent,
    required this.child,
    this.watermarkIcon,
    this.glowOffset = const Offset(-36, -40),
  });

  final Color accent;
  final Widget child;

  /// Icon chìm cỡ lớn ở góc dưới phải; `null` thì chỉ có quầng sáng.
  final IconData? watermarkIcon;

  /// Vị trí quầng sáng (góc trên trái của hình tròn 140px) — đặt sau avatar/icon.
  final Offset glowOffset;

  /// Nền chuyển sắc: gần trắng ở góc trên trái, đậm dần về góc dưới phải.
  static LinearGradient gradient(Color accent) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.alphaBlend(accent.withValues(alpha: 0.05), AppColors.surface),
      AppColors.surface,
      Color.alphaBlend(accent.withValues(alpha: 0.11), AppColors.surface),
    ],
    stops: const [0.0, 0.45, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: glowOffset.dx,
          top: glowOffset.dy,
          child: IgnorePointer(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.14),
                    accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (watermarkIcon != null)
          Positioned(
            right: -14,
            bottom: -20,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(
                  watermarkIcon,
                  size: 92,
                  color: accent.withValues(alpha: 0.06),
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}

/// Ô icon đặc chuyển sắc có bóng màu — nhận diện loại đơn trên thẻ.
class TintedIconTile extends StatelessWidget {
  const TintedIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
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
            Color.lerp(color, Colors.white, 0.12)!,
            Color.lerp(color, Colors.black, 0.12)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.5, color: Colors.white),
    );
  }
}

/// Nút › tròn trắng viền mảnh theo sắc thẻ.
class TintedChevron extends StatelessWidget {
  const TintedChevron({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColors.textSecondary,
      ),
    );
  }
}
