import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_action_button.dart';

/// Thanh hành động cố định ở đáy màn chi tiết đơn/phiếu.
///
/// Hai nhóm hành động có thứ bậc rõ ràng:
/// - Người duyệt: **Duyệt** (gradient brand, nổi bật nhất) và **Từ chối**
///   (tonal đỏ — đủ rõ nhưng không tranh nổi với nút chính).
/// - Người lập: **Chỉnh sửa** (tonal teal) và **Rút đơn** (viền trung tính,
///   chữ đỏ). Khi cùng xuất hiện với nhóm duyệt, nhóm này thu gọn lại.
///
/// Truyền `null` cho callback để ẩn nút tương ứng. Khi [busy], mọi nút bị khoá
/// và thanh tiến trình mảnh chạy trên cùng.
class ApprovalActionBar extends StatelessWidget {
  const ApprovalActionBar({
    super.key,
    this.busy = false,
    this.onApprove,
    this.onReject,
    this.onEdit,
    this.onWithdraw,
    this.approveLabel = 'Duyệt',
    this.approveIcon = Icons.check_rounded,
    this.rejectLabel = 'Từ chối',
    this.editLabel = 'Chỉnh sửa',
    this.withdrawLabel = 'Rút đơn',
    this.withdrawIcon = Icons.undo_rounded,
    this.approveSemanticLabel,
    this.rejectSemanticLabel,
    this.busySemanticLabel = 'Đang xử lý yêu cầu, vui lòng chờ',
  });

  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onEdit;
  final VoidCallback? onWithdraw;
  final String approveLabel;
  final IconData approveIcon;
  final String rejectLabel;
  final String editLabel;
  final String withdrawLabel;
  final IconData withdrawIcon;
  final String? approveSemanticLabel;
  final String? rejectSemanticLabel;
  final String busySemanticLabel;

  bool get _hasReview => onApprove != null || onReject != null;
  bool get _hasOwner => onEdit != null || onWithdraw != null;

  @override
  Widget build(BuildContext context) {
    if (!_hasReview && !_hasOwner) return const SizedBox.shrink();

    // Nhóm người lập chỉ thu gọn khi phải nhường chỗ cho nhóm duyệt.
    final ownerCompact = _hasReview;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        border: const Border(top: BorderSide(color: AppColors.borderSoft)),
        boxShadow: AppShadows.nav,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BusyIndicator(busy: busy, label: busySemanticLabel),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm - 2,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
                  final stack = constraints.maxWidth < 330 || textScale > 1.25;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_hasOwner)
                        _pair(
                          stack: stack,
                          gap: AppSpacing.xs,
                          leading: onEdit == null
                              ? null
                              : AppActionButton(
                                  variant: AppActionVariant.tonalPrimary,
                                  compact: ownerCompact,
                                  icon: Icons.edit_outlined,
                                  label: editLabel,
                                  onPressed: busy ? null : onEdit,
                                ),
                          trailing: onWithdraw == null
                              ? null
                              : AppActionButton(
                                  variant: AppActionVariant.outlineDanger,
                                  compact: ownerCompact,
                                  icon: withdrawIcon,
                                  label: withdrawLabel,
                                  onPressed: busy ? null : onWithdraw,
                                ),
                        ),
                      if (_hasOwner && _hasReview)
                        const SizedBox(height: AppSpacing.xs + 2),
                      if (_hasReview)
                        _pair(
                          stack: stack,
                          gap: AppSpacing.sm,
                          // Khi xếp dọc, nút chính lên trên cho dễ chạm bằng
                          // ngón cái; khi xếp ngang, nút chính nằm bên phải.
                          primaryFirstWhenStacked: true,
                          leadingFlex: 2,
                          trailingFlex: 3,
                          leading: onReject == null
                              ? null
                              : AppActionButton(
                                  variant: AppActionVariant.tonalDanger,
                                  icon: Icons.close_rounded,
                                  label: rejectLabel,
                                  semanticLabel: rejectSemanticLabel,
                                  onPressed: busy ? null : onReject,
                                ),
                          trailing: onApprove == null
                              ? null
                              : AppActionButton(
                                  variant: AppActionVariant.primary,
                                  icon: approveIcon,
                                  label: approveLabel,
                                  semanticLabel: approveSemanticLabel,
                                  onPressed: busy ? null : onApprove,
                                ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pair({
    required bool stack,
    required double gap,
    required Widget? leading,
    required Widget? trailing,
    bool primaryFirstWhenStacked = false,
    int leadingFlex = 1,
    int trailingFlex = 1,
  }) {
    if (leading == null) return trailing!;
    if (trailing == null) return leading;
    if (stack) {
      final ordered = primaryFirstWhenStacked
          ? [trailing, leading]
          : [leading, trailing];
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ordered[0],
          SizedBox(height: gap),
          ordered[1],
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: leadingFlex, child: leading),
        SizedBox(width: gap),
        Expanded(flex: trailingFlex, child: trailing),
      ],
    );
  }
}

class _BusyIndicator extends StatelessWidget {
  const _BusyIndicator({required this.busy, required this.label});

  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      child: AnimatedSwitcher(
        duration: AppDurations.fast,
        child: busy
            ? Semantics(
                key: const ValueKey('busy'),
                liveRegion: true,
                label: label,
                child: const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: AppColors.primaryContainer,
                  color: AppColors.primary,
                ),
              )
            : const SizedBox(key: ValueKey('idle'), height: 2),
      ),
    );
  }
}
