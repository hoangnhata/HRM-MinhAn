import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Nút chuông thông báo trên header brand — badge đếm chưa đọc.
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({
    super.key,
    required this.onTap,
    this.unreadCount = 0,
    this.size = 42,
    this.framed = true,
  });

  final VoidCallback onTap;
  final int unreadCount;
  final double size;

  /// `true`: nút tròn kính mờ đứng riêng. `false`: nền trong suốt, dùng khi
  /// đặt trong một cụm hành động đã có khung (vd. thanh đầu Dashboard).
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final label = hasUnread ? 'Thông báo, $unreadCount chưa đọc' : 'Thông báo';

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: hasUnread ? '$unreadCount thông báo chưa đọc' : 'Thông báo',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: framed
                          ? null
                          : Colors.white.withValues(alpha: 0.08),
                      gradient: framed
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.22),
                                Colors.white.withValues(alpha: 0.10),
                              ],
                            )
                          : null,
                      border: framed
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            )
                          : null,
                      boxShadow: framed
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      hasUnread
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: size * 0.5,
                    ),
                  ),
                  if (hasUnread)
                    Positioned(
                      right: -5,
                      top: -4,
                      child: _UnreadBadge(count: unreadCount),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge đỏ viền teal đậm — viền cùng tông nền header nên badge như "khoét"
/// vào nút thay vì dán đè một vòng trắng thô.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEF5B6A), AppColors.error],
        ),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: AppColors.primaryDark, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        textScaler: TextScaler.noScaling,
        style: AppTypography.style(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
          tabular: true,
        ),
      ),
    );
  }
}
