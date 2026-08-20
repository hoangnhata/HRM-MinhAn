import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../auth/application/auth_controller.dart';

/// Đổi mật khẩu tự nguyện (khác màn hình bắt buộc lúc đăng nhập lần đầu).
class ProfileChangePasswordScreen extends ConsumerStatefulWidget {
  const ProfileChangePasswordScreen({super.key});

  @override
  ConsumerState<ProfileChangePasswordScreen> createState() =>
      _ProfileChangePasswordScreenState();
}

class _ProfileChangePasswordScreenState
    extends ConsumerState<ProfileChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final ok = await ref
        .read(authControllerProvider.notifier)
        .changePassword(_currentController.text, _newController.text);
    if (!mounted) return;
    final error = ok
        ? null
        : ref.read(authControllerProvider).errorMessage ??
              'Đổi mật khẩu thất bại';
    setState(() {
      _submitting = false;
      _errorMessage = error;
    });

    if (ok) {
      showAppSnackBar(context, 'Đã đổi mật khẩu thành công', isSuccess: true);
      Navigator.of(context).maybePop();
    } else {
      showAppSnackBar(context, error!, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = _PasswordStrength.of(_newController.text);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GradientAppBar(title: 'Đổi mật khẩu'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    const NoticeBanner(
                      icon: Icons.shield_outlined,
                      message:
                          'Mật khẩu tối thiểu 6 ký tự. Nên kết hợp chữ, số và ký tự đặc biệt để bảo mật hơn.',
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      NoticeBanner.error(
                        title: 'Chưa thể đổi mật khẩu',
                        message: _errorMessage!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: AppCard(
                  child: Column(
                    children: [
                      const AppSectionTitle(
                        title: 'Cập nhật thông tin bảo mật',
                        icon: Icons.security_rounded,
                        padding: EdgeInsets.only(bottom: AppSpacing.md),
                      ),
                      TextFormField(
                        controller: _currentController,
                        obscureText: _obscureCurrent,
                        enabled: !_submitting,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu hiện tại',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: _VisibilityToggle(
                            obscured: _obscureCurrent,
                            onToggle: _submitting
                                ? null
                                : () => setState(
                                    () => _obscureCurrent = !_obscureCurrent,
                                  ),
                          ),
                        ),
                        validator: (v) =>
                            Validators.required(v, label: 'Mật khẩu hiện tại'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _newController,
                        obscureText: _obscureNew,
                        enabled: !_submitting,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          suffixIcon: _VisibilityToggle(
                            obscured: _obscureNew,
                            onToggle: _submitting
                                ? null
                                : () => setState(
                                    () => _obscureNew = !_obscureNew,
                                  ),
                          ),
                        ),
                        validator: Validators.combine([
                          (v) => Validators.required(v, label: 'Mật khẩu mới'),
                          (v) =>
                              Validators.minLength(v, 6, label: 'Mật khẩu mới'),
                        ]),
                      ),
                      if (_newController.text.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Semantics(
                          liveRegion: true,
                          label: 'Độ mạnh mật khẩu: ${strength.label}',
                          child: ExcludeSemantics(
                            child: Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: AppRadius.brPill,
                                    child: LinearProgressIndicator(
                                      value: strength.ratio,
                                      minHeight: 4,
                                      backgroundColor: AppColors.surfaceMuted,
                                      valueColor: AlwaysStoppedAnimation(
                                        strength.color,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  strength.label,
                                  style: AppTypography.caption(
                                    color: strength.color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscureConfirm,
                        enabled: !_submitting,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu mới',
                          prefixIcon: const Icon(
                            Icons.check_circle_outline_rounded,
                          ),
                          suffixIcon: _VisibilityToggle(
                            obscured: _obscureConfirm,
                            onToggle: _submitting
                                ? null
                                : () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                          ),
                        ),
                        validator: (v) => v != _newController.text
                            ? 'Mật khẩu xác nhận không khớp'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Semantics(
                  liveRegion: _submitting,
                  label: _submitting ? 'Đang đổi mật khẩu' : null,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Theme.of(context).colorScheme.onPrimary,
                                strokeCap: StrokeCap.round,
                              ),
                            )
                          : const Icon(Icons.lock_reset_rounded, size: 19),
                      label: Text(
                        _submitting ? 'Đang xử lý...' : 'Xác nhận đổi mật khẩu',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({required this.obscured, required this.onToggle});

  final bool obscured;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onToggle,
      tooltip: obscured ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: AppColors.textTertiary,
      ),
    );
  }
}

/// Đánh giá nhanh độ mạnh mật khẩu để người dùng có phản hồi tức thì.
class _PasswordStrength {
  const _PasswordStrength(this.ratio, this.label, this.color);

  final double ratio;
  final String label;
  final Color color;

  static _PasswordStrength of(String value) {
    var score = 0;
    if (value.length >= 6) score++;
    if (value.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(value)) score++;
    if (RegExp(r'[^\w\s]').hasMatch(value)) score++;

    if (score <= 2) {
      return const _PasswordStrength(0.33, 'Yếu', AppColors.error);
    }
    if (score <= 3) {
      return const _PasswordStrength(0.66, 'Trung bình', AppColors.warning);
    }
    return const _PasswordStrength(1, 'Mạnh', AppColors.success);
  }
}
