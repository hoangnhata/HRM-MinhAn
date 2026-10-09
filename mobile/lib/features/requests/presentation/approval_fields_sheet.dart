import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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
                          Text(
                            'Kiểm tra thông tin trước khi xác nhận duyệt.',
                            style: AppTypography.style(
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
  const _SheetActions({
    required this.onCancel,
    required this.onSubmit,
    this.submitLabel = 'Duyệt & ký',
    this.submitIcon = Icons.check_rounded,
    this.submitColor,
  });

  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final String submitLabel;
  final IconData submitIcon;
  final Color? submitColor;

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
          style: submitColor == null
              ? null
              : ElevatedButton.styleFrom(
                  backgroundColor: submitColor,
                  foregroundColor: Colors.white,
                ),
          icon: Icon(submitIcon, size: 18),
          label: Text(submitLabel),
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
          style: AppTypography.style(
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
                    style: AppTypography.style(
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

/* ------------------------------------------------------------------------ */
/* Sửa quyết định Giám đốc — phiếu hội thảo đã xử lý                         */
/* ------------------------------------------------------------------------ */

/// Quyết định của Giám đốc với phiếu hội thảo.
enum SeminarDecision { paid, unpaid, reject }

class SeminarDecisionInput {
  const SeminarDecisionInput({
    required this.decision,
    this.supportAmount,
    this.comment,
  });

  final SeminarDecision decision;
  final String? supportAmount;
  final String? comment;

  bool get approved => decision != SeminarDecision.reject;

  /// Trường gửi kèm khi duyệt (backend bắt buộc chọn có / không công).
  Map<String, dynamic> get extra => approved
      ? {
          'withPay': decision == SeminarDecision.paid,
          if (supportAmount != null) 'supportAmount': supportAmount,
        }
      : const {};
}

/// Quyết định hiện tại suy ra từ phiếu.
SeminarDecision seminarDecisionOf(Map<String, dynamic> raw) {
  if (raw['status'] == 'DIRECTOR_REJECTED') return SeminarDecision.reject;
  return raw['withPay'] == false
      ? SeminarDecision.unpaid
      : SeminarDecision.paid;
}

/// Giám đốc đổi có công / không công hoặc từ chối phiếu hội thảo đã xử lý —
/// tương đương "Lưu chỉnh sửa · Giám đốc" trên web.
Future<SeminarDecisionInput?> showSeminarDecisionSheet(
  BuildContext context, {
  required Map<String, dynamic> raw,
}) {
  return showModalBottomSheet<SeminarDecisionInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => _SeminarDecisionForm(raw: raw),
  );
}

class _SeminarDecisionForm extends StatefulWidget {
  const _SeminarDecisionForm({required this.raw});

  final Map<String, dynamic> raw;

  @override
  State<_SeminarDecisionForm> createState() => _SeminarDecisionFormState();
}

class _SeminarDecisionFormState extends State<_SeminarDecisionForm> {
  final _formKey = GlobalKey<FormState>();
  late final SeminarDecision _current = seminarDecisionOf(widget.raw);
  late SeminarDecision _decision = _current;
  late final _supportController = TextEditingController(
    text: widget.raw['supportAmount']?.toString() ?? '',
  );
  late final _commentController = TextEditingController(
    text: widget.raw['directorComment']?.toString() ?? '',
  );

  @override
  void dispose() {
    _supportController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final support = _supportController.text.trim();
    final comment = _commentController.text.trim();
    Navigator.of(context).pop(
      SeminarDecisionInput(
        decision: _decision,
        supportAmount: support.isEmpty ? null : support,
        comment: comment.isEmpty ? null : comment,
      ),
    );
  }

  String get _effectMessage => switch (_decision) {
    SeminarDecision.paid =>
      'Các buổi hội thảo sẽ được tính công trên bảng công.',
    SeminarDecision.unpaid =>
      'Các buổi hội thảo không được cộng công; công từ máy chấm (nếu có) vẫn giữ nguyên.',
    SeminarDecision.reject =>
      'Phiếu chuyển sang "Giám đốc từ chối" và các buổi hội thảo được gỡ khỏi bảng công.',
  };

  @override
  Widget build(BuildContext context) {
    final rejecting = _decision == SeminarDecision.reject;
    final changed = _decision != _current;

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
                      icon: Icons.edit_note_rounded,
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
                              'Sửa quyết định · Giám đốc',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Đổi có công / không công hoặc trạng thái phiếu. Bảng công và chữ ký được cập nhật lại.',
                            style: AppTypography.style(
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
                Text(
                  'Quyết định *',
                  style: AppTypography.style(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                for (final option in const [
                  (
                    SeminarDecision.paid,
                    'Duyệt có công',
                    Icons.check_circle_outline_rounded,
                  ),
                  (
                    SeminarDecision.unpaid,
                    'Duyệt không công',
                    Icons.remove_circle_outline_rounded,
                  ),
                  (SeminarDecision.reject, 'Từ chối', Icons.cancel_outlined),
                ]) ...[
                  _Choice(
                    label: option.$1 == _current
                        ? '${option.$2} (hiện tại)'
                        : option.$2,
                    icon: option.$3,
                    selected: _decision == option.$1,
                    color: switch (option.$1) {
                      SeminarDecision.paid => AppColors.success,
                      SeminarDecision.unpaid => AppColors.warning,
                      SeminarDecision.reject => AppColors.error,
                    },
                    onTap: () => setState(() => _decision = option.$1),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                if (changed) ...[
                  const SizedBox(height: AppSpacing.xs),
                  NoticeBanner(
                    icon: rejecting
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline_rounded,
                    message: _effectMessage,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                if (!rejecting) ...[
                  TextFormField(
                    controller: _supportController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Tiền hỗ trợ (không bắt buộc)',
                      hintText: 'VD: 500.000 đ',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                TextFormField(
                  controller: _commentController,
                  minLines: 2,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: rejecting
                        ? 'Lý do từ chối *'
                        : 'Ý kiến duyệt (không bắt buộc)',
                    hintText: 'Nhập ghi chú để người gửi dễ theo dõi...',
                    prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                    alignLabelWithHint: true,
                  ),
                  validator: rejecting
                      ? (v) => (v == null || v.trim().isEmpty)
                            ? 'Vui lòng nhập lý do từ chối'
                            : null
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                _SheetActions(
                  onCancel: () => Navigator.of(context).pop(),
                  onSubmit: _submit,
                  submitLabel: 'Lưu chỉnh sửa',
                  submitIcon: Icons.save_outlined,
                  submitColor: rejecting ? AppColors.error : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
