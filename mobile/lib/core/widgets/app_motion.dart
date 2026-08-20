import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_tokens.dart';

/// Chuyển động vào màn hình dùng chung. Hiệu ứng ngắn, tôn trọng thiết lập
/// giảm chuyển động của hệ điều hành, để giao diện vẫn phù hợp môi trường y tế.
class AppReveal extends StatelessWidget {
  const AppReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
    this.duration = AppDurations.normal,
  });

  final Widget child;
  final Duration delay;
  final double offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return child
        .animate(delay: delay, autoPlay: true)
        .fadeIn(duration: duration, curve: Curves.easeOutCubic)
        .slideY(
          begin: offset / 100,
          end: 0,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Tạo nhịp xuất hiện khác nhau cho các phần tử trong danh sách mà không cần
/// mỗi màn hình tự quản lý AnimationController.
class AppStagger {
  AppStagger._();

  static Duration delayFor(int index, {int stepMs = 42, int maxMs = 360}) {
    return Duration(milliseconds: (index * stepMs).clamp(0, maxMs));
  }
}
