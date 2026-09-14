import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/notice_banner.dart';
import '../application/auth_controller.dart';

/// Màn đăng nhập — hero brand + form trắng, nền khí quyển nhẹ.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _errorMessage;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
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
        .login(_usernameController.text.trim(), _passwordController.text);
    if (!mounted) return;
    final error = ok
        ? null
        : ref.read(authControllerProvider).errorMessage ?? 'Đăng nhập thất bại';
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const Positioned.fill(child: _AmbientBackground()),
            SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxHeight < 620 || bottomInset > 80;

                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        children: [
                          _FadeSlide(
                            controller: _entrance,
                            start: 0,
                            child: _BrandHero(
                              topInset: topInset,
                              compact: compact,
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(0, compact ? -26 : -38),
                            child: _FadeSlide(
                              controller: _entrance,
                              start: 0.18,
                              child: _LoginCard(
                                compact: compact,
                                formKey: _formKey,
                                usernameController: _usernameController,
                                passwordController: _passwordController,
                                obscure: _obscure,
                                submitting: _submitting,
                                errorMessage: _errorMessage,
                                onToggleObscure: () =>
                                    setState(() => _obscure = !_obscure),
                                onSubmit: _submit,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: bottomInset > 0
                                ? AppSpacing.sm
                                : AppSpacing.xl,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.background,
            AppColors.surfaceAlt,
          ],
          stops: const [0.0, 0.42, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _GlowOrb(
              size: 220,
              color: AppColors.primaryLight.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -70,
            child: _GlowOrb(
              size: 200,
              color: AppColors.primary.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -40,
            child: _GlowOrb(
              size: 140,
              color: AppColors.secondary.withValues(alpha: 0.07),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero({required this.topInset, required this.compact});

  final double topInset;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final logoSize = compact ? 66.0 : 78.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(compact ? 26 : 34),
          bottomRight: Radius.circular(compact ? 26 : 34),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: -72,
            right: -48,
            child: _HeroOrb(size: 210, alpha: 0.10),
          ),
          Positioned(
            bottom: -72,
            left: -52,
            child: _HeroOrb(size: 210, alpha: 0.08),
          ),
          Positioned(top: 34, left: 28, child: _HeroOrb(size: 52, alpha: 0.09)),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              topInset + (compact ? AppSpacing.sm : AppSpacing.lg),
              AppSpacing.xl,
              compact ? 54 : 72,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: logoSize + 14,
                    height: logoSize + 14,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.34),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: AppColors.secondaryLight.withValues(
                            alpha: 0.18,
                          ),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: BrandMark(
                      size: logoSize,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      'Bệnh viện Minh An',
                      textAlign: TextAlign.center,
                      style: AppTypography.style(
                        color: onBrand,
                        fontSize: compact ? 22 : 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Hệ thống quản trị nhân sự',
                    textAlign: TextAlign.center,
                    style: AppTypography.style(
                      color: onBrand.withValues(alpha: 0.88),
                      fontSize: compact ? 12.5 : 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.05,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 13),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: AppRadius.brPill,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 14,
                          color: onBrand.withValues(alpha: 0.92),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'CỔNG NHÂN SỰ NỘI BỘ',
                          style: AppTypography.style(
                            color: onBrand.withValues(alpha: 0.9),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroOrb extends StatelessWidget {
  const _HeroOrb({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: alpha),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.compact,
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.obscure,
    required this.submitting,
    required this.errorMessage,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  final bool compact;
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscure;
  final bool submitting;
  final String? errorMessage;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.style(
        color: AppColors.textTertiary,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, size: 20),
      prefixIconColor: AppColors.primary,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.brMd,
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.brMd,
        borderSide: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.16),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.brMd,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.7),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.brMd,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.brMd,
        borderSide: const BorderSide(color: AppColors.error, width: 1.7),
      ),
      errorMaxLines: 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.brXl,
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.14),
                  blurRadius: 38,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8),
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 30,
                  right: 30,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: AppGradients.brandSoft,
                      borderRadius: AppRadius.brPill,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? AppSpacing.md : AppSpacing.lg,
                    compact ? AppSpacing.lg : AppSpacing.xl,
                    compact ? AppSpacing.md : AppSpacing.lg,
                    compact ? AppSpacing.md : AppSpacing.lg,
                  ),
                  child: AutofillGroup(
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: AppGradients.brandSoft,
                                  borderRadius: AppRadius.brMd,
                                  boxShadow: AppShadows.tinted(
                                    AppColors.primary,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: Colors.white,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Semantics(
                                      header: true,
                                      child: Text(
                                        'Đăng nhập hệ thống',
                                        style: AppTypography.style(
                                          color: AppColors.textPrimary,
                                          fontSize: compact ? 19 : 20.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.45,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Sử dụng tài khoản HRM nội bộ',
                                      style: AppTypography.caption(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (errorMessage != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            NoticeBanner.error(
                              title: 'Không thể đăng nhập',
                              message: errorMessage!,
                            ),
                          ],
                          SizedBox(height: compact ? 16 : 22),
                          const _LoginFieldLabel(
                            icon: Icons.person_outline_rounded,
                            label: 'Tên đăng nhập hoặc số điện thoại',
                          ),
                          const SizedBox(height: 7),
                          TextFormField(
                            controller: usernameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            enabled: !submitting,
                            autocorrect: false,
                            decoration: _inputDecoration(
                              hintText: 'Nhập tên đăng nhập hoặc SĐT',
                              icon: Icons.person_outline_rounded,
                            ),
                            style: AppTypography.style(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            validator: (v) =>
                                Validators.required(v, label: 'Tên đăng nhập'),
                          ),
                          SizedBox(height: compact ? 13 : AppSpacing.md),
                          const _LoginFieldLabel(
                            icon: Icons.key_rounded,
                            label: 'Mật khẩu',
                          ),
                          const SizedBox(height: 7),
                          TextFormField(
                            controller: passwordController,
                            obscureText: obscure,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            enabled: !submitting,
                            autocorrect: false,
                            enableSuggestions: false,
                            onFieldSubmitted: (_) => onSubmit(),
                            decoration: _inputDecoration(
                              hintText: 'Nhập mật khẩu',
                              icon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                tooltip: obscure
                                    ? 'Hiện mật khẩu'
                                    : 'Ẩn mật khẩu',
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                color: AppColors.textSecondary,
                                onPressed: submitting ? null : onToggleObscure,
                              ),
                            ),
                            style: AppTypography.style(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: obscure ? 1.1 : 0,
                            ),
                            validator: (v) =>
                                Validators.required(v, label: 'Mật khẩu'),
                          ),
                          SizedBox(height: compact ? 18 : AppSpacing.xl),
                          Semantics(
                            liveRegion: submitting,
                            label: submitting ? 'Đang đăng nhập' : null,
                            child: SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: submitting
                                      ? AppColors.primaryLight
                                      : null,
                                  gradient: submitting
                                      ? null
                                      : AppGradients.brand,
                                  borderRadius: AppRadius.brMd,
                                  boxShadow: submitting
                                      ? null
                                      : AppShadows.button,
                                ),
                                child: ElevatedButton(
                                  onPressed: submitting ? null : onSubmit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    disabledBackgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                    foregroundColor: Colors.white,
                                    disabledForegroundColor: Colors.white
                                        .withValues(alpha: 0.9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: AppRadius.brMd,
                                    ),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: AppDurations.fast,
                                    child: submitting
                                        ? Row(
                                            key: const ValueKey('loading'),
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 19,
                                                height: 19,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.2,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.onPrimary,
                                                      strokeCap:
                                                          StrokeCap.round,
                                                    ),
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.sm,
                                              ),
                                              Text(
                                                'Đang xác thực...',
                                                style: AppTypography.style(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            key: const ValueKey('ready'),
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Đăng nhập an toàn',
                                                style: AppTypography.style(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  letterSpacing: -0.15,
                                                ),
                                              ),
                                              const SizedBox(width: 9),
                                              const Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: compact ? 14 : AppSpacing.lg),
                          Semantics(
                            label:
                                'Quên mật khẩu, liên hệ phòng Hành chính Nhân sự',
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.055,
                                ),
                                borderRadius: AppRadius.brMd,
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.11,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: AppRadius.brSm,
                                    ),
                                    child: const Icon(
                                      Icons.support_agent_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Bạn quên mật khẩu?',
                                          style: AppTypography.style(
                                            color: AppColors.textPrimary,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Liên hệ phòng Hành chính – Nhân sự',
                                          style: AppTypography.caption(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.lock_rounded,
                                size: 13,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Kết nối bảo mật  •  Dữ liệu nội bộ',
                                style: AppTypography.style(
                                  color: AppColors.textTertiary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

class _LoginFieldLabel extends StatelessWidget {
  const _LoginFieldLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.style(
            color: AppColors.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FadeSlide extends StatelessWidget {
  const _FadeSlide({
    required this.controller,
    required this.child,
    this.start = 0,
  });

  final AnimationController controller;
  final Widget child;
  final double start;

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(
        start,
        (start + 0.55).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }
}
