import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:liferadar_core/liferadar_core.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/assistant_controller.dart';
import '../../data/providers.dart';
import '../event/event_actions.dart';
import '../event/event_detail_sheet.dart';

/// 앱 안의 AI 비서. 질문하면 실제 데이터에서 찾아 답하고, 행동은 제안만 한다 —
/// 캘린더 추가·지도 보기는 사용자가 [추가]를 눌러야 실행된다.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || ref.read(assistantProvider.notifier).busy) return;
    _input.clear();
    _scrollToEnd();
    await ref.read(assistantProvider.notifier).ask(text, lang: context.lang);
    _scrollToEnd();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_scroll.hasClients || !mounted) return;
    final end = _scroll.position.maxScrollExtent;
    final d = Motion.of(context, Motion.slow);
    d == Duration.zero ? _scroll.jumpTo(end) : _scroll.animateTo(end, duration: d, curve: Motion.curve);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final messages = ref.watch(assistantProvider);
    final busy = messages.any((m) => m.loading);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const AiOrb(size: 32),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.assistantTitle, style: t.titleMedium),
                  Text(l10n.assistantSubtitle, style: t.labelSmall),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              tooltip: l10n.assistantNewChat,
              onPressed: busy ? null : ref.read(assistantProvider.notifier).clear,
              icon: const Icon(Icons.edit_square),
            ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: Stack(
        children: [
          const AmbientGlow(height: 260),
          Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.normal),
                  child: messages.isEmpty
                      ? _Intro(onPick: _send)
                      : ListView.builder(
                          key: const ValueKey('chat'),
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xl),
                          itemCount: messages.length,
                          itemBuilder: (_, i) => FadeSlideIn(
                            key: ValueKey('m$i-${messages[i].loading}'),
                            child: messages[i].fromUser
                                ? _UserBubble(messages[i].text)
                                : messages[i].loading
                                ? const _Thinking()
                                : _BotMessage(index: i, message: messages[i]),
                          ),
                        ),
                ),
              ),
              _Composer(controller: _input, focus: _focus, busy: busy, onSend: _send),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 브랜드 구슬 ─────────────────────────

/// AI 표시: 브랜드 그라데이션 구슬 + ✨. [breathing]이면 천천히 숨 쉬듯 빛난다.
class AiOrb extends StatefulWidget {
  const AiOrb({super.key, this.size = 40, this.breathing = false});
  final double size;
  final bool breathing;

  @override
  State<AiOrb> createState() => _AiOrbState();
}

class _AiOrbState extends State<AiOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.breathing && !still && !_c.isAnimating) _c.repeat(reverse: true);
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
      builder: (_, child) {
        final k = Curves.easeInOut.transform(_c.value);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: p.brandGradient,
            boxShadow: [
              BoxShadow(
                color: p.primary.withValues(alpha: 0.18 + 0.14 * k),
                blurRadius: widget.size * (0.3 + 0.25 * k),
                spreadRadius: widget.size * 0.02 * k,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Icon(Icons.auto_awesome, size: widget.size * 0.5, color: p.onPrimary),
    );
  }
}

// ───────────────────────── 첫 화면 ─────────────────────────

class _Intro extends ConsumerWidget {
  const _Intro({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final now = ref.watch(nowProvider);
    final today = DateTime(now.year, now.month, now.day);
    // 추천 질문에 쓸 일정: 장소가 있는 다가오는 일정 중 가장 긴 것 (보통 여행·출장).
    final upcoming = ref.watch(plansProvider).where((x) => !x.end.isBefore(today) && x.location != null).toList()
      ..sort((a, b) => b.end.difference(b.start).compareTo(a.end.difference(a.start)));
    final nextTrip = upcoming.firstOrNull;

    final suggestions = <(IconData, String)>[
      (Icons.weekend_outlined, l10n.assistantSuggestWeekend),
      if (nextTrip != null) (Icons.luggage_outlined, l10n.assistantSuggestPlan(nextTrip.title)),
      (Icons.hourglass_bottom_rounded, l10n.assistantSuggestDeadline),
      (Icons.palette_outlined, l10n.assistantSuggestFree),
    ];

    return ListView(
      key: const ValueKey('intro'),
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxl, Space.gutter, Space.xl),
      children: [
        const Center(child: AiOrb(size: 76, breathing: true)),
        const SizedBox(height: Space.xl),
        Text(l10n.assistantHello, textAlign: TextAlign.center, style: t.headlineSmall),
        const SizedBox(height: Space.sm),
        Text(
          l10n.assistantHelloBody,
          textAlign: TextAlign.center,
          style: t.bodyMedium!.copyWith(color: p.textMuted),
        ),
        const SizedBox(height: Space.xxl),
        for (var i = 0; i < suggestions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: FadeSlideIn(
              index: i + 1,
              child: Pressable(
                child: Material(
                  color: p.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.lg),
                    side: BorderSide(color: p.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onPick(suggestions[i].$2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md + 2),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: p.primarySoft,
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                            child: Icon(suggestions[i].$1, size: 20, color: p.primaryStrong),
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(child: Text(suggestions[i].$2, style: t.titleSmall)),
                          Icon(Icons.north_east_rounded, size: 18, color: p.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: Space.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_outlined, size: 14, color: p.textMuted),
            const SizedBox(width: Space.xs),
            Flexible(
              child: Text(l10n.assistantTrust, style: t.labelSmall, textAlign: TextAlign.center),
            ),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────── 말풍선 ─────────────────────────

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.only(bottom: Space.lg, left: Space.xxxl),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        decoration: BoxDecoration(
          gradient: p.brandGradient,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(Radii.lg),
            topRight: Radius.circular(Radii.lg),
            bottomLeft: Radius.circular(Radii.lg),
            bottomRight: Radius.circular(Radii.sm),
          ),
        ),
        child: Text(text, style: context.textStyles.bodyMedium!.copyWith(color: p.onPrimary)),
      ),
    );
  }
}

/// 비서 쪽: 구슬 + 내용 (말풍선 없이 넓게 — 카드가 들어간다).
class _BotRow extends StatelessWidget {
  const _BotRow({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.xl),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AiOrb(size: 28),
        const SizedBox(width: Space.md),
        Expanded(child: child),
      ],
    ),
  );
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    return _BotRow(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TypingDots(),
              const SizedBox(width: Space.sm),
              Text(l10n.assistantThinking, style: t.bodySmall),
            ],
          ),
          const SizedBox(height: Space.md),
          const Shimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14, width: 240),
                SizedBox(height: Space.sm),
                SkeletonBox(height: 14, width: 180),
                SizedBox(height: Space.md),
                Row(
                  children: [
                    SkeletonBox(width: 150, height: 96, radius: Radii.lg),
                    SizedBox(width: Space.sm),
                    SkeletonBox(width: 110, height: 96, radius: Radii.lg),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "입력 중" 점 세 개.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false) && !_c.isAnimating) _c.repeat();
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
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Builder(
              builder: (_) {
                final phase = (_c.value - i * 0.18) % 1.0;
                final up = math.sin(phase * math.pi).clamp(0.0, 1.0);
                return Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  transform: Matrix4.translationValues(0, -3 * up, 0),
                  decoration: BoxDecoration(
                    color: p.primary.withValues(alpha: 0.35 + 0.65 * up),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _BotMessage extends ConsumerWidget {
  const _BotMessage({required this.index, required this.message});
  final int index;
  final AssistantMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final events = [
      for (final id in message.eventIds) ?ref.watch(eventByIdProvider(id)),
    ];

    return _BotRow(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 출처 표시: AI 답인지, 조건 검색 규칙 문장인지 + 코드가 읽은 조건.
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              message.fromAi
                  ? Pill(l10n.assistantAiBadge, icon: Icons.auto_awesome, tone: Tone.primary, dense: true)
                  : Pill(l10n.assistantRuleBadge, icon: Icons.filter_alt_outlined, dense: true),
              if (message.understood.isNotEmpty) Pill(message.understood, icon: Icons.tune_rounded, dense: true),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(message.text, style: t.bodyMedium!.copyWith(height: 1.6)),
          if (events.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            SizedBox(
              height: 164,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                itemBuilder: (_, i) => FadeSlideIn(index: i, child: _MiniEventCard(events[i])),
              ),
            ),
          ],
          for (var i = 0; i < message.actions.length; i++)
            if (ref.watch(eventByIdProvider(message.actions[i].eventId)) case final e?)
              Padding(
                padding: const EdgeInsets.only(top: Space.md),
                child: _ActionCard(
                  action: message.actions[i],
                  event: e,
                  status: message.actionStatus[i],
                  onStatus: (s) => ref.read(assistantProvider.notifier).setActionStatus(index, i, s),
                ),
              ),
          if (!message.fromAi && message.text.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text(l10n.assistantRuleNote, style: t.labelSmall!.copyWith(color: p.textMuted)),
          ],
        ],
      ),
    );
  }
}

/// 추천 행사 카드 (실제 데이터) — 누르면 행사 상세.
class _MiniEventCard extends ConsumerWidget {
  const _MiniEventCard(this.event);
  final RadarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.textStyles;
    final l10n = context.l10n;
    final now = ref.watch(nowProvider);
    final ongoing = event.start.isBefore(DateTime(now.year, now.month, now.day));
    final when = (event.isApplication || event.placeless) && event.deadline != null
        ? '${l10n.kindDeadline} ${DateFormat.MMMd(context.lang).format(event.isApplication ? event.applicationDate(event.deadline!) : event.deadline!)}'
        : ongoing
        ? '~${DateFormat.MMMd(context.lang).format(event.end)}'
        : DateFormat.MMMEd(context.lang).format(event.start);

    return Pressable(
      child: SizedBox(
        width: 168,
        child: Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            side: BorderSide(color: p.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showEventDetail(
              context,
              event,
              onShowOnMap: () {
                ref.read(mapFocusProvider.notifier).focus(event.id);
                context.go('/map');
              },
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 84,
                  width: double.infinity,
                  child: event.imageUrl != null
                      ? Image.network(
                          event.imageUrl!,
                          fit: BoxFit.cover,
                          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                          errorBuilder: (_, _, _) => _CategoryArt(event.category),
                        )
                      : _CategoryArt(event.category),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr(event.title), style: t.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        '$when · ${event.city}',
                        style: t.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

class _CategoryArt extends StatelessWidget {
  const _CategoryArt(this.category);
  final EventCategory category;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.primarySoft, p.surfaceAlt],
        ),
      ),
      child: Center(child: Icon(categoryIcon(category), color: p.primaryStrong, size: 28)),
    );
  }
}

/// 제안 행동: "캘린더에 추가할까요?" [취소] [추가]. 누르기 전에는 아무것도 바뀌지 않는다.
class _ActionCard extends ConsumerWidget {
  const _ActionCard({required this.action, required this.event, required this.status, required this.onStatus});
  final AssistantAction action;
  final RadarEvent event;
  final ActionStatus status;
  final ValueChanged<ActionStatus> onStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final isCal = action.type == AssistantActionType.addToCalendar;
    final title = isCal && event.isApplication
        ? '${l10n.applicationDeadline} · ${context.tr(event.title)}'
        : context.tr(event.title);

    Future<void> run() async {
      if (isCal) {
        onStatus(ActionStatus.running);
        final ok = await addEventToCalendar(context, ref, event);
        onStatus(ok ? ActionStatus.done : ActionStatus.failed);
      } else {
        onStatus(ActionStatus.done);
        ref.read(mapFocusProvider.notifier).focus(event.id);
        context.go('/map');
      }
    }

    final Widget trailing = switch (status) {
      ActionStatus.pending || ActionStatus.failed => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: p.textMuted, minimumSize: const Size(56, 40)),
            onPressed: () => onStatus(ActionStatus.cancelled),
            child: Text(l10n.cancel),
          ),
          const SizedBox(width: Space.xs),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(72, 40),
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            ),
            onPressed: run,
            child: Text(status == ActionStatus.failed ? l10n.retry : (isCal ? l10n.assistantAdd : l10n.assistantOpen)),
          ),
        ],
      ),
      ActionStatus.running => AppSpinner(size: 20, color: p.primary),
      ActionStatus.done => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: p.primary),
          const SizedBox(width: Space.xs),
          Text(
            isCal ? l10n.assistantAdded : l10n.assistantOpened,
            style: t.labelMedium!.copyWith(color: p.primaryStrong),
          ),
        ],
      ),
      ActionStatus.cancelled => Text(l10n.assistantCancelled, style: t.labelMedium),
    };

    return AnimatedContainer(
      duration: Motion.of(context, Motion.normal),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.sm, Space.sm),
      decoration: BoxDecoration(
        color: status == ActionStatus.done ? p.primarySoft : p.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: status == ActionStatus.pending ? p.primary.withValues(alpha: 0.35) : p.border,
          width: status == ActionStatus.pending ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCal ? Icons.event_available_outlined : Icons.map_outlined,
            size: 20,
            color: status == ActionStatus.cancelled ? p.textMuted : p.primary,
          ),
          const SizedBox(width: Space.sm),
          // 무엇을 할지(굵게) + 어떤 행사인지(한 줄) — 긴 행사 이름에 질문이 잘리지 않게.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCal ? l10n.assistantProposeCalendar : l10n.assistantProposeMap,
                  style: t.titleSmall!.copyWith(color: status == ActionStatus.cancelled ? p.textMuted : p.text),
                ),
                Text(title, style: t.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.fast),
            child: KeyedSubtree(key: ValueKey(status), child: trailing),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 입력 ─────────────────────────

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.focus, required this.busy, required this.onSend});
  final TextEditingController controller;
  final FocusNode focus;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final can = controller.text.trim().isNotEmpty && !busy;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.background,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.md, Space.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focus,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        hintText: l10n.assistantHint,
                        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(color: p.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  _SendButton(enabled: can, busy: busy, onTap: onSend),
                ],
              ),
              const SizedBox(height: Space.xs),
              Text(l10n.assistantFooter, style: context.textStyles.labelSmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.busy, required this.onTap});
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Motion.of(context, Motion.fast);
    return Semantics(
      button: true,
      enabled: enabled,
      label: context.l10n.aboutMeSend,
      child: AnimatedScale(
        scale: enabled ? 1 : 0.92,
        duration: d,
        curve: Curves.easeOutBack,
        child: Pressable(
          scale: 0.9,
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            child: AnimatedContainer(
              duration: d,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: enabled ? p.brandGradient : null,
                color: enabled ? null : p.surfaceAlt,
                boxShadow: enabled
                    ? [BoxShadow(color: p.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 4))]
                    : null,
              ),
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: AppSpinner(size: 20, color: p.textMuted),
                    )
                  : Icon(Icons.arrow_upward_rounded, color: enabled ? p.onPrimary : p.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}
