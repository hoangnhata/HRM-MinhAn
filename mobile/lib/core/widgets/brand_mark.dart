import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Logo Bệnh viện Minh An — bản HD sạch, bo tròn mềm.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 76,
    this.heroTag,
    this.backgroundColor,
    this.showShadow = false,
  });

  final double size;
  final String? heroTag;
  final Color? backgroundColor;
  final bool showShadow;

  /// Bản HD đã xử lý răng cưa / nền đen.
  static const assetPath = 'assets/images/logo_hd.png';

  @override
  Widget build(BuildContext context) {
    final image = ClipOval(
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        gaplessPlayback: true,
        semanticLabel: 'Logo Bệnh viện Minh An',
      ),
    );

    Widget mark = image;

    if (backgroundColor != null || showShadow) {
      mark = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ?? Colors.white,
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 2),
                  ),
                ]
              : AppShadows.soft,
        ),
        child: image,
      );
    }

    return heroTag == null ? mark : Hero(tag: heroTag!, child: mark);
  }
}

/// Logo ứng dụng HRM — chữ **MA** như favicon trang web.
class AppMark extends StatelessWidget {
  const AppMark({
    super.key,
    this.size = 76,
    this.heroTag,
  });

  final double size;
  final String? heroTag;

  static const assetPath = 'assets/images/ma_logo.svg';

  @override
  Widget build(BuildContext context) {
    final image = SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      semanticsLabel: 'Logo ứng dụng HRM Minh An',
    );

    return heroTag == null ? image : Hero(tag: heroTag!, child: image);
  }
}
