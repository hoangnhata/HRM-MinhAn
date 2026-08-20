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
                            offset: Offset(0, compact ? -18 : -28),
                            child: _FadeSlide(
                              controller: _entrance,
                              start: 0.18,
                              child: _LoginCard(
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
                                : AppSpacing.md,
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
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
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
    final logoSize = compact ? 72.0 : 92.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(compact ? AppRadius.lg : AppRadius.xl),
          bottomRight: Radius.circular(compact ? AppRadius.lg : AppRadius.xl),
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
            top: -48,
            right: -36,
            child: _HeroOrb(size: 160, alpha: 0.10),
          ),
          Positioned(
            bottom: -56,
            left: -44,
            child: _HeroOrb(size: 180, alpha: 0.07),
          ),
          Positioned(
            top: 48,
            left: 28,
            child: _HeroOrb(size: 56, alpha: 0.08),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              topInset + (compact ? AppSpacing.md : AppSpacing.xl),
              AppSpacing.xl,
              compact ? 44 : 56,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BrandMark(
                    size: logoSize,
                    backgroundColor: Colors.white,
                    showShadow: true,
                  ),
                  SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
                  Semantics(
                    header: true,
                    child: Text(
                      'Bệnh viện Minh An',
                      textAlign: TextAlign.center,
                      style: AppTypography.style(
                        color: onBrand,
                        fontSize: compact ? 22 : 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hệ thống quản trị nhân sự',
                    textAlign: TextAlign.center,
                    style: AppTypography.style(
                      color: onBrand.withValues(alpha: 0.88),
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                      height: 1.4,
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
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.obscure,
    required this.submitting,
    required this.errorMessage,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscure;
  final bool submitting;
  final String? errorMessage;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

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
              borderRadius: AppRadius.brLg,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.10),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
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
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: AppRadius.brSm,
                            ),
                            child: const Icon(
                              Icons.lock_person_rounded,
                              color: AppColors.primary,
                              size: 22,
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
                                    'Đăng nhập',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tài khoản HRM nội bộ',
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
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Nhập tên đăng nhập hoặc số điện thoại để tiếp tục.',
                        style: AppTypography.body(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        NoticeBanner.error(
                          title: 'Không thể đăng nhập',
                          message: errorMessage!,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      TextFormField(
                        controller: usernameController,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        enabled: !submitting,
                        decoration: InputDecoration(
                          labelText: 'Tên đăng nhập hoặc SĐT',
                          hintText: 'VD: 09xxxxxxxx',
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceMuted,
                        ),
                        validator: (v) =>
                            Validators.required(v, label: 'Tên đăng nhập'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        enabled: !submitting,
                        onFieldSubmitted: (_) => onSubmit(),
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          filled: true,
                          fillColor: AppColors.surfaceMuted,
                          suffixIcon: IconButton(
                            tooltip:
                                obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: submitting ? null : onToggleObscure,
                          ),
                        ),
                        validator: (v) =>
                            Validators.required(v, label: 'Mật khẩu'),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Semantics(
                        liveRegion: submitting,
                        label: submitting ? 'Đang đăng nhập' : null,
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.brControl,
                              boxShadow: submitting ? null : AppShadows.button,
                              gradient: submitting
                                  ? null
                                  : AppGradients.brandSoft,
                            ),
                            child: ElevatedButton(
                              onPressed: submitting ? null : onSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: submitting
                                    ? AppColors.primary.withValues(alpha: 0.55)
                                    : Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.white
                                    .withValues(alpha: 0.9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.brControl,
                                ),
                              ),
                              child: submitting
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                            strokeCap: StrokeCap.round,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Text(
                                          'Đang đăng nhập...',
                                          style: AppTypography.style(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.login_rounded,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Đăng nhập',
                                          style: AppTypography.style(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Divider(height: 1, color: AppColors.borderSoft),
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        label:
                            'Quên mật khẩu, liên hệ phòng Hành chính Nhân sự',
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHigh,
                                borderRadius: AppRadius.brXs,
                              ),
                              child: const Icon(
                                Icons.support_agent_rounded,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Quên mật khẩu? Liên hệ phòng Hành chính - Nhân sự.',
                                style: AppTypography.caption(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
      curve: Interval(start, (start + 0.55).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
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
