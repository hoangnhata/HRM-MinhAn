import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Trạng thái rỗng — gọn, chuyên nghiệp, dễ đọc trên phone.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.action,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final minHeight = (MediaQuery.sizeOf(context).height * 0.38).clamp(
      240.0,
      360.0,
    );

    return Semantics(
      container: true,
      label: message == null ? title : '$title. $message',
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xxl,
              horizontal: AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HaloIcon(icon: icon, color: color),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Không thể tải dữ liệu. $message',
      child: EmptyState(
        icon: Icons.cloud_off_outlined,
        color: AppColors.error,
        title: 'Không thể tải dữ liệu',
        message: message,
        action: onRetry == null
            ? null
            : OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Thử lại'),
              ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: label ?? 'Đang tải dữ liệu',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 56),
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                if (label != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(label!, style: AppTypography.caption()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HaloIcon extends StatelessWidget {
  const _HaloIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: AppGradients.tint(color),
        borderRadius: AppRadius.brLg,
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Icon(icon, size: 30, color: color),
    );
  }
}
