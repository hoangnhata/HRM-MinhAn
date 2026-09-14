import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Nút mũi tên điều hướng kỳ — vùng chạm 44px theo chuẩn tối thiểu.
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
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Material(
          color: AppColors.surface,
          borderRadius: AppRadius.brBase,
          child: InkWell(
            onTap: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    onTap();
                  }
                : null,
            borderRadius: AppRadius.brBase,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 22, color: AppColors.primaryDark),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thanh chọn kỳ báo cáo: tháng (bắt buộc) + phạm vi khoa/phòng (tuỳ chọn).
///
/// Thay cho các bản sao `_PeriodNavigator` / `_CompliancePeriodBar` từng được
/// viết lại ở mỗi màn báo cáo. Bỏ [scopeLabel] nếu màn chỉ chọn tháng.
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
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
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
              const SizedBox(width: 4),
              Expanded(
                child: _PickerTile(
                  height: 44,
                  semanticsLabel: 'Chọn tháng, $label',
                  onTap: onPickMonth,
                  leading: const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: AppColors.primaryDark,
                  ),
                  label: label,
                  labelStyle: AppTypography.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.15,
                    color: AppColors.textPrimary,
                  ),
                  showChevron: true,
                ),
              ),
              const SizedBox(width: 4),
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
            _PickerTile(
              height: 44,
              semanticsLabel: canPickScope
                  ? 'Chọn phạm vi, đang xem $scopeLabel'
                  : scopeLabel!,
              onTap: canPickScope ? onPickScope : null,
              leading: Icon(
                scopeIcon,
                size: 15,
                color: canPickScope
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              label: scopeLabel!,
              labelStyle: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              showChevron: canPickScope,
            ),
          ],
        ],
      ),
    );
  }
}

/// Ô bấm để mở picker — nội dung căn giữa quang học, có chevron cân đối.
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.height,
    required this.semanticsLabel,
    required this.onTap,
    required this.leading,
    required this.label,
    required this.labelStyle,
    required this.showChevron,
  });

  final double height;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final Widget leading;
  final String label;
  final TextStyle labelStyle;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.brBase,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          borderRadius: AppRadius.brBase,
          child: ExcludeSemantics(
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  // Chừa hai bên bằng nhau để nhãn nằm giữa thật, kể cả khi
                  // không có chevron.
                  const SizedBox(width: 22),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        leading,
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: labelStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 22,
                    child: showChevron
                        ? const Icon(
                            Icons.expand_more_rounded,
                            size: 18,
                            color: AppColors.textTertiary,
                          )
                        : null,
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
