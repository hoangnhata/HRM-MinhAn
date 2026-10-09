import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Bóng hai lớp cho các ô trắng nổi trên rãnh lõm (mềm + sắc mép).
List<BoxShadow> get _raisedShadow => [
  BoxShadow(
    color: AppColors.textPrimary.withValues(alpha: 0.09),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
  BoxShadow(
    color: AppColors.textPrimary.withValues(alpha: 0.05),
    blurRadius: 1,
    offset: const Offset(0, 1),
  ),
];

/// Nút mũi tên điều hướng kỳ — nút tròn trắng nổi, vùng chạm 44px.
class AppNavArrow extends StatelessWidget {
  const AppNavArrow({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticsLabel,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticsLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: AnimatedOpacity(
        duration: AppDurations.fast,
        opacity: enabled ? 1 : 0.4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: enabled ? _raisedShadow : null,
          ),
          child: Material(
            color: enabled
                ? AppColors.surface
                : Colors.white.withValues(alpha: 0.6),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onTap();
                    }
                  : null,
              child: SizedBox.square(
                dimension: 44,
                child: Icon(
                  icon,
                  size: 22,
                  color: enabled
                      ? AppColors.primaryDark
                      : AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thanh chọn kỳ báo cáo: tháng (bắt buộc) + phạm vi khoa/phòng (tuỳ chọn).
///
/// Rãnh lõm không viền, các ô trắng nổi bằng bóng; hàng tháng căn giữa giữa
/// hai nút tròn, hàng phạm vi căn trái kèm nhãn "Phạm vi" để đọc như một
/// trường chọn. Bỏ [scopeLabel] nếu màn chỉ chọn tháng.
class AppPeriodNavigator extends StatelessWidget {
  const AppPeriodNavigator({
    super.key,
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onPickMonth,
    this.canGoBack = true,
    this.canGoForward = true,
    this.scopeLabel,
    this.onPickScope,
    this.canPickScope = false,
    this.scopeIcon = Icons.apartment_rounded,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPickMonth;
  final bool canGoBack;
  final bool canGoForward;

  /// Tên phạm vi đang xem. `null` để ẩn hàng chọn phạm vi.
  final String? scopeLabel;
  final VoidCallback? onPickScope;
  final bool canPickScope;
  final IconData scopeIcon;

  @override
  Widget build(BuildContext context) {
    final label =
        'Tháng ${month.month.toString().padLeft(2, '0')}/${month.year}';

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDDE8E6), Color(0xFFE9F1F0)],
        ),
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [BoxShadow(color: Color(0xCCFFFFFF), offset: Offset(0, 1))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppNavArrow(
                icon: Icons.chevron_left_rounded,
                semanticsLabel: 'Tháng trước',
                enabled: canGoBack,
                onTap: onPrev,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _RaisedTile(
                  semanticsLabel: 'Chọn tháng, $label',
                  onTap: onPickMonth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _IconBubble(icon: Icons.calendar_month_rounded),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            height: AppTypography.uppercaseHeight,
                            tabular: true,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AppNavArrow(
                icon: Icons.chevron_right_rounded,
                semanticsLabel: 'Tháng sau',
                enabled: canGoForward,
                onTap: onNext,
              ),
            ],
          ),
          if (scopeLabel != null) ...[
            const SizedBox(height: 6),
            _RaisedTile(
              semanticsLabel: canPickScope
                  ? 'Chọn phạm vi, đang xem $scopeLabel'
                  : 'Phạm vi: $scopeLabel',
              onTap: canPickScope ? onPickScope : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    _IconBubble(icon: scopeIcon, muted: !canPickScope),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PHẠM VI',
                            style: AppTypography.uppercase(
                              fontSize: 8.5,
                              letterSpacing: 0.7,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          Text(
                            scopeLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.style(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: AppTypography.uppercaseHeight,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canPickScope)
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 3, 5, 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: AppRadius.brPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Đổi',
                              style: AppTypography.style(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                height: AppTypography.uppercaseHeight,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const Icon(
                              Icons.expand_more_rounded,
                              size: 16,
                              color: AppColors.primaryDark,
                            ),
                          ],
                        ),
                      )
                    else
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 15,
                        color: AppColors.textTertiary,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Đĩa icon nhỏ nền teal nhạt (xám khi chỉ đọc).
class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, this.muted = false});

  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: muted ? AppColors.surfaceMuted : AppColors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 15,
        color: muted ? AppColors.textSecondary : AppColors.primaryDark,
      ),
    );
  }
}

/// Ô trắng nổi trên rãnh — bấm để mở picker (hoặc chỉ hiển thị khi [onTap] null).
class _RaisedTile extends StatelessWidget {
  const _RaisedTile({
    required this.semanticsLabel,
    required this.onTap,
    required this.child,
  });

  final String semanticsLabel;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.brPaper,
          boxShadow: _raisedShadow,
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: AppRadius.brPaper,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            child: SizedBox(height: 46, child: child),
          ),
        ),
      ),
    );
  }
}
