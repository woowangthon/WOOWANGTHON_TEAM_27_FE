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
                            Text(dayLabel(entry.key), style: t.titleSmall),
                            const SizedBox(width: Space.sm),
                            Expanded(child: Divider(color: context.palette.border, height: 1)),
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

Color _topicColor(BuildContext context, AlertTopic t) {
  final p = context.palette;
  return switch (t) {
    AlertTopic.road => p.accent,
    AlertTopic.transit => p.danger,
    AlertTopic.weather => p.info,
    AlertTopic.crowd => p.primary,
  };
}

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
        border: calm ? Border.all(color: p.border) : null,
        boxShadow: calm ? null : [BoxShadow(color: p.primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
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
                            margin: const EdgeInsets.only(right: 2),
                            color: Colors.white.withValues(alpha: 0.35 + 0.15 * tp.index),
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
    return Padding(
      padding: const EdgeInsets.only(right: Space.sm),
      child: FilterChip(
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? c : p.textMuted),
        label: Text('$label $count'),
        selectedColor: c.withValues(alpha: 0.14),
        side: BorderSide(color: selected ? c : p.border),
      ),
    );
  }
}

/// 알림 한 줄: 종류 아이콘 · 제목 한 줄 · 어느 일정인지. 새 알림은 점.
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

    return AnimatedOpacity(
      duration: Motion.of(context, Motion.normal),
      opacity: unseen ? 1 : 0.62,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: () {
            ref.read(seenProvider.notifier).mark(['insight:${alert.id}']);
            openSignal(context, ref, alert);
          },
          child: Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: unseen ? color.withValues(alpha: 0.45) : p.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(alertTopicIcon(topic), color: color, size: 22),
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
                        style: t.titleSmall,
                      ),
                      if (plan != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.event_note_rounded, size: 14, color: p.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                [?when, plan!.title].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (unseen)
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(left: Space.sm),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: p.textMuted),
              ],
            ),
          ),
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
