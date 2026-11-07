import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/session.dart';
import '../auth/login_screen.dart' show RadarMark;

/// 첫 실행: 1) 언어 → 2) 테마 → 로그인.
/// 선택은 즉시 적용되고 (실시간 미리보기) 기기에 저장된다.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  int _step = 0;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    // 아직 언어를 고르지 않았다면 기기 언어를 미리 선택해 둔다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(localeProvider) != null) return;
      final device = View.of(context).platformDispatcher.locale.languageCode;
      ref.read(localeProvider.notifier).set(Locale(device == 'ko' ? 'ko' : 'en'));
    });
  }

  void _go(int step) => setState(() {
    _forward = step > _step;
    _step = step;
  });

  Future<void> _finish() async {
    await ref.read(setupDoneProvider.notifier).complete();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Motion.of(context, Motion.slow);

    return Scaffold(
      body: DecoratedBox(
        // 위쪽의 부드러운 브랜드 색 → 배경. 차분하고 눈이 편하다.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.45, 1],
            colors: [p.primarySoft, p.background, p.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  const SizedBox(height: Space.xl),
                  const RadarMark(size: 72),
                  const SizedBox(height: Space.lg),
                  _StepDots(count: 2, index: _step),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: d,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) {
                        final incoming = child.key == ValueKey(_step);
                        final dx = (incoming == _forward) ? 0.12 : -0.12;
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: _step == 0
                          ? _LanguageStep(key: const ValueKey(0), onNext: () => _go(1))
                          : _ThemeStep(key: const ValueKey(1), onBack: () => _go(0), onDone: _finish),
                    ),
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

// ─────────────────────────── 1. Til ───────────────────────────

class _LanguageStep extends ConsumerWidget {
  const _LanguageStep({super.key, required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.textStyles;
    final p = context.palette;
    final l10n = context.l10n;
    final current = ref.watch(localeProvider)?.languageCode ?? context.lang;

    void pick(String code) => ref.read(localeProvider.notifier).set(Locale(code));

    return _StepLayout(
      // 아직 언어를 고르지 않음 — 제목을 두 언어로.
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('언어를 선택하세요', style: t.headlineSmall),
          const SizedBox(height: 2),
          Text(
            'Choose your language',
            style: t.titleMedium!.copyWith(color: p.textMuted, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      options: [
        _OptionTile(
          selected: current == 'ko',
          onTap: () => pick('ko'),
          leading: const _Glyph('가', Hue.teal),
          title: '한국어',
          subtitle: 'Korean',
        ),
        _OptionTile(
          selected: current == 'en',
          onTap: () => pick('en'),
          leading: const _Glyph('A', Hue.indigo),
          title: 'English',
          subtitle: '영어',
        ),
      ],
      actions: [FilledButton(onPressed: onNext, child: Text(l10n.next))],
    );
  }
}

// ─────────────────────────── 2. 테마 ───────────────────────────

class _ThemeStep extends ConsumerWidget {
  const _ThemeStep({super.key, required this.onBack, required this.onDone});
  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final mode = ref.watch(themeModeProvider);
    void pick(ThemeMode m) => ref.read(themeModeProvider.notifier).set(m);

    return _StepLayout(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.themeTitle, style: t.headlineSmall),
          const SizedBox(height: 2),
          Text(l10n.themeSubtitle, style: t.bodyMedium!.copyWith(color: p.textMuted)),
        ],
      ),
      options: [
        _OptionTile(
          selected: mode == ThemeMode.system,
          onTap: () => pick(ThemeMode.system),
          leading: const _ThemePreview(mode: ThemeMode.system),
          title: l10n.themeSystem,
          subtitle: l10n.themeSystemDesc,
        ),
        _OptionTile(
          selected: mode == ThemeMode.light,
          onTap: () => pick(ThemeMode.light),
          leading: const _ThemePreview(mode: ThemeMode.light),
          title: l10n.themeLight,
          subtitle: l10n.themeLightDesc,
        ),
        _OptionTile(
          selected: mode == ThemeMode.dark,
          onTap: () => pick(ThemeMode.dark),
          leading: const _ThemePreview(mode: ThemeMode.dark),
          title: l10n.themeDark,
          subtitle: l10n.themeDarkDesc,
        ),
      ],
      actions: [
        OutlinedButton(onPressed: onBack, child: Text(l10n.back)),
        FilledButton(onPressed: onDone, child: Text(l10n.getStarted)),
      ],
    );
  }
}

// ─────────────────────────── 공통 부품 ───────────────────────────

/// 제목 + 선택지 (차례로 등장) + 아래 버튼.
class _StepLayout extends StatelessWidget {
  const _StepLayout({required this.title, required this.options, required this.actions});
  final Widget title;
  final List<Widget> options;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: Space.xxl, bottom: Space.lg),
              children: [
                FadeSlideIn(child: title),
                const SizedBox(height: Space.xxl),
                for (var i = 0; i < options.length; i++) ...[
                  FadeSlideIn(index: i + 1, child: options[i]),
                  const SizedBox(height: Space.md),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xl),
            child: Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: Space.md),
                  Expanded(flex: i == actions.length - 1 ? 2 : 1, child: actions[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final d = Motion.of(context, Motion.fast);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: AnimatedContainer(
            duration: d,
            curve: Motion.curve,
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              color: selected ? p.primarySoft : p.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: selected ? p.primary : p.border, width: selected ? 2 : 1),
              boxShadow: selected
                  ? [BoxShadow(color: p.primary.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6))]
                  : null,
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.titleMedium!.copyWith(color: selected ? p.primary : p.text)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: t.bodySmall),
                    ],
                  ),
                ),
                AnimatedScale(
                  duration: d,
                  curve: Curves.easeOutBack,
                  scale: selected ? 1 : 0,
                  child: Icon(Icons.check_circle_rounded, color: p.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 언어 표시: 색 원 안의 "가" / "A".
class _Glyph extends StatelessWidget {
  const _Glyph(this.text, this.hue);
  final String text;
  final Hue hue;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = hue.of(context);
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(text, style: context.textStyles.titleLarge!.copyWith(color: fg)),
    );
  }
}

/// 작은 휴대폰 화면 목업 — 테마가 어떻게 보이는지 미리 보여준다.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.mode});
  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    Widget screen(AppPalette p) => ColoredBox(
      color: p.background,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 18, height: 4, decoration: _bar(p.text)),
            const SizedBox(height: 5),
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: p.border, width: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Container(height: 10, decoration: _bar(p.primarySoft)),
            const Spacer(),
            Container(height: 6, decoration: _bar(p.primary)),
          ],
        ),
      ),
    );

    final border = context.palette.border;
    return Container(
      width: 48,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: switch (mode) {
        ThemeMode.light => screen(AppPalette.light),
        ThemeMode.dark => screen(AppPalette.dark),
        // 시스템: 반은 밝게, 반은 어둡게.
        ThemeMode.system => Row(
          children: [
            Expanded(
              child: ClipRect(
                child: OverflowBox(alignment: Alignment.centerLeft, maxWidth: 48, child: screen(AppPalette.light)),
              ),
            ),
            Expanded(
              child: ClipRect(
                child: OverflowBox(alignment: Alignment.centerRight, maxWidth: 48, child: screen(AppPalette.dark)),
              ),
            ),
          ],
        ),
      },
    );
  }

  static BoxDecoration _bar(Color c) => BoxDecoration(color: c, borderRadius: BorderRadius.circular(2));
}

/// 단계 표시: 현재 점이 길게.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Motion.of(context, Motion.normal);
    return Semantics(
      label: context.l10n.stepOf(index + 1, count),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: d,
              curve: Motion.curve,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == index ? p.primary : p.textMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
