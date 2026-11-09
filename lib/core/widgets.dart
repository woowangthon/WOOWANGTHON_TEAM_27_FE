import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

// 공통 UI 블록 — 모든 화면은 이 블록으로 구성한다.

// ───────────────────────────── Skeleton / Shimmer ─────────────────────────────

/// 내부의 [SkeletonBox]들에 하나의 공통 shimmer 물결을 제공한다.
/// "동작 줄이기"가 켜져 있으면 정적.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  // 지연 생성: reduced-motion에서는 아예 필요 없음.
  AnimationController? _ctrl;
  AnimationController get _c =>
      _ctrl ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return widget.child;
    final p = context.palette;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [p.skeleton, p.surfaceAlt.withValues(alpha: 0.9), p.skeleton],
          stops: const [0.25, 0.5, 0.75],
          transform: _SlideGradient(_c.value),
        ).createShader(rect),
        child: child,
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);
  final double t;
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = Radii.sm});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: context.palette.skeleton, borderRadius: BorderRadius.circular(radius)),
  );
}

/// 카드 형태의 기본 스켈레톤 (목록 로딩 중).
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 2, this.leading = true});
  final int lines;
  final bool leading;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading) ...[const SkeletonBox(width: 44, height: 44, radius: Radii.md), const SizedBox(width: Space.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 160, height: 16),
                for (var i = 0; i < lines; i++) ...[
                  const SizedBox(height: Space.sm),
                  SkeletonBox(width: i == lines - 1 ? 120 : double.infinity, height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ───────────────────────────── 텍스트 / 제목 ─────────────────────────────

/// 섹션 제목: "다가오는 일정 ........ 전체".
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.padding});
  final String title;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding ?? const EdgeInsets.fromLTRB(Space.gutter, Space.xxl, Space.sm, Space.sm),
    child: Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text(title, style: context.textStyles.titleMedium)),
        ),
        ?action,
      ],
    ),
  );
}

/// Kichik teg: "일정 알림", "D-12", "#ai".
enum Tone { neutral, primary, accent, danger, info }

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.icon, this.tone = Tone.neutral, this.dense = false});
  final String label;
  final IconData? icon;
  final Tone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, fg) = switch (tone) {
      Tone.neutral => (p.surfaceAlt, p.textMuted),
      Tone.primary => (p.primarySoft, p.primary),
      Tone.accent => (p.accentSoft, p.accent),
      Tone.danger => (p.dangerSoft, p.danger),
      Tone.info => (p.infoSoft, p.info),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : Space.sm, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(
              child: Icon(icon, size: dense ? 12 : 14, color: fg),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.labelSmall!.copyWith(color: fg, fontSize: dense ? 10.5 : 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// 아이콘 + 텍스트 줄 (메타 정보).
class MetaRow extends StatelessWidget {
  const MetaRow(this.icon, this.text, {super.key, this.color, this.maxLines = 1});
  final IconData icon;
  final String text;
  final Color? color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.textMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: ExcludeSemantics(child: Icon(icon, size: 16, color: c)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.bodySmall!.copyWith(color: c),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────── 블록 ─────────────────────────────

/// 날짜 타일 (행사 목록용): "NOV / 20".
class DateTile extends StatelessWidget {
  const DateTile(this.date, {super.key, this.color, this.monthLabel});
  final DateTime date;
  final Color? color;
  final String? monthLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.primary;
    return Container(
      width: 48,
      height: 52,
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(monthLabel ?? '${date.month}', style: context.textStyles.labelSmall!.copyWith(color: c, fontSize: 10.5)),
          Text('${date.day}', style: context.textStyles.titleLarge!.copyWith(height: 1.1)),
        ],
      ),
    );
  }
}

/// 아이콘이 든 사각형 (카테고리/상태 표시).
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.tone = Tone.primary, this.size = 40});
  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, fg) = switch (tone) {
      Tone.neutral => (p.surfaceAlt, p.textMuted),
      Tone.primary => (p.primarySoft, p.primary),
      Tone.accent => (p.accentSoft, p.accent),
      Tone.danger => (p.dangerSoft, p.danger),
      Tone.info => (p.infoSoft, p.info),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.md)),
      child: ExcludeSemantics(
        child: Icon(icon, size: size * 0.5, color: fg),
      ),
    );
  }
}

/// 빈 상태: 아이콘 + 제목 + 설명 + 행동 버튼.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.actions = const []});
  final IconData icon;
  final String title;
  final String? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xxxl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTile(icon, size: 56),
        const SizedBox(height: Space.lg),
        Text(title, style: context.textStyles.titleMedium, textAlign: TextAlign.center),
        if (body != null) ...[
          const SizedBox(height: Space.sm),
          Text(
            body!,
            style: context.textStyles.bodyMedium!.copyWith(color: context.palette.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          Wrap(spacing: Space.sm, runSpacing: Space.sm, alignment: WrapAlignment.center, children: actions),
        ],
      ],
    ),
  );
}

/// 프로필 사진: 사진이 없으면 이니셜.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, this.photoUrl, this.name, this.size = 48});
  final String? photoUrl;
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final initials = (name ?? '').trim().isEmpty ? null : name!.trim().characters.first.toUpperCase();
    final fallback = Center(
      child: initials == null
          ? Icon(Icons.person_outline, size: size * 0.5, color: p.primary)
          : Text(
              initials,
              style: context.textStyles.titleMedium!.copyWith(color: p.primary, fontSize: size * 0.4),
            ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: p.primarySoft, shape: BoxShape.circle),
      child: photoUrl == null
          ? fallback
          : Image.network(photoUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }
}

/// 그룹으로 묶인 설정/정보 블록 (iOS 설정 스타일).
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(indent: Space.lg, endIndent: Space.lg),
          children[i],
        ],
      ],
    ),
  );
}

// ───────────────────────────── 동작 ─────────────────────────────

/// 목록 항목의 부드러운 등장: 투명도 + 8px 위로 이동, [index]에 따라 지연.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.slow);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Motion.curve);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
      return;
    }
    Future.delayed(Duration(milliseconds: 40 * widget.index.clamp(0, 8)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (_, child) => Transform.translate(offset: Offset(0, 8 * (1 - _a.value)), child: child),
    ),
  );
}

/// 색상 관심사 칩. [onTap]이 있으면 선택 가능(온보딩), 없으면 정적 표시.
class InterestChip extends StatelessWidget {
  const InterestChip({
    super.key,
    required this.label,
    required this.icon,
    required this.hue,
    this.selected = true,
    this.onTap,
    this.dense = false,
  });

  final String label;
  final IconData icon;
  final Hue hue;
  final bool selected;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (fg, bg) = hue.of(context);
    final d = Motion.of(context, Motion.fast);
    final radius = BorderRadius.circular(Radii.xl);
    final chip = AnimatedContainer(
      duration: d,
      curve: Motion.curve,
      padding: EdgeInsets.symmetric(horizontal: dense ? Space.sm + 2 : Space.md, vertical: dense ? 5 : Space.sm + 2),
      decoration: BoxDecoration(
        color: selected ? bg : p.surface,
        borderRadius: radius,
        border: Border.all(
          color: selected ? fg.withValues(alpha: 0.55) : p.border,
          // 선택 여부와 관계없이 같은 두께 — 선택해도 칩 크기·줄바꿈이 바뀌지 않는다.
          width: onTap != null ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: dense ? 14 : 18, color: fg),
          ),
          SizedBox(width: dense ? 5 : Space.sm),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (dense ? context.textStyles.labelMedium : context.textStyles.titleSmall)!.copyWith(
                color: selected ? fg : p.text,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: radius, child: chip),
      ),
    );
  }
}

/// AnimatedSize이지만 "동작 줄이기"가 켜지면 애니메이션 없음.
/// (AnimatedSize에 Duration.zero를 주면 Flutter layout assertion이 발생한다.)
class SmoothSize extends StatelessWidget {
  const SmoothSize({super.key, required this.child, this.duration = Motion.normal, this.alignment = Alignment.center});
  final Widget child;
  final Duration duration;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, duration);
    if (d == Duration.zero) return child;
    return AnimatedSize(duration: d, curve: Motion.curve, alignment: alignment, child: child);
  }
}

/// 한 줄 텍스트: 들어가면 그대로, 넘치면 오른쪽에서 왼쪽으로 천천히 흐른다
/// (매 회전 전 짧은 정지). "동작 줄이기"에서는 "…"로 자른다.
class MarqueeText extends StatefulWidget {
  const MarqueeText(this.text, {super.key, this.style, this.velocity = 28, this.gap = 48});

  final String text;
  final TextStyle? style;

  /// 픽셀 / 초.
  final double velocity;
  final double gap;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  static const _pause = Duration(milliseconds: 1600);
  late final AnimationController _c = AnimationController(vsync: this);
  double _distance = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _run(double distance) {
    if (distance == _distance && _c.isAnimating) return;
    _distance = distance;
    final move = Duration(milliseconds: (distance / widget.velocity * 1000).round());
    _c
      ..duration = move + _pause
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return LayoutBuilder(
      builder: (context, c) {
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final fits = tp.width <= c.maxWidth;
        if (fits || reduce || !c.maxWidth.isFinite) {
          if (_c.isAnimating) _c.stop();
          return Text(widget.text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
        }
        final distance = tp.width + widget.gap;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _run(distance);
        });
        final pauseFraction = _pause.inMilliseconds / (_c.duration?.inMilliseconds ?? 1).clamp(1, 1 << 31);
        final line = Text(widget.text, style: style, maxLines: 1, softWrap: false);
        return Semantics(
          label: widget.text,
          child: ExcludeSemantics(
            child: ClipRect(
              child: SizedBox(
                height: tp.height,
                width: c.maxWidth,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, child) {
                    final t = _c.value <= pauseFraction ? 0.0 : (_c.value - pauseFraction) / (1 - pauseFraction);
                    return OverflowBox(
                      alignment: Alignment.centerLeft,
                      maxWidth: double.infinity,
                      child: Transform.translate(offset: Offset(-t * distance, 0), child: child),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      line,
                      SizedBox(width: widget.gap),
                      line,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 앱 전체에서 하나뿐인 스피너: 얇고, 끝이 둥글며, 브랜드 색.
class AppSpinner extends StatelessWidget {
  const AppSpinner({super.key, this.size = 18, this.color, this.strokeWidth = 2.2});

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(
      strokeWidth: strokeWidth,
      strokeCap: StrokeCap.round,
      color: color ?? context.palette.primary,
      backgroundColor: (color ?? context.palette.primary).withValues(alpha: 0.15),
    ),
  );
}

/// 차분한 태그 하나: 아이콘은 선택; [color]가 있으면 배경 없이 글자색만 (예: "무료").
class QuietTag {
  const QuietTag(this.label, {this.icon, this.color});
  final String label;
  final IconData? icon;
  final Color? color;
}

/// 카드의 미니멀 태그: 배경·테두리 없이 차분한 색 — "✦ AI · 🚀 Startups".
/// 색상 [InterestChip]은 선택 화면에서만 사용; 카드에서는 태그가 핵심 정보보다 눈에 띄지 않게 한다.
class QuietTags extends StatelessWidget {
  const QuietTags(this.items, {super.key});

  final List<QuietTag> items;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = context.textStyles.labelMedium!.copyWith(color: p.textMuted, fontWeight: FontWeight.w500);
    final spans = <InlineSpan>[];
    for (var i = 0; i < items.length; i++) {
      final tag = items[i];
      final c = tag.color ?? p.textMuted;
      if (i > 0) {
        spans.add(TextSpan(text: '  ·  ', style: style.copyWith(color: p.border)));
      }
      if (tag.icon != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(tag.icon, size: 13, color: c),
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: tag.label,
          style: tag.color == null ? null : TextStyle(color: c, fontWeight: FontWeight.w600),
        ),
      );
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 상세 창(바텀 시트) 틀: 약 92% 높이로 열리고, 위로 끌면 95%까지,
/// 아래로 끌면 닫힘. 위쪽에 핸들과 항상 보이는 "뒤로" 버튼.
/// [bodyBuilder] — 스크롤 콘텐츠(전달받은 controller 사용), [bottom] — 고정 하단 패널.
class DetailSheet extends StatefulWidget {
  const DetailSheet({super.key, required this.bodyBuilder, this.bottom});

  final Widget Function(BuildContext context, ScrollController controller) bodyBuilder;
  final Widget? bottom;

  static const initial = 0.92;

  /// 최대 높이 — 전체 화면이 아니라 위쪽 배경이 조금 보이게 한다.
  static const max = 0.95;

  @override
  State<DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<DetailSheet> {
  final _sheet = DraggableScrollableController();

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails d) {
    if (!_sheet.isAttached) return;
    final h = MediaQuery.sizeOf(context).height;
    _sheet.jumpTo((_sheet.size - d.delta.dy / h).clamp(0.3, DetailSheet.max));
  }

  void _dragEnd(DragEndDetails d) {
    if (!_sheet.isAttached) return;
    final v = d.primaryVelocity ?? 0;
    final size = _sheet.size;
    final dur = Motion.of(context, Motion.normal);
    void go(double to) => dur == Duration.zero // reduced motion: animateTo(zero) — assertion
        ? _sheet.jumpTo(to)
        : _sheet.animateTo(to, duration: dur, curve: Curves.easeOutCubic);
    if (v > 700 || size < 0.6) {
      Navigator.of(context).maybePop();
    } else if (v < -300 || size > (DetailSheet.initial + DetailSheet.max) / 2) {
      go(DetailSheet.max);
    } else {
      go(DetailSheet.initial);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DraggableScrollableSheet(
      controller: _sheet,
      expand: false,
      initialChildSize: DetailSheet.initial,
      minChildSize: 0.3,
      maxChildSize: DetailSheet.max,
      snap: true,
      snapSizes: const [DetailSheet.initial],
      builder: (context, controller) => Column(children: [
        // 핸들 + 뒤로 — 이 부분을 끌어서 창을 키우거나 닫을 수 있다.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: _drag,
          onVerticalDragEnd: _dragEnd,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.xs, 0),
            child: Column(children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(2)),
              ),
              Row(children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ]),
            ]),
          ),
        ),
        Expanded(child: widget.bodyBuilder(context, controller)),
        ?widget.bottom,
      ]),
    );
  }
}

/// "Liquid glass" 표면: 뒤의 내용이 흐리게 비친다 (blur + 반투명 배경),
/// 얇고 밝은 테두리와 부드러운 그림자. 지도 버튼, 필터, 탭 바에서 공통 사용.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 999,
    this.padding = EdgeInsets.zero,
    this.opacity,
    this.blur = 18,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// 배경 투명도 (null — 테마 기본값: light 0.62, dark 0.55).
  final double? opacity;
  final double blur;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final br = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: shadow
            ? [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.40 : 0.12), blurRadius: 24, offset: const Offset(0, 8))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (dark ? const Color(0xFF1B2327) : Colors.white).withValues(alpha: opacity ?? (dark ? 0.55 : 0.62)),
              borderRadius: br,
              border: Border.all(color: Colors.white.withValues(alpha: dark ? 0.12 : 0.7)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 유리 캡슐 안의 선택 컨트롤: 선택된 항목 아래의 안쪽 캡슐이 살짝 튀며 이동한다.
class GlassSegmented<T> extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.label,
    this.icon,
    this.height = 46,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) label;
  final IconData Function(T, bool selected)? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final n = values.length;
    final index = values.indexOf(selected).clamp(0, n - 1);
    final d = Motion.of(context, const Duration(milliseconds: 380));
    // 복잡한 배경(지도 글자) 위에 놓이는 컨트롤 — 읽기 쉽도록 더 두꺼운 유리.
    return GlassSurface(
      opacity: dark ? 0.82 : 0.84,
      blur: 24,
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        height: height - 8,
        child: Stack(fit: StackFit.expand, children: [
          AnimatedAlign(
            duration: d,
            curve: Curves.easeOutBack,
            alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: dark ? Colors.white.withValues(alpha: 0.13) : p.primarySoft.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Row(children: [
            for (final v in values)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: v == selected,
                  label: label(v),
                  excludeSemantics: true,
                  onTap: () => onChanged(v),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(v),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (icon != null) ...[
                        Icon(icon!(v, v == selected), size: 18, color: v == selected ? p.primary : p.text),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          label(v),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.labelLarge!.copyWith(
                            color: v == selected ? p.primary : p.text,
                            fontWeight: v == selected ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}
