import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/calendar_link.dart';
import '../../core/errors.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/calendar_controller.dart';
import '../../data/providers.dart';
import 'package:liferadar_core/liferadar_core.dart';
import '../shell/app_shell.dart';
import '../weather/weather_chip.dart';
import 'month_view.dart';
import 'plan_detail_sheet.dart';
import 'plan_editor_sheet.dart';
import 'plan_signals.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  static const _viewKey = 'plans_view';

  /// 월간 보기 (선택을 기억한다).
  late bool _month = ref.read(sharedPrefsProvider).getString(_viewKey) == 'month';
  DateTime? _selected;
  DateTime? _visibleMonth;

  void _setMonth(bool v) {
    setState(() => _month = v);
    ref.read(sharedPrefsProvider).setString(_viewKey, v ? 'month' : 'list');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cal = ref.watch(calendarProvider);
    final now = ref.watch(nowProvider);
    final today = DateTime(now.year, now.month, now.day);
    final all = ref.watch(plansProvider);
    final upcoming = all.where((p) => !p.end.isBefore(today)).toList()..sort((a, b) => a.start.compareTo(b.start));
    final insights = ref.watch(insightsProvider);
    final signalPlanIds = {for (final i in insights) ?i.planId};
    final selected = _selected ?? today;
    final visibleMonth = _visibleMonth ?? selected;

    Widget planTile(Plan plan, int i) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
      child: FadeSlideIn(
        key: ValueKey('${plan.id}-$_month'),
        index: i,
        child: _PlanCard(plan: plan),
      ),
    );

    // 목록: 날짜별 그룹
    final groups = <DateTime, List<Plan>>{};
    for (final p in upcoming) {
      final d = p.start.isBefore(today) ? today : DateTime(p.start.year, p.start.month, p.start.day);
      groups.putIfAbsent(d, () => []).add(p);
    }
    String dayLabel(DateTime d) {
      final diff = d.difference(today).inDays;
      if (diff == 0) return l10n.today;
      if (diff == 1) return l10n.tomorrow;
      return DateFormat.MMMMEEEEd(context.lang).format(d);
    }

    final dayPlans = all.where((p) => MonthView.covers(p, selected)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabPlans),
        actions: [
          IconButton(
            tooltip: _month ? l10n.planViewList : l10n.planViewMonth,
            onPressed: () => _setMonth(!_month),
            icon: Icon(_month ? Icons.view_agenda_outlined : Icons.calendar_month_outlined),
          ),
          if (cal.isConnected)
            IconButton(
              tooltip: l10n.calendarSync,
              onPressed: cal.isBusy ? null : () => ref.read(calendarProvider.notifier).sync(),
              icon: const Icon(Icons.sync_rounded),
            ),
          const SizedBox(width: Space.sm),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPlanEditor(context, day: _month ? selected : null),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.planNew),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (cal.isConnected) await ref.read(calendarProvider.notifier).sync();
        },
        child: ListView(
          // FAB가 마지막 카드를 가리지 않도록.
          padding: EdgeInsets.only(bottom: 96 + MediaQuery.paddingOf(context).bottom),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: _CalendarCard(onOpenMonth: () => _setMonth(true)),
            ),
            if (cal.isBusy)
              const Shimmer(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(Space.gutter, Space.xxl, Space.gutter, 0),
                  child: Column(
                    children: [
                      SkeletonCard(),
                      SizedBox(height: Space.md),
                      SkeletonCard(),
                      SizedBox(height: Space.md),
                      SkeletonCard(lines: 1),
                    ],
                  ),
                ),
              )
            else if (_month) ...[
              // ── 월간 보기 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.xs, Space.sm),
                    child: MonthView(
                      month: visibleMonth,
                      selected: selected,
                      today: today,
                      plans: all,
                      signalPlanIds: signalPlanIds,
                      onSelect: (d) => setState(() {
                        _selected = d;
                        _visibleMonth = d;
                      }),
                      onMonth: (m) => setState(() {
                        _visibleMonth = m;
                        if (DateUtils.isSameMonth(m, today)) _selected = today;
                      }),
                    ),
                  ),
                ),
              ),
              SectionHeader(dayLabel(selected)),
              if (dayPlans.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Text(
                    l10n.noPlansThisDay,
                    style: context.textStyles.bodyMedium!.copyWith(color: context.palette.textMuted),
                  ),
                )
              else
                for (var i = 0; i < dayPlans.length; i++) planTile(dayPlans[i], i),
            ] else if (upcoming.isEmpty)
              EmptyState(
                icon: Icons.event_available_outlined,
                title: l10n.upcoming,
                body: l10n.plansEmptyAdd,
                actions: [
                  FilledButton.icon(
                    onPressed: () => showPlanEditor(context),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.planNew),
                  ),
                ],
              )
            else
              for (final entry in groups.entries) ...[
                SectionHeader(dayLabel(entry.key)),
                for (var i = 0; i < entry.value.length; i++) planTile(entry.value[i], i),
              ],
          ],
        ),
      ),
    );
  }
}

/// 미연결: 캘린더 연결 카드. 연결됨: 얇은 줄 — 누르면 월간 보기,
/// ↗ — Google 캘린더 자체.
class _CalendarCard extends ConsumerWidget {
  const _CalendarCard({required this.onOpenMonth});
  final VoidCallback onOpenMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final cal = ref.watch(calendarProvider);
    final c = ref.read(calendarProvider.notifier);
    final count = ref.watch(plansProvider).where((x) => x.source == 'gcal').length;

    final error = cal.status != CalendarStatus.error
        ? null
        : switch (cal.error) {
            'not-configured' => l10n.calendarNotConfigured,
            'expired' => l10n.calendarExpired,
            _ => l10n.calendarError(friendlyError(l10n, cal.error)),
          };

    if (cal.isConnected) {
      return Material(
        color: p.primarySoft,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onOpenMonth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.xs, Space.xs),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded, size: 20, color: p.primary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    cal.isBusy ? l10n.calendarSyncing : l10n.calendarConnectedCount(count),
                    style: t.labelLarge!.copyWith(color: p.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (cal.isBusy) Padding(padding: const EdgeInsets.all(Space.md), child: AppSpinner(size: 16)),
                IconButton(
                  tooltip: l10n.calendarOpenGoogle,
                  onPressed: () => openCalendar(),
                  icon: Icon(Icons.open_in_new_rounded, size: 18, color: p.primary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconTile(Icons.calendar_month_outlined),
                const SizedBox(width: Space.md),
                Expanded(child: Text(l10n.connectCalendar, style: t.titleSmall)),
              ],
            ),
            const SizedBox(height: Space.md),
            Text(l10n.calendarPrivacy, style: t.bodySmall),
            if (error != null) ...[
              const SizedBox(height: Space.sm),
              Text(error, style: t.bodySmall!.copyWith(color: p.danger)),
            ],
            const SizedBox(height: Space.lg),
            FilledButton.icon(
              onPressed: cal.isBusy ? null : c.connect,
              icon: cal.isBusy ? AppSpinner(color: p.textMuted) : const Icon(Icons.link_rounded),
              label: Text(cal.isBusy ? l10n.calendarConnecting : l10n.connect),
            ),
          ],
        ),
      ),
    );
  }
}

/// 일정 카드: 시간 · 이름 · 장소 · 날씨 + 아래에 가장 중요한 신호 2줄.
class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});
  final Plan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final multiDay = plan.end.difference(plan.start).inDays >= 1;
    final time = plan.isAllDay ? '—' : DateFormat.Hm(context.lang).format(plan.start);
    final signals = planSignals(context, ref, plan);
    final accent = signals.isEmpty
        ? p.primary
        : switch (signals.first.tone) {
            Tone.info => p.info,
            Tone.accent => p.accent,
            _ => p.primary,
          };

    return Card(
      child: InkWell(
        onTap: () => showPlanDetail(context, plan),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(time, style: t.titleSmall),
                    if (multiDay) ...[
                      const SizedBox(height: 2),
                      Text('~${DateFormat.Md(context.lang).format(plan.end)}', style: t.labelSmall),
                    ],
                  ],
                ),
              ),
              // 왼쪽 선 — 가장 중요한 신호의 색 (없으면 브랜드 색).
              Container(
                width: 3,
                height: 44,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(plan.title, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (plan.source == 'sample') const SampleBadge(),
                        if (plan.source == 'gcal')
                          Tooltip(
                            message: l10n.sourceCalendar,
                            child: Icon(Icons.calendar_month_outlined, size: 16, color: p.textMuted),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    MetaRow(
                      plan.location == null ? Icons.location_off_outlined : Icons.place_outlined,
                      plan.locationText.isEmpty ? l10n.noLocation : plan.locationText,
                    ),
                    if (plan.location != null) ...[
                      const SizedBox(height: 6),
                      WeatherChip(location: plan.location!, date: plan.start),
                    ],
                    if (signals.isNotEmpty) ...[
                      const SizedBox(height: Space.sm),
                      for (final s in signals.take(2)) ...[PlanSignalLine(s), const SizedBox(height: 2)],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
