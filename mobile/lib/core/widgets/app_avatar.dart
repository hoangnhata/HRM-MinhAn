import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import 'auth_network_image.dart';

/// Avatar tròn chuyên nghiệp — ảnh mạng / auth URL + fallback monogram.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.authImageUrl,
    required this.name,
    this.size = 40,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth,
    this.showShadow = true,
    this.useGradientFallback = true,
  });

  /// URL công khai (CachedNetworkImage).
  final String? imageUrl;

  /// URL cần kèm JWT (AuthNetworkImage) — ưu tiên hơn [imageUrl].
  final String? authImageUrl;

  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final bool showShadow;
  final bool useGradientFallback;

  @override
  Widget build(BuildContext context) {
    final ringWidth = borderWidth ?? (size >= 52 ? 2.5 : 2.0);
    final hasAuthImage = authImageUrl != null && authImageUrl!.isNotEmpty;
    final hasPublicImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Semantics(
      image: true,
      label: 'Ảnh đại diện của $name',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? Colors.white,
            width: ringWidth,
          ),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.16),
                    blurRadius: size * 0.28,
                    offset: Offset(0, size * 0.08),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: ClipOval(
          child: ExcludeSemantics(
            child: hasAuthImage
                ? AuthNetworkImage(
                    url: authImageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_) => _Monogram(
                      name: name,
                      size: size,
                      backgroundColor: backgroundColor,
                      foregroundColor: foregroundColor,
                      useGradient: useGradientFallback,
                    ),
                    placeholder: (_) => _Monogram(
                      name: name,
                      size: size,
                      backgroundColor: backgroundColor,
                      foregroundColor: foregroundColor,
                      useGradient: useGradientFallback,
                    ),
                  )
                : hasPublicImage
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    fadeInDuration: const Duration(milliseconds: 180),
                    errorWidget: (_, _, _) => _Monogram(
                      name: name,
                      size: size,
                      backgroundColor: backgroundColor,
                      foregroundColor: foregroundColor,
                      useGradient: useGradientFallback,
                    ),
                    placeholder: (_, _) => _Monogram(
                      name: name,
                      size: size,
                      backgroundColor: backgroundColor,
                      foregroundColor: foregroundColor,
                      useGradient: useGradientFallback,
                    ),
                  )
                : _Monogram(
                    name: name,
                    size: size,
                    backgroundColor: backgroundColor,
                    foregroundColor: foregroundColor,
                    useGradient: useGradientFallback,
                  ),
          ),
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({
    required this.name,
    required this.size,
    this.backgroundColor,
    this.foregroundColor,
    this.useGradient = true,
  });

  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    final initials = AppFormat.initials(name);
    final fg = foregroundColor ?? Colors.white;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: useGradient && backgroundColor == null
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryDark,
                      AppColors.primary,
                      AppColors.appBarMid,
                    ],
                    stops: [0.0, 0.55, 1.0],
                  )
                : null,
            color: useGradient && backgroundColor == null
                ? null
                : (backgroundColor ??
                      AppColors.primary.withValues(alpha: 0.14)),
          ),
        ),
        // Soft highlight — tạo chiều sâu nhẹ.
        Positioned(
          top: -size * 0.18,
          left: -size * 0.1,
          child: Container(
            width: size * 0.72,
            height: size * 0.55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        // Watermark icon rất nhẹ phía sau chữ.
        Align(
          alignment: const Alignment(0.55, 0.55),
          child: Icon(
            Icons.person_rounded,
            size: size * 0.42,
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        Center(
          child: Text(
            initials,
            style: AppTypography.style(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.34,
              letterSpacing: 0.4,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}
