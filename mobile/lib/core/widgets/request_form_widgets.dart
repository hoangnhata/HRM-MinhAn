import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'app_action_button.dart';

/// Thanh đáy chung của các form tạo đơn: "Huỷ" viền trung tính + nút gửi
/// gradient brand. Màu loại đơn không tô lên nút để mọi form cùng một nhịp.
class RequestFormBottomBar extends StatelessWidget {
  const RequestFormBottomBar({
    super.key,
    required this.saving,
    required this.submitLabel,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool saving;
  final String submitLabel;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isEdit = submitLabel == 'Lưu thay đổi';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        boxShadow: AppShadows.nav,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            12,
            AppSpacing.page,
            12,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: AppActionButton(
                  variant: AppActionVariant.outlineNeutral,
                  label: 'Huỷ',
                  onPressed: saving ? null : onCancel,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 3,
                child: AppActionButton(
                  variant: AppActionVariant.primary,
                  icon: isEdit ? Icons.save_rounded : Icons.send_rounded,
                  label: saving
                      ? (isEdit ? 'Đang lưu…' : 'Đang gửi…')
                      : submitLabel,
                  loading: saving,
                  onPressed: onSubmit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ô chọn ngày trong form: nhãn in hoa nhỏ, ngày cỡ lớn, icon lịch bên phải.
/// [emphasized] = ngày quan trọng nhất của đơn (viền teal).
class RequestDateTile extends StatelessWidget {
  const RequestDateTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final placeholder = value.startsWith('Chọn');
    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brControl,
          side: BorderSide(
            color: emphasized
                ? AppColors.primary.withValues(alpha: 0.45)
                : AppColors.border,
            width: emphasized ? 1.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          color: placeholder ? AppColors.surfaceAlt : AppColors.surface,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.uppercase(
                            fontSize: 9.5,
                            letterSpacing: 0.5,
                            color: emphasized
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            maxLines: 1,
                            style: placeholder
                                ? AppTypography.style(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textTertiary,
                                  )
                                : AppTypography.metric(
                                    fontSize: 15.5,
                                    color: AppColors.textPrimary,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.event_rounded,
                    size: 18,
                    color: placeholder
                        ? AppColors.textTertiary
                        : AppColors.primary,
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

/// Ô nhập nhiều dòng (lý do / nội dung) cùng kiểu cho mọi form tạo đơn.
InputDecoration requestFieldDecoration({
  String? label,
  String? hint,
  bool multiline = false,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    alignLabelWithHint: multiline,
    labelStyle: AppTypography.style(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
    hintStyle: AppTypography.style(
      fontSize: 12.5,
      color: AppColors.textTertiary,
    ),
    filled: true,
    fillColor: AppColors.surfaceAlt,
    border: OutlineInputBorder(borderRadius: AppRadius.brControl),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.brControl,
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.brControl,
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}
