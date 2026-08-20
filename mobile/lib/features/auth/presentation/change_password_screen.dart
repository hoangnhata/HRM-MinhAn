import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../application/auth_controller.dart';

/// Màn hình bắt buộc đổi mật khẩu lần đầu — chặn toàn bộ app cho đến khi
/// hoàn tất, đồng bộ với luồng /change-password-required của web.
class ChangePasswordRequiredScreen extends ConsumerStatefulWidget {
  const ChangePasswordRequiredScreen({super.key});

  @override
  ConsumerState<ChangePasswordRequiredScreen> createState() =>
      _ChangePasswordRequiredScreenState();
}

class _ChangePasswordRequiredScreenState
    extends ConsumerState<ChangePasswordRequiredScreen> {
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

    if (!ok) {
      showAppSnackBar(context, error!, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          const AppScreenHeader(
            eyebrow: 'Bảo mật tài khoản',
            title: 'Đổi mật khẩu',
            icon: Icons.lock_reset_rounded,
            subtitle: 'Bước bắt buộc để bảo vệ tài khoản của bạn.',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.page),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      const NoticeBanner.warning(
                        message:
                            'Vì lý do an toàn, bạn cần đổi mật khẩu mặc định trước khi tiếp tục sử dụng ứng dụng.',
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        NoticeBanner.error(
                          title: 'Chưa thể đổi mật khẩu',
                          message: _errorMessage!,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              const AppSectionTitle(
                                title: 'Tạo mật khẩu mới',
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
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: _obscureCurrent
                                        ? 'Hiện mật khẩu hiện tại'
                                        : 'Ẩn mật khẩu hiện tại',
                                    icon: Icon(
                                      _obscureCurrent
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                    ),
                                    onPressed: _submitting
                                        ? null
                                        : () => setState(
                                            () => _obscureCurrent =
                                                !_obscureCurrent,
                                          ),
                                  ),
                                ),
                                validator: (v) => Validators.required(
                                  v,
                                  label: 'Mật khẩu hiện tại',
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _newController,
                                obscureText: _obscureNew,
                                enabled: !_submitting,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Mật khẩu mới',
                                  helperText: 'Tối thiểu 6 ký tự',
                                  prefixIcon: const Icon(
                                    Icons.password_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: _obscureNew
                                        ? 'Hiện mật khẩu mới'
                                        : 'Ẩn mật khẩu mới',
                                    icon: Icon(
                                      _obscureNew
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                    ),
                                    onPressed: _submitting
                                        ? null
                                        : () => setState(
                                            () => _obscureNew = !_obscureNew,
                                          ),
                                  ),
                                ),
                                validator: Validators.combine([
                                  (v) => Validators.required(
                                    v,
                                    label: 'Mật khẩu mới',
                                  ),
                                  (v) => Validators.minLength(
                                    v,
                                    6,
                                    label: 'Mật khẩu mới',
                                  ),
                                ]),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _confirmController,
                                obscureText: _obscureConfirm,
                                enabled: !_submitting,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Xác nhận mật khẩu mới',
                                  prefixIcon: const Icon(Icons.check_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _obscureConfirm
                                        ? 'Hiện mật khẩu xác nhận'
                                        : 'Ẩn mật khẩu xác nhận',
                                    onPressed: _submitting
                                        ? null
                                        : () => setState(
                                            () => _obscureConfirm =
                                                !_obscureConfirm,
                                          ),
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                validator: (v) => v != _newController.text
                                    ? 'Mật khẩu xác nhận không khớp'
                                    : null,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Semantics(
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
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                              strokeCap: StrokeCap.round,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.lock_reset_rounded,
                                            size: 19,
                                          ),
                                    label: Text(
                                      _submitting
                                          ? 'Đang xử lý...'
                                          : 'Xác nhận đổi mật khẩu',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}
