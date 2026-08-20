import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import 'auth_network_image.dart';

/// Mở xem ảnh chữ ký / ảnh auth full màn — pinch zoom, chạm nền để đóng.
Future<void> showAuthImagePreview(
  BuildContext context, {
  required String url,
  String? title,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng xem chữ ký',
    barrierColor: Colors.black.withValues(alpha: 0.88),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _AuthImagePreviewPage(url: url, title: title);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

class _AuthImagePreviewPage extends StatelessWidget {
  const _AuthImagePreviewPage({required this.url, this.title});

  final String url;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Chạm nền tối để đóng.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox.expand(),
            ),
          ),
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height * 0.78,
                child: AuthNetworkImage(
                  url: url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title?.trim().isNotEmpty == true
                        ? title!.trim()
                        : 'Chữ ký số',
                    style: AppTypography.style(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: Text(
              'Chạm ngoài hoặc nút đóng · chụm để phóng to',
              textAlign: TextAlign.center,
              style: AppTypography.style(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ảnh chữ ký có thể nhấn để xem to.
class TappableAuthImage extends StatelessWidget {
  const TappableAuthImage({
    super.key,
    required this.url,
    this.title,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.borderRadius,
  });

  final String url;
  final String? title;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(6);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showAuthImagePreview(context, url: url, title: title),
        borderRadius: radius,
        child: Ink(
          width: width,
          height: height,
          child: AuthNetworkImage(url: url, fit: fit),
        ),
      ),
    );
  }
}
