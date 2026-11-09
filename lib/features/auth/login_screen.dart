import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../core/widgets.dart';
import '../../data/calendar_controller.dart';
import '../../data/session.dart';
import 'google_button.dart';

/// 로그인 / 가입. Google 계정 = 가입 (별도 양식 없음).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(sessionProvider.notifier).listenForGoogle(_next, (e) {
      if (mounted) Toast.show(context.l10n.loginError, type: ToastType.error);
    });
  }

  void _next() {
    if (!mounted) return;
    context.go(nextAfterAuthOf(ref)); // 이름 → 관심사 → 홈
  }

  Future<void> _guest() async {
    await ref.read(sessionProvider.notifier).continueAsGuest();
    _next();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final lang = context.lang;

    return Scaffold(
      body: Stack(
        children: [
          // 천천히 떠다니는 색 번짐 — 생동감 있지만 글자보다 눈에 띄지 않는다.
          const Positioned.fill(child: _Aurora()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: Space.xxxl),

                          // ── 브랜드 ──
                          const FadeSlideIn(child: Center(child: _GlowingRadar(size: 104))),
                          const SizedBox(height: Space.xl),
                          FadeSlideIn(
                            index: 1,
                            child: Center(
                              child: _GradientText(
                                l10n.appTitle,
                                style: t.headlineMedium!.copyWith(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.sm),
                          FadeSlideIn(
                            index: 2,
                            child: Text(
                              l10n.onboardingTagline,
                              textAlign: TextAlign.center,
                              style: t.bodyLarge!.copyWith(color: p.textMuted, height: 1.5),
                            ),
                          ),
                          const SizedBox(height: Space.xxl),

                          // ── 장점 ──
                          FadeSlideIn(
                            index: 3,
                            child: _GlassCard(
                              child: Column(
                                children: [
                                  _Feature(Icons.hub_outlined, Hue.teal, l10n.loginF1Title, l10n.loginF1Body),
                                  _divider(p),
                                  _Feature(Icons.alt_route_rounded, Hue.indigo, l10n.loginF2Title, l10n.loginF2Body),
                                  _divider(p),
                                  _Feature(Icons.auto_awesome_outlined, Hue.amber, l10n.loginF3Title, l10n.loginF3Body),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.xxl),

                          // ── 행동 ──
                          FadeSlideIn(
                            index: 4,
                            child: _GlassCard(
                              padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(l10n.loginPanelTitle, style: t.titleLarge),
                                  const SizedBox(height: Space.xs),
                                  Text(l10n.loginPanelBody, style: t.bodySmall),
                                  const SizedBox(height: Space.lg),
                                  if (isGoogleSignInConfigured) ...[
                                    Center(
                                      child: googleSignInButton(
                                        context,
                                        languageCode: lang,
                                        width: math.min(c.maxWidth - 2 * Space.xl - 2 * Space.xl, 400),
                                      ),
                                    ),
                                    const SizedBox(height: Space.lg),
                                    Row(
                                      children: [
                                        Expanded(child: Divider(color: p.border)),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: Space.md),
                                          child: Text(l10n.or, style: t.labelMedium),
                                        ),
                                        Expanded(child: Divider(color: p.border)),
                                      ],
                                    ),
                                    const SizedBox(height: Space.lg),
                                  ],
                                  _GuestButton(label: l10n.continueAsGuest, onPressed: _guest),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.lg),
                          FadeSlideIn(
                            index: 5,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_outline_rounded, size: 14, color: p.textMuted),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(l10n.loginPrivacy, textAlign: TextAlign.center, style: t.bodySmall),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Space.xxl),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _divider(AppPalette p) => Padding(
    padding: const EdgeInsets.only(left: 56),
    child: Divider(height: 1, color: p.border),
  );
}

/// 반투명 "유리" 카드: 오로라 배경 위에서 부드럽게 구분된다.
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: dark ? 0.72 : 0.82),
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: p.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : p.primary).withValues(alpha: dark ? 0.35 : 0.08),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.hue, this.title, this.body);
  final IconData icon;
  final Hue hue;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final (fg, bg) = hue.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.md)),
            child: Icon(icon, color: fg, size: 22),
          ),
          const SizedBox(width: Space.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: t.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 게스트 버튼: 부드러운 브랜드 배경, 아이콘과 화살표 — 누르면 살짝 "눌림".
class _GuestButton extends StatefulWidget {
  const _GuestButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  State<_GuestButton> createState() => _GuestButtonState();
}

class _GuestButtonState extends State<_GuestButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return AnimatedScale(
      duration: Motion.of(context, Motion.fast),
      scale: _down ? 0.97 : 1,
      child: Material(
        color: p.primarySoft,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: widget.onPressed,
          onHighlightChanged: (v) => setState(() => _down = v),
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: p.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.explore_outlined, color: p.primary, size: 22),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(widget.label, style: t.labelLarge!.copyWith(color: p.primary)),
                ),
                Icon(Icons.arrow_forward_rounded, color: p.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 그라데이션 브랜드 이름 (blurple → violet).
class _GradientText extends StatelessWidget {
  const _GradientText(this.text, {required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(colors: [p.primary, p.primaryAlt]).createShader(r),
      child: Text(text, style: style),
    );
  }
}

/// 레이더 + 주변의 천천히 "숨 쉬는" 빛 고리.
class _GlowingRadar extends StatefulWidget {
  const _GlowingRadar({required this.size});
  final double size;

  @override
  State<_GlowingRadar> createState() => _GlowingRadarState();
}

class _GlowingRadarState extends State<_GlowingRadar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = Curves.easeInOut.transform(_c.value);
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: p.primary.withValues(alpha: 0.10 + 0.14 * v),
                blurRadius: 24 + 22 * v,
                spreadRadius: 2 + 6 * v,
              ),
            ],
          ),
          child: child,
        );
      },
      child: RadarMark(size: widget.size),
    );
  }
}

/// 배경: 크고 부드러운 원형 번짐 3개가 천천히 돌며 떠다닌다. 동작 줄이기에서는 정적.
class _Aurora extends StatefulWidget {
  const _Aurora();

  @override
  State<_Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<_Aurora> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 0.2;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (sky, _) = Hue.sky.of(context);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _AuroraPainter(
            t: _c.value,
            background: p.background,
            // 은은하게: 다크에서도 눈부시지 않도록 낮은 투명도.
            blobs: [(p.primary, dark ? 0.20 : 0.18), (p.primaryAlt, dark ? 0.14 : 0.12), (sky, dark ? 0.08 : 0.08)],
          ),
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.t, required this.background, required this.blobs});
  final double t;
  final Color background;
  final List<(Color, double)> blobs;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final w = size.width, h = size.height;
    final a = t * 2 * math.pi;
    // 각 번짐은 자기 중심을 기준으로 서로 다른 위상과 반지름으로 돈다 (위쪽 절반에 더 많이).
    final centers = [
      Offset(w * 0.15 + math.cos(a) * w * 0.12, h * 0.12 + math.sin(a) * h * 0.05),
      Offset(w * 0.90 + math.cos(a + 2.1) * w * 0.10, h * 0.30 + math.sin(a + 2.1) * h * 0.06),
      Offset(w * 0.45 + math.cos(a + 4.2) * w * 0.15, h * 0.62 + math.sin(a + 4.2) * h * 0.05),
    ];
    final radius = math.max(w, h) * 0.55;
    for (var i = 0; i < blobs.length; i++) {
      final (color, alpha) = blobs[i];
      final rect = Rect.fromCircle(center: centers[i], radius: radius);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t || old.background != background;
}

/// 브랜드 마크: 동심원 + 천천히 도는 "sweep" + 신호 점.
class RadarMark extends StatefulWidget {
  const RadarMark({super.key, this.size = 96});
  final double size;

  @override
  State<RadarMark> createState() => _RadarMarkState();
}

class _RadarMarkState extends State<RadarMark> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.stop();
      _c.value = 0.15;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(painter: _RadarPainter(_c.value, p.primary, p.primarySoft, p.accent)),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t, this.color, this.soft, this.accent);
  final double t;
  final Color color, soft, accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = soft);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.35);
    for (final f in [0.33, 0.66, 0.97]) {
      canvas.drawCircle(c, r * f, ring);
    }
    final angle = t * 2 * math.pi;
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi / 2,
        colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.35)],
        transform: GradientRotation(angle - math.pi / 2),
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.97), angle - math.pi / 2, math.pi / 2, true, sweep);
    canvas.drawLine(
      c,
      c + Offset(math.cos(angle), math.sin(angle)) * r * 0.97,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(c, 4, Paint()..color = color);
    canvas.drawCircle(c + Offset(r * 0.42, -r * 0.3), 4.5, Paint()..color = accent);
    canvas.drawCircle(c + Offset(-r * 0.5, r * 0.36), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.color != color;
}
