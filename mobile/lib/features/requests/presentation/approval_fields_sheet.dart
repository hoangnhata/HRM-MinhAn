import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/notice_banner.dart';
import '../data/request_type_config.dart';

/// Ket qua nhap them khi duyet: cac truong rieng cua buoc duyet + y kien.
class ApprovalInput {
  const ApprovalInput({required this.extra, this.comment});

  final Map<String, dynamic> extra;
  final String? comment;
}

/// Mo bottom sheet thu thap thong tin bat buoc truoc khi duyet (VD: tien ho
/// tro dao tao, quyet dinh co cong / khong cong cua Giam doc).
Future<ApprovalInput?> showApprovalFieldsSheet(
  BuildContext context, {
  required RequestReviewStage stage,
  required String title,
}) {
  return showModalBottomSheet<ApprovalInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => _ApprovalFieldsForm(stage: stage, title: title),
  );
}

class _ApprovalFieldsForm extends StatefulWidget {
  const _ApprovalFieldsForm({required this.stage, required this.title});

  final RequestReviewStage stage;
  final String title;

  @override
  State<_ApprovalFieldsForm> createState() => _ApprovalFieldsFormState();
}

class _ApprovalFieldsFormState extends State<_ApprovalFieldsForm> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _choices = <String, bool>{};
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final field in widget.stage.approveFields) {
      if (field.type == ApprovalFieldType.yesNo) {
        _choices[field.key] = true;
      } else {
        _controllers[field.key] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final extra = <String, dynamic>{};
    for (final field in widget.stage.approveFields) {
      if (field.type == ApprovalFieldType.yesNo) {
        extra[field.key] = _choices[field.key];
      } else {
        final text = _controllers[field.key]!.text.trim();
        if (text.isNotEmpty) extra[field.key] = text;
      }
    }
    final comment = _commentController.text.trim();

    Navigator.of(context).pop(
      ApprovalInput(extra: extra, comment: comment.isEmpty ? null : comment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requiredCount = widget.stage.approveFields
        .where((field) => field.required)
        .length;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppIconBadge(
                      icon: Icons.fact_check_outlined,
                      color: AppColors.primary,
                      size: 42,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              widget.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Kiểm tra thông tin trước khi xác nhận duyệt.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                NoticeBanner(
                  icon: Icons.info_outline_rounded,
                  message: requiredCount == 0
                      ? 'Bạn có thể bổ sung thông tin và ý kiến duyệt nếu cần.'
                      : '$requiredCount trường có dấu * là thông tin bắt buộc.',
                ),
                const SizedBox(height: AppSpacing.md),
                for (final field in widget.stage.approveFields) ...[
                  if (field.type == ApprovalFieldType.yesNo)
                    _YesNoField(
                      field: field,
                      value: _choices[field.key] ?? true,
                      onChanged: (v) => setState(() => _choices[field.key] = v),
                    )
                  else
                    TextFormField(
                      controller: _controllers[field.key],
                      keyboardType: field.type == ApprovalFieldType.money
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: field.required
                            ? '${field.label} *'
                            : '${field.label} (không bắt buộc)',
                        hintText: field.hint,
                        helperText: field.type == ApprovalFieldType.money
                            ? 'Có thể nhập số tiền theo định dạng 2.000.000'
                            : null,
                        prefixIcon: Icon(
                          field.type == ApprovalFieldType.money
                              ? Icons.payments_outlined
                              : Icons.edit_note_rounded,
                        ),
                      ),
                      validator: field.required
                          ? (v) => (v == null || v.trim().isEmpty)
                                ? 'Vui lòng nhập ${field.label.toLowerCase()}'
                                : null
                          : null,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                TextFormField(
                  controller: _commentController,
                  minLines: 2,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Ý kiến duyệt (không bắt buộc)',
                    hintText: 'Nhập ghi chú để người gửi dễ theo dõi...',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SheetActions(
                  onCancel: () => Navigator.of(context).pop(),
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({required this.onCancel, required this.onSubmit});

  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stack = constraints.maxWidth < 330 || textScale > 1.25;
        final cancel = OutlinedButton(
          onPressed: onCancel,
          child: const Text('Huỷ'),
        );
        final submit = ElevatedButton.icon(
          onPressed: onSubmit,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Duyệt & ký'),
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              submit,
              const SizedBox(height: AppSpacing.xs),
              cancel,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cancel),
            const SizedBox(width: AppSpacing.sm),
            Expanded(flex: 2, child: submit),
          ],
        );
      },
    );
  }
}

class _YesNoField extends StatelessWidget {
  const _YesNoField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final ApprovalField field;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final first = _Choice(
      label: field.yesLabel,
      icon: Icons.check_circle_outline_rounded,
      selected: value,
      color: AppColors.success,
      onTap: () => onChanged(true),
    );
    final second = _Choice(
      label: field.noLabel,
      icon: Icons.remove_circle_outline_rounded,
      selected: !value,
      color: AppColors.textSecondary,
      onTap: () => onChanged(false),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.required ? '${field.label} *' : field.label,
          style: const TextStyle(
            fontSize: 12.8,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 310 || textScale > 1.35;
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  first,
                  const SizedBox(height: AppSpacing.xs),
                  second,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: first),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: second),
              ],
            );
          },
        ),
      ],
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
      label: '$label${selected ? ', đã chọn' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brSm,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? color : AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
    );
  }
}
