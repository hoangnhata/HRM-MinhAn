import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Anh tai qua API can xac thuc (avatar/chu ky) — tu dong gan header
/// Authorization: Bearer truoc khi tai.
class AuthNetworkImage extends ConsumerWidget {
  const AuthNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.cacheKey,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? errorWidget;
  final String? cacheKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: ref.read(tokenStorageProvider).readToken(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return placeholder?.call(context) ?? const SizedBox.shrink();
        }
        final token = snapshot.data;
        return CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          width: width,
          height: height,
          cacheKey: cacheKey,
          httpHeaders: token != null && token.isNotEmpty ? {'Authorization': 'Bearer $token'} : null,
          placeholder: placeholder != null ? (ctx, _) => placeholder!(ctx) : null,
          errorWidget: (ctx, _, _) => errorWidget?.call(ctx) ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
