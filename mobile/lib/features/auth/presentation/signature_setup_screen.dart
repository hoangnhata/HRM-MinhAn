import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../application/auth_controller.dart';

/// Màn hình bắt buộc thiết lập chữ ký lần đầu (vẽ tay) — dùng cho ký duyệt
/// đơn từ / đánh giá trên toàn hệ thống.
class SignatureSetupScreen extends ConsumerStatefulWidget {
  const SignatureSetupScreen({super.key});

  @override
  ConsumerState<SignatureSetupScreen> createState() =>
      _SignatureSetupScreenState();
}

class _SignatureSetupScreenState extends ConsumerState<SignatureSetupScreen> {
  late final SignatureController _controller;
  bool _submitting = false;
  bool _hasStrokes = false;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: AppColors.textPrimary,
      exportBackgroundColor: AppColors.surface,
      onDrawEnd: () {
        if (!_hasStrokes) setState(() => _hasStrokes = true);
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    setState(() => _hasStrokes = false);
  }

  Future<void> _submit() async {
    if (_controller.isEmpty) {
      showAppSnackBar(
        context,
        'Vui lòng ký vào khung trước khi lưu.',
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    final Uint8List? bytes = await _controller.toPngBytes();
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _submitting = false);
      showAppSnackBar(
        context,
        'Không đọc được chữ ký. Vui lòng ký lại.',
        isError: true,
      );
      return;
    }

    final ok = await ref
        .read(authControllerProvider.notifier)
        .submitSignature(bytes);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!ok) {
      showAppSnackBar(
        context,
        ref.read(authControllerProvider).errorMessage ?? 'Lưu chữ ký thất bại',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _SignatureSetupHeader(
            submitting: _submitting,
            onSkip: () =>
                ref.read(authControllerProvider.notifier).skipSignatureForNow(),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final landscape = constraints.maxWidth > constraints.maxHeight;
                final canvasHeight = landscape
                    ? 180.0
                    : (constraints.maxHeight * 0.48)
                          .clamp(220.0, 360.0)
                          .toDouble();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const NoticeBanner(
                            icon: Icons.draw_outlined,
                            color: AppColors.primary,
                            message:
                                'Chữ ký của bạn sẽ được chèn tự động khi ký duyệt phiếu và đơn từ trong hệ thống.',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Semantics(
                            container: true,
                            label: _hasStrokes
                                ? 'Khung chữ ký đã có nét vẽ'
                                : 'Khung chữ ký đang trống',
                            hint: 'Ký bằng ngón tay hoặc bút cảm ứng',
                            child: Container(
                              height: canvasHeight,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadius.brMd,
                                border: Border.all(
                                  color: _hasStrokes
                                      ? AppColors.primary.withValues(alpha: 0.5)
                                      : AppColors.border,
                                  width: _hasStrokes ? 1.5 : 1,
                                ),
                                boxShadow: AppShadows.soft,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Signature(
                                    controller: _controller,
                                    backgroundColor: AppColors.surface,
                                  ),
                                  if (!_hasStrokes)
                                    IgnorePointer(
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.gesture_rounded,
                                              size: 34,
                                              color: AppColors.textTertiary,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Ký tên của bạn vào đây',
                                              textAlign: TextAlign.center,
                                              style: AppTypography.caption(
                                                color: AppColors.textTertiary,
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
                          const SizedBox(height: AppSpacing.md),
                          _SignatureSetupActions(
                            hasStrokes: _hasStrokes,
                            submitting: _submitting,
                            onClear: _clear,
                            onSave: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SignatureSetupHeader extends StatelessWidget {
  const _SignatureSetupHeader({required this.submitting, required this.onSkip});

  final bool submitting;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final stackAction =
        MediaQuery.sizeOf(context).width < 380 || textScale > 1.25;

    final skipButton = TextButton(
      onPressed: submitting ? null : onSkip,
      style: TextButton.styleFrom(
        foregroundColor: onBrand,
        disabledForegroundColor: onBrand.withValues(alpha: 0.5),
        backgroundColor: onBrand.withValues(alpha: 0.14),
        minimumSize: const Size(0, 48),
      ),
      child: const Text('Bỏ qua'),
    );

    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: onBrand.withValues(alpha: 0.14),
                  borderRadius: AppRadius.brSm,
                ),
                child: ExcludeSemantics(
                  child: Icon(Icons.draw_outlined, color: onBrand, size: 21),
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
                        'Thiết lập chữ ký',
                        style: AppTypography.pageTitle(color: onBrand),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ký một lần, dùng cho mọi phiếu và đơn từ về sau.',
                      style: AppTypography.body(
                        fontSize: 12.5,
                        color: onBrand.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              if (!stackAction) ...[
                const SizedBox(width: AppSpacing.sm),
                skipButton,
              ],
            ],
          ),
          if (stackAction) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(alignment: Alignment.centerRight, child: skipButton),
          ],
        ],
      ),
    );
  }
}

class _SignatureSetupActions extends StatelessWidget {
  const _SignatureSetupActions({
    required this.hasStrokes,
    required this.submitting,
    required this.onClear,
    required this.onSave,
  });

  final bool hasStrokes;
  final bool submitting;
  final VoidCallback onClear;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
        final stacked = constraints.maxWidth < 340 || textScale > 1.25;
        const gap = AppSpacing.sm;
        final clearWidth = stacked
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / 3;
        final saveWidth = stacked
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) * 2 / 3;

        return Wrap(
          spacing: gap,
          runSpacing: AppSpacing.xs,
          children: [
            SizedBox(
              width: clearWidth,
              child: OutlinedButton.icon(
                onPressed: (submitting || !hasStrokes) ? null : onClear,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Ký lại'),
              ),
            ),
            Semantics(
              liveRegion: submitting,
              label: submitting ? 'Đang lưu chữ ký' : null,
              child: SizedBox(
                width: saveWidth,
                child: ElevatedButton.icon(
                  onPressed: submitting ? null : onSave,
                  icon: submitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Theme.of(context).colorScheme.onPrimary,
                            strokeCap: StrokeCap.round,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 19),
                  label: Text(submitting ? 'Đang lưu...' : 'Lưu chữ ký'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
