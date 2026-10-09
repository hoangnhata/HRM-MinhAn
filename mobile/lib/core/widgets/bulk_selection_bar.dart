import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Thanh thao tác hàng loạt khi đang chọn nhiều mục chờ duyệt: số đã chọn,
/// chọn tất cả / bỏ chọn và cặp nút Từ chối · Duyệt.
class BulkSelectionBar extends StatelessWidget {
  const BulkSelectionBar({
    super.key,
    required this.count,
    required this.busy,
    required this.totalSelectable,
    required this.onSelectAll,
    required this.onClear,
    required this.onApprove,
    required this.onReject,
    this.approveLabel = 'Duyệt',
    this.approveIcon = Icons.check_rounded,
  });

  final int count;
  final bool busy;
  final int totalSelectable;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  /// Nhãn/icon nút chính — vd. "Duyệt & ký" cho phiếu cần chữ ký số.
  final String approveLabel;
  final IconData approveIcon;

  @override
  Widget build(BuildContext context) {
    final allSelected = count >= totalSelectable && totalSelectable > 0;

    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.brPill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Viên giãn theo số chữ số (tròn khi 1 số, thuôn khi 2–3 số)
                      // thay cho vòng tròn cố định 18px làm "28" tràn lệch tâm.
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadius.brPill,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          count > 999 ? '999+' : '$count',
                          textAlign: TextAlign.center,
                          textScaler: TextScaler.noScaling,
                          style: AppTypography.style(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            tabular: true,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'đã chọn',
                        style: AppTypography.style(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _BulkSelectionLink(
                  label: allSelected
                      ? 'Đã chọn hết'
                      : 'Tất cả ($totalSelectable)',
                  enabled: !busy && !allSelected,
                  onTap: onSelectAll,
                ),
                const SizedBox(width: 4),
                Container(
                  width: 1,
                  height: 12,
                  color: AppColors.border.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                _BulkSelectionLink(
                  label: 'Bỏ chọn',
                  enabled: !busy,
                  onTap: onClear,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: busy ? null : onReject,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 46,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: busy
                                  ? AppColors.error.withValues(alpha: 0.4)
                                  : AppColors.error,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Từ chối',
                              style: AppTypography.style(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: busy
                                    ? AppColors.error.withValues(alpha: 0.4)
                                    : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: busy
                        ? AppColors.primary.withValues(alpha: 0.55)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: busy ? null : onApprove,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 46,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (busy)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              Icon(approveIcon, size: 18, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              busy ? 'Đang xử lý…' : approveLabel,
                              style: AppTypography.style(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkSelectionLink extends StatelessWidget {
  const _BulkSelectionLink({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: AppTypography.style(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: enabled ? AppColors.primaryDark : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
