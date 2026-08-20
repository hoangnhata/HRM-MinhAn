import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// Hộp xác nhận — có icon ngữ cảnh để người dùng nhận biết mức độ nguy hiểm.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Xác nhận',
  String cancelLabel = 'Huỷ',
  bool danger = false,
  IconData? icon,
}) async {
  final color = danger ? AppColors.error : AppColors.primary;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final width = MediaQuery.sizeOf(ctx).width;
      final dialogWidth = width >= 600 ? 420.0 : width - 40;

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SizedBox(
          width: dialogWidth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIconBadge(
                  icon: icon ??
                      (danger
                          ? Icons.warning_amber_rounded
                          : Icons.help_outline_rounded),
                  color: color,
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.sectionTitle(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                _DialogActions(
                  cancelLabel: cancelLabel,
                  confirmLabel: confirmLabel,
                  confirmColor: color,
                  onCancel: () => Navigator.of(ctx).pop(false),
                  onConfirm: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// Hộp nhập ghi chú (dùng khi duyệt/từ chối đơn, cần lý do).
Future<String?> showNoteInputDialog(
  BuildContext context, {
  required String title,
  String label = 'Ghi chú',
  String? hint,
  bool required = false,
  String confirmLabel = 'Xác nhận',
  Color? confirmColor,
}) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final width = MediaQuery.sizeOf(ctx).width;
      final dialogWidth = width >= 600 ? 420.0 : width - 40;

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SizedBox(
          width: dialogWidth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: AppTypography.sectionTitle()),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: controller,
                    maxLines: 4,
                    minLines: 3,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: label,
                      hintText: hint,
                      alignLabelWithHint: true,
                    ),
                    validator: required
                        ? (v) => (v == null || v.trim().isEmpty)
                            ? 'Vui lòng nhập $label'
                            : null
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DialogActions(
                    cancelLabel: 'Huỷ',
                    confirmLabel: confirmLabel,
                    confirmColor: confirmColor,
                    onCancel: () => Navigator.of(ctx).pop(),
                    onConfirm: () {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      Navigator.of(ctx).pop(controller.text.trim());
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  controller.dispose();
  return result;
}

/// SnackBar thống nhất — icon trạng thái + nền theo ngữ cảnh.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isSuccess = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final Color background = isError
      ? AppColors.error
      : isSuccess
          ? AppColors.success
          : AppColors.textPrimary;
  final IconData icon = isError
      ? Icons.error_outline_rounded
      : isSuccess
          ? Icons.check_circle_outline_rounded
          : Icons.info_outline_rounded;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: background,
      duration: Duration(seconds: isError ? 4 : 3),
      showCloseIcon: true,
      closeIconColor: Colors.white.withValues(alpha: 0.9),
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 19),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.body(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Bottom sheet chuẩn — bọc nội dung, tự cuộn khi dài, tránh bàn phím.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  String? subtitle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
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
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.body(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  child,
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.confirmColor,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final Color? confirmColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            onPressed: onConfirm,
            child: Text(confirmLabel),
          ),
        ),
      ],
    );
  }
}
