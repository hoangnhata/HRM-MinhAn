import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Nền khí quyển dùng chung toàn app — gradient mint nhẹ + soft orb brand.
class AppAmbientBackground extends StatelessWidget {
  const AppAmbientBackground({super.key, this.intensity = 1});

  /// 0–1: độ đậm của tint (màn push có thể nhẹ hơn).
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final t = intensity.clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              AppColors.background,
              AppColors.primary.withValues(alpha: 0.10),
              t,
            )!,
            AppColors.background,
            AppColors.surfaceAlt,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -80,
            child: _Orb(
              size: 240,
              color: AppColors.primaryLight.withValues(alpha: 0.13 * t),
            ),
          ),
          Positioned(
            top: 220,
            left: -90,
            child: _Orb(
              size: 220,
              color: AppColors.primary.withValues(alpha: 0.07 * t),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -50,
            child: _Orb(
              size: 160,
              color: AppColors.secondary.withValues(alpha: 0.05 * t),
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
