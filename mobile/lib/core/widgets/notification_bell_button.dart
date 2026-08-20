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
  });

  final VoidCallback onTap;
  final int unreadCount;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final label = hasUnread
        ? 'Thông báo, $unreadCount chưa đọc'
        : 'Thông báo';

    return Semantics(
      button: true,
      label: label,
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
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0.10),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      hasUnread
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_rounded,
                      color: Colors.white,
                      size: size * 0.48,
                    ),
                  ),
                  if (hasUnread)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFE25563),
                              AppColors.error,
                            ],
                          ),
                          borderRadius: AppRadius.brPill,
                          border: Border.all(color: Colors.white, width: 1.6),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error.withValues(alpha: 0.45),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          textScaler: TextScaler.noScaling,
                          style: AppTypography.style(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
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
