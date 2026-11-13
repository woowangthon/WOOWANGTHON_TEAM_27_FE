import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:liferadar_core/liferadar_core.dart';

import '../../core/l10n_ext.dart';
import '../../core/notify/notify.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../core/widgets.dart';
import '../../data/alerts.dart';
import '../../data/notifications.dart';
import '../../data/providers.dart';
import '../home/home_screen.dart' show openSignal;

/// 알림 탭 — 내 일정에 영향을 주는 경고만, 일정 날짜별로.
/// 홈(새 소식·기회)과 내용이 겹치지 않는다. 한눈에: 몇 건인지, 무슨 종류인지,
/// 어느 일정인지. 자세한 이유는 눌렀을 때만.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  AlertTopic? _topic;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final planList = ref.watch(plansProvider);
    final all = alertsFrom(ref.watch(insightsProvider), planList);
    final seen = ref.watch(seenProvider);
    final plans = {for (final p in planList) p.id: p};
    final now = ref.watch(nowProvider);
    final today = DateTime(now.year, now.month, now.day);

    final counts = <AlertTopic, int>{};
    for (final a in all) {
      counts.update(alertTopicOf(a), (n) => n + 1, ifAbsent: () => 1);
    }
    // 고른 종류가 사라지면 전체로 돌아간다.
    final topic = counts.containsKey(_topic) ? _topic : null;
    final shown = topic == null ? all : all.where((a) => alertTopicOf(a) == topic).toList();
    final unseen = all.where((a) => !seen.contains('insight:${a.id}')).toList();

    // 일정 날짜별 묶음: 오늘 · 내일 · 그 뒤 날짜.
    final groups = <DateTime, List<Insight>>{};
    for (final a in shown) {
      final start = plans[a.planId]?.start;
      final day = start == null ? DateTime(9999) : DateTime(start.year, start.month, start.day);
      groups.putIfAbsent(day, () => []).add(a);
    }
    String dayLabel(DateTime d) {
      if (d.year == 9999) return l10n.alertsNoDate;
      final diff = d.difference(today).inDays;
      if (diff == 0) return l10n.today;
      if (diff == 1) return l10n.alertsTomorrow;
      return DateFormat.MMMEd(context.lang).format(d);
    }

    return Scaffold(
      body: Stack(
        children: [
          const AmbientGlow(),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.sm, Space.md),
                    child: Row(
                      children: [
                        Expanded(child: Text(l10n.alertsTitle, style: t.headlineSmall)),
                        const _PushToggle(),
                        PopupMenuButton<String>(
                          tooltip: l10n.more,
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (v) async {
                            if (v == 'read') {
                              await ref.read(seenProvider.notifier).mark([for (final a in all) 'insight:${a.id}']);
                              Toast.show(l10n.alertsAllRead, type: ToastType.info);
                            } else if (v == 'test') {
                              await ref.read(signalNotifierProvider).test();
                              Toast.show(l10n.alertsTestSent, type: ToastType.info);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'read',
                              enabled: unseen.isNotEmpty,
                              child: Text(l10n.alertsMarkAllRead),
                            ),
                            if (ref.read(notificationsEnabledProvider))
                              PopupMenuItem(value: 'test', child: Text(l10n.notifyTest)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    child: _Summary(total: all.length, unseen: unseen.length, counts: counts),
                  ),
                ),
                if (counts.length > 1)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 56,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                        children: [
                          _TopicChip(
                            label: l10n.alertsAll,
                            count: all.length,
                            selected: topic == null,
                            onTap: () => setState(() => _topic = null),
                          ),
                          for (final tp in AlertTopic.values)
                            if (counts[tp] case final n?)
                              _TopicChip(
                                icon: alertTopicIcon(tp),
                                color: _topicColor(context, tp),
                                label: _topicLabel(context, tp),
                                count: n,
                                selected: topic == tp,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _topic = topic == tp ? null : tp);
                                },
                              ),
                        ],
                      ),
                    ),
                  ),
                // 알림이 없으면 위의 "조용해요" 카드가 전부 — 같은 말을 두 번 하지 않는다.
                if (all.isNotEmpty)
                  for (final entry in groups.entries) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.sm),
                        child: Row(
                          children: [
                            _DayPill(dayLabel(entry.key), today: entry.key == today),
                            const SizedBox(width: Space.sm),
                            Text('${entry.value.length}', style: t.labelLarge!.copyWith(color: context.palette.textMuted)),
                          ],
                        ),
                      ),
                    ),
                    SliverList.builder(
                      itemCount: entry.value.length,
                      itemBuilder: (_, i) {
                        final a = entry.value[i];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
                          child: FadeSlideIn(
                            key: ValueKey(a.id),
                            index: i,
                            child: _AlertTile(alert: a, plan: plans[a.planId], unseen: !seen.contains('insight:${a.id}')),
                          ),
                        );
                      },
                    ),
                  ],
                SliverToBoxAdapter(child: SizedBox(height: Space.xxxl * 2 + MediaQuery.paddingOf(context).bottom)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _topicLabel(BuildContext context, AlertTopic t) {
  final l10n = context.l10n;
  return switch (t) {
    AlertTopic.road => l10n.alertsTopicRoad,
    AlertTopic.transit => l10n.alertsTopicTransit,
    AlertTopic.weather => l10n.alertsTopicWeather,
    AlertTopic.crowd => l10n.alertsTopicCrowd,
  };
}

/// 종류별 밝은 색 (다크 모드에서도 같은 색 — 채도가 높아 어두운 배경에서도 잘 보인다).
Color _topicColor(BuildContext context, AlertTopic t) => switch (t) {
  AlertTopic.road => const Color(0xFFFF9600), // 주황
  AlertTopic.transit => const Color(0xFFFF4B6E), // 산호빨강
  AlertTopic.weather => const Color(0xFF1CB0F6), // 하늘
  AlertTopic.crowd => context.palette.primary, // 브랜드 #5865F2
};

/// 3D "입술" — 같은 색을 어둡게 한 아래 그림자 (Duolingo 버튼처럼).
Color _lip(Color c) => Color.lerp(c, Colors.black, 0.22)!;

/// 맨 위 요약: 큰 숫자 하나 + 종류별 비율 막대. 알림이 없으면 "조용한 날".
class _Summary extends StatelessWidget {
  const _Summary({required this.total, required this.unseen, required this.counts});
  final int total, unseen;
  final Map<AlertTopic, int> counts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final calm = total == 0;
    final fg = calm ? p.text : p.onPrimary;

    return AnimatedContainer(
      duration: Motion.of(context, Motion.normal),
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        gradient: calm ? null : p.brandGradient,
        color: calm ? p.surface : null,
        borderRadius: BorderRadius.circular(Radii.xl),

        boxShadow: calm
            ? [BoxShadow(color: p.border, offset: const Offset(0, 4))]
            : [
                BoxShadow(color: _lip(p.primary), offset: const Offset(0, 5)),
                BoxShadow(color: p.primary.withValues(alpha: 0.30), blurRadius: 24, offset: const Offset(0, 14)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (calm)
                Icon(Icons.verified_rounded, size: 40, color: p.primary)
              else
                Text('$total', style: t.displaySmall!.copyWith(color: fg, fontWeight: FontWeight.w800, height: 1)),
              const SizedBox(width: Space.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    calm ? l10n.alertsCalm : l10n.alertsSummary,
                    style: t.titleMedium!.copyWith(color: fg),
                  ),
                ),
              ),
              if (unseen > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(l10n.alertsNew(unseen), style: t.labelSmall!.copyWith(color: fg)),
                ),
            ],
          ),
          if (!calm) ...[
            const SizedBox(height: Space.lg),
            // 종류별 비율 — 색 막대 하나로 한눈에.
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    for (final tp in AlertTopic.values)
                      if (counts[tp] case final n?)
                        Expanded(
                          flex: n,
                          child: Container(
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: tp == AlertTopic.crowd ? Colors.white : _topicColor(context, tp),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.md,
              runSpacing: Space.xs,
              children: [
                for (final tp in AlertTopic.values)
                  if (counts[tp] case final n?)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(alertTopicIcon(tp), size: 14, color: fg),
                        const SizedBox(width: 4),
                        Text('${_topicLabel(context, tp)} $n', style: t.labelMedium!.copyWith(color: fg)),
                      ],
                    ),
              ],
            ),
          ] else ...[
            const SizedBox(height: Space.xs),
            Text(l10n.alertsCalmBody, style: t.bodySmall),
            const SizedBox(height: Space.md),
            Text(l10n.alertsEmptyBody, style: t.bodySmall),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => GoRouter.of(context).go('/plans'),
                icon: const Icon(Icons.event_note_rounded, size: 18),
                label: Text(l10n.tabPlans),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 눌리는 3D 블록 — 아래쪽 "입술"(어두운 그림자)이 있고, 누르면 그만큼 내려간다.
class _Press3D extends StatefulWidget {
  const _Press3D({required this.child, required this.face, required this.lip, this.onTap, this.radius = Radii.lg, this.depth = 4});
  final Widget child;
  final Color face, lip;
  final VoidCallback? onTap;
  final double radius, depth;

  @override
  State<_Press3D> createState() => _Press3DState();
}

class _Press3DState extends State<_Press3D> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final d = _down ? 0.0 : widget.depth;
    final duration = Motion.of(context, const Duration(milliseconds: 90));
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedContainer(
        duration: duration,
        margin: EdgeInsets.only(top: widget.depth - d),
        decoration: BoxDecoration(
          color: widget.face,
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            BoxShadow(color: widget.lip, offset: Offset(0, d)),
            if (!_down) BoxShadow(color: widget.lip.withValues(alpha: 0.18), blurRadius: 16, offset: Offset(0, d + 6)),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// 날짜 묶음 제목 — 오늘은 브랜드 색으로 채운 알약.
class _DayPill extends StatelessWidget {
  const _DayPill(this.label, {required this.today});
  final String label;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final face = today ? p.primary : p.primarySoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 5),
      decoration: BoxDecoration(
        color: face,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: today ? _lip(p.primary) : p.primary.withValues(alpha: 0.18), offset: const Offset(0, 3))],
      ),
      child: Text(
        label,
        style: context.textStyles.labelLarge!.copyWith(color: today ? p.onPrimary : p.primaryStrong, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.label, required this.count, required this.selected, required this.onTap, this.icon, this.color});
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.primary;
    final fg = selected ? Colors.white : p.text;
    return Padding(
      padding: const EdgeInsets.only(right: Space.sm, bottom: 4),
      child: _Press3D(
        onTap: onTap,
        face: selected ? c : p.surface,
        lip: selected ? _lip(c) : p.border,
        radius: 999,
        depth: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: selected ? Colors.white : c), const SizedBox(width: 6)],
              Text('$label $count', style: context.textStyles.labelLarge!.copyWith(color: fg, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 알림 한 줄: 밝은 종류 아이콘 · 제목 한 줄 · 어느 일정인지. 테두리 없이 3D 블록.
/// 새 알림은 종류 색의 입술, 읽은 알림은 차분한 회색 입술.
class _AlertTile extends ConsumerWidget {
  const _AlertTile({required this.alert, required this.plan, required this.unseen});
  final Insight alert;
  final Plan? plan;
  final bool unseen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.textStyles;
    final topic = alertTopicOf(alert);
    final color = _topicColor(context, topic);
    final when = plan == null || plan!.isAllDay ? null : DateFormat.Hm(context.lang).format(plan!.start);
    // 행사가 원인이면 행사 이름이 가장 짧고 분명하다 (날짜·장소는 묶음 제목과 일정 줄에 이미 있다).
    final event = alert.eventIds.isEmpty ? null : ref.watch(eventByIdProvider(alert.eventIds.first));
    final headline = context.tr(event?.title ?? alert.title);

    return _Press3D(
      onTap: () {
        ref.read(seenProvider.notifier).mark(['insight:${alert.id}']);
        openSignal(context, ref, alert);
      },
      face: p.surface,
      lip: unseen ? color.withValues(alpha: 0.55) : p.border,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          children: [
            // 아이콘 구슬 — 밝은 색 + 아래 입술
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: unseen ? color : color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                boxShadow: unseen ? [BoxShadow(color: _lip(color), offset: const Offset(0, 3))] : null,
              ),
              child: Icon(alertTopicIcon(topic), color: unseen ? Colors.white : color, size: 23),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall!.copyWith(
                      fontWeight: unseen ? FontWeight.w800 : FontWeight.w600,
                      color: unseen ? p.text : p.textMuted,
                    ),
                  ),
                  if (plan != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      [?when, plan!.title].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (unseen)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.only(left: Space.sm),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                child: Text('NEW', style: t.labelSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
              )
            else
              Icon(Icons.chevron_right_rounded, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}

/// 휴대폰 알림 켜기/끄기 — 알림 탭의 오른쪽 위 (설정은 여기 한 곳에만).
class _PushToggle extends ConsumerWidget {
  const _PushToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final on = ref.watch(notificationsEnabledProvider);

    Future<void> toggle() async {
      final c = ref.read(notificationsEnabledProvider.notifier);
      if (!notifySupported) {
        Toast.show(l10n.notifyUnsupported, type: ToastType.warning);
        return;
      }
      if (on) {
        await c.disable();
        Toast.show(l10n.notifyOff, type: ToastType.info);
        return;
      }
      final r = await c.enable();
      switch (r) {
        case 'granted':
          Toast.show(l10n.notifyOn);
        case 'unsupported':
          Toast.show(l10n.notifyUnsupported, type: ToastType.warning);
        default:
          final opened = await openNotifySettings();
          Toast.show(opened ? l10n.notifyDeniedApp : l10n.notifyDenied, type: ToastType.warning);
      }
    }

    return Tooltip(
      message: l10n.notifications,
      child: ActionChip(
        onPressed: toggle,
        avatar: Icon(
          on ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
          size: 16,
          color: on ? p.primary : p.textMuted,
        ),
        label: Text(on ? l10n.alertsPushOn : l10n.alertsPushOff),
        side: BorderSide(color: on ? p.primary.withValues(alpha: 0.5) : p.border),
        backgroundColor: on ? p.primarySoft : null,
      ),
    );
  }
}
