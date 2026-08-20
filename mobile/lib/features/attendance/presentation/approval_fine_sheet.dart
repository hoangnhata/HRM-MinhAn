import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../shared/models/attendance_models.dart';
import 'attendance_enums.dart';

/// Quyet dinh cua HCNS / Giam doc khi duyet don cong co lien quan tien phat.
class FineDecision {
  const FineDecision({required this.waiveForgotFine, this.comment});

  final bool waiveForgotFine;
  final String? comment;
}

/// Mo bottom sheet duyet don kem lua chon co / khong tru tien phat quen cham
/// cong (di muon, ve som). Tra ve `null` neu nguoi dung huy.
Future<FineDecision?> showApprovalWithFineSheet(
  BuildContext context, {
  required AttendanceWorkRequest request,
}) {
  return showModalBottomSheet<FineDecision>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _FineSheet(request: request),
  );
}

class _FineSheet extends StatefulWidget {
  const _FineSheet({required this.request});

  final AttendanceWorkRequest request;

  @override
  State<_FineSheet> createState() => _FineSheetState();
}

class _FineSheetState extends State<_FineSheet> {
  final _commentController = TextEditingController();

  /// Mặc định vẫn trừ tiền phạt như quy định.
  bool _waive = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUpdate = widget.request.requestType == 'UPDATE';
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final maxHeight =
        media.size.height - media.padding.top - AppSpacing.md - keyboardInset;

    return AnimatedPadding(
      duration: AppDurations.fast,
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight.clamp(240.0, 760.0).toDouble(),
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Duyệt đơn',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  AttendanceEnums.requestTypeLabel(widget.request.requestType),
                  style: AppTypography.body(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                NoticeBanner(
                  icon: Icons.savings_outlined,
                  color: AppColors.warning,
                  message: isUpdate
                      ? 'Theo quy định, đơn bổ sung công bị trừ tiền quên chấm công. Bạn có thể miễn trừ nếu có lý do chính đáng.'
                      : 'Đơn giải trình đi muộn/về sớm có thể bị trừ tiền phạt. Bạn có thể miễn trừ nếu có lý do chính đáng.',
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Quyết định tiền phạt',
                  style: AppTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stack =
                        constraints.maxWidth < 330 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.2;
                    final deduct = _Choice(
                      label: 'Vẫn trừ tiền',
                      icon: Icons.remove_circle_outline_rounded,
                      selected: !_waive,
                      color: AppColors.warning,
                      onTap: () => setState(() => _waive = false),
                    );
                    final waive = _Choice(
                      label: 'Miễn trừ',
                      icon: Icons.volunteer_activism_outlined,
                      selected: _waive,
                      color: AppColors.success,
                      onTap: () => setState(() => _waive = true),
                    );
                    if (stack) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          deduct,
                          const SizedBox(height: AppSpacing.xs),
                          waive,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: deduct),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(child: waive),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _commentController,
                  minLines: 2,
                  maxLines: 4,
                  scrollPadding: EdgeInsets.only(
                    bottom: keyboardInset + AppSpacing.xxxl,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Ý kiến duyệt (không bắt buộc)',
                    helperText: 'Ý kiến này sẽ được lưu trong lịch sử duyệt.',
                    helperMaxLines: 2,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Huỷ'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final comment = _commentController.text.trim();
                          Navigator.of(context).pop(
                            FineDecision(
                              waiveForgotFine: _waive,
                              comment: comment.isEmpty ? null : comment,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Duyệt & ký'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: AppDurations.fast,
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.08)
                : AppColors.surfaceMuted,
            borderRadius: AppRadius.brSm,
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: 1.4,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: selected ? color : AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppTypography.style(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// True khi HCNS/Giám đốc duyệt UPDATE/EXPLANATION cần chọn trừ/miễn phạt.
bool attendanceNeedsFineDecision(AttendanceWorkRequest r) {
  final atFineStage =
      r.status == 'PENDING_HR' || r.status == 'PENDING_DIRECTOR';
  final finableType =
      r.requestType == 'UPDATE' || r.requestType == 'EXPLANATION';
  return atFineStage && finableType;
}

/// Chọn trừ/miễn phạt khi duyệt hàng loạt đơn công.
/// Trả về `null` nếu huỷ; `true` = không trừ tiền; `false` = trừ tiền.
Future<bool?> showBulkFineDecisionSheet(
  BuildContext context, {
  required int fineTargetCount,
  required int totalCount,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quyết định tiền phạt',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                '$fineTargetCount/$totalCount đơn cập nhật công / giải trình '
                'đang ở bước HCNS hoặc Giám đốc. Chọn áp dụng cho các đơn này.',
                style: AppTypography.body(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Lựa chọn gửi qua cùng API duyệt từng đơn (waiveForgotFine), giống web.',
                style: AppTypography.body(
                  fontSize: 12.5,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(false),
                icon: const Icon(Icons.payments_outlined),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                ),
                label: const Text('Có trừ tiền phạt'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: const Icon(Icons.money_off_rounded),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                label: const Text('Không trừ tiền phạt'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Huỷ'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
