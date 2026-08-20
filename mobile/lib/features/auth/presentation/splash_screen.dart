import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';

/// Màn mở app — brand + load chuyên nghiệp (không dùng splash logo native).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  static const _statusMessages = [
    'Đang khởi tạo…',
    'Đang tải cấu hình…',
    'Chuẩn bị không gian làm việc…',
  ];
  int _statusIndex = 0;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (!mounted) return;
      setState(() {
        _statusIndex = (_statusIndex + 1) % _statusMessages.length;
      });
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _entrance.dispose();
    _pulse.dispose();
    _progress.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end) {
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logoFade = _interval(0.0, 0.4);
    final logoScale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    final titleFade = _interval(0.22, 0.58);
    final titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(titleFade);
    final metaFade = _interval(0.38, 0.72);
    final loaderFade = _interval(0.52, 0.9);
    final pulse = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.primaryDark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppGradients.brand),
            ),
            Positioned(
              top: -140,
              left: -80,
              child: _GlowOrb(
                size: 320,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Positioned(
              bottom: -120,
              right: -60,
              child: _GlowOrb(
                size: 280,
                color: AppColors.secondary.withValues(alpha: 0.14),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 28,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: metaFade,
                child: Text(
                  'MINH AN HRM',
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: logoFade,
                      child: ScaleTransition(
                        scale: logoScale,
                        child: _HospitalLogoBadge(
                          glow: pulse,
                          shimmer: _progress,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: titleFade,
                      child: SlideTransition(
                        position: titleSlide,
                        child: Text(
                          'Bệnh viện Minh An',
                          textAlign: TextAlign.center,
                          style: AppTypography.style(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeTransition(
                      opacity: metaFade,
                      child: Text(
                        'Hệ thống quản trị nhân sự',
                        textAlign: TextAlign.center,
                        style: AppTypography.style(
                          color: Colors.white.withValues(alpha: 0.84),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FadeTransition(
                      opacity: metaFade,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: AppRadius.brPill,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.secondaryLight,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.secondaryLight
                                        .withValues(alpha: 0.55),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'HRM',
                              style: AppTypography.style(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    FadeTransition(
                      opacity: loaderFade,
                      child: _SplashLoader(
                        progress: _progress,
                        status: _statusMessages[_statusIndex],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: MediaQuery.paddingOf(context).bottom + 20,
              child: FadeTransition(
                opacity: loaderFade,
                child: Text(
                  'An toàn · Bảo mật · Đồng bộ web',
                  textAlign: TextAlign.center,
                  style: AppTypography.style(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
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

class _HospitalLogoBadge extends StatelessWidget {
  const _HospitalLogoBadge({
    required this.glow,
    required this.shimmer,
  });

  final Animation<double> glow;
  final Animation<double> shimmer;

  static const _outer = 220.0;
  static const _emblem = 168.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([glow, shimmer]),
      builder: (context, _) {
        final breathe = glow.value;
        final spin = shimmer.value * math.pi * 2;
        final haloSize = _outer + breathe * 10;

        return SizedBox(
          width: _outer,
          height: _outer,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: haloSize,
                height: haloSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.16 + breathe * 0.1),
                      AppColors.secondaryLight.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              Transform.rotate(
                angle: spin,
                child: CustomPaint(
                  size: const Size(_outer - 8, _outer - 8),
                  painter: _LogoAuraRingPainter(
                    accent: AppColors.secondaryLight,
                    progress: shimmer.value,
                  ),
                ),
              ),
              Transform.rotate(
                angle: -spin * 0.65,
                child: CustomPaint(
                  size: const Size(_outer - 20, _outer - 20),
                  painter: _LogoAuraRingPainter(
                    accent: Colors.white,
                    progress: 1 - shimmer.value,
                    strokeWidth: 1.4,
                    arcSweep: math.pi * 0.55,
                    opacity: 0.35,
                  ),
                ),
              ),
              Container(
                width: _emblem + 6,
                height: _emblem + 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22 + breathe * 0.12),
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                    BoxShadow(
                      color: AppColors.secondaryLight.withValues(
                        alpha: 0.18 + breathe * 0.12,
                      ),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              ClipOval(
                child: Image.asset(
                  'assets/images/logo_hd.png',
                  width: _emblem,
                  height: _emblem,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                  gaplessPlayback: true,
                  semanticLabel: 'Logo Bệnh viện Minh An',
                ),
              ),
              IgnorePointer(
                child: Container(
                  width: _emblem,
                  height: _emblem,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.28, 0.72],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LogoAuraRingPainter extends CustomPainter {
  _LogoAuraRingPainter({
    required this.accent,
    required this.progress,
    this.strokeWidth = 2.2,
    this.arcSweep = math.pi * 0.72,
    this.opacity = 0.75,
  });

  final Color accent;
  final double progress;
  final double strokeWidth;
  final double arcSweep;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - strokeWidth;
    final start = -math.pi / 2 + progress * math.pi * 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + arcSweep,
        colors: [
          accent.withValues(alpha: 0),
          accent.withValues(alpha: opacity),
          accent.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(start),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      arcSweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoAuraRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.opacity != opacity;
  }
}

class _SplashLoader extends StatelessWidget {
  const _SplashLoader({
    required this.progress,
    required this.status,
  });

  final Animation<double> progress;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 220,
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              final t = Curves.easeInOut.transform((progress.value * 2) % 1.0);
              return ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment(-1.0 + t * 2.0, 0),
                        widthFactor: 0.38,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.05),
                                Colors.white,
                                AppColors.secondaryLight,
                                Colors.white.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: AppDurations.normal,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Text(
            status,
            key: ValueKey(status),
            style: AppTypography.style(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
