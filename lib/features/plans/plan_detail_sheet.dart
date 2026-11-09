import 'package:flutter/material.dart';
import 'plan_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/calendar_link.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import 'package:liferadar_core/liferadar_core.dart';
import '../home/home_screen.dart' show openSignal;
import '../shell/app_shell.dart';
import '../weather/weather_chip.dart';
import 'plan_editor_sheet.dart';
import 'plan_signals.dart';

/// 일정 보기 (수정 전): 언제 · 어디서 · 날씨 · 주변 소식.
Future<void> showPlanDetail(BuildContext context, Plan plan) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  showDragHandle: false,
  builder: (_) => PlanDetailSheet(planId: plan.id),
);

class PlanDetailSheet extends ConsumerWidget {
  const PlanDetailSheet({super.key, required this.planId});
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final lang = context.lang;
    // 수정한 뒤에도 최신 정보가 보이도록 id로 추적한다.
    final plan = ref.watch(plansProvider).where((x) => x.id == planId).firstOrNull;
    if (plan == null) return const SizedBox(height: 120);
    final signals = planSignals(context, ref, plan);

    final sameDay =
        DateUtils.isSameDay(plan.start, plan.end) || (plan.isAllDay && plan.end.difference(plan.start).inDays <= 1);
    final dateText = sameDay
        ? DateFormat.MMMMEEEEd(lang).format(plan.start)
        : '${DateFormat.MMMEd(lang).format(plan.start)} – ${DateFormat.MMMEd(lang).format(plan.isAllDay ? plan.end.subtract(const Duration(days: 1)) : plan.end)}';
    final timeText = plan.isAllDay
        ? l10n.planAllDay
        : '${DateFormat.Hm(lang).format(plan.start)} – ${DateFormat.Hm(lang).format(plan.end)}';

    void edit() {
      // 창이 닫히면 그 context는 무효 — 수정 창은 navigator context로 연다.
      final nav = Navigator.of(context);
      nav.pop();
      showPlanEditor(nav.context, plan: plan);
    }

    void map() {
      Navigator.pop(context);
      ref.read(mapFocusProvider.notifier).focus('plan:${plan.id}');
      context.go('/map');
    }

    return DetailSheet(
      bodyBuilder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        children: [
          // ── 제목 ──
          Row(
            children: [
              switch (plan.source) {
                'gcal' => Pill(l10n.sourceCalendar, icon: Icons.calendar_month_outlined, tone: Tone.info, dense: true),
                'sample' => const SampleBadge(),
                _ => Pill(l10n.myPlanBadge, icon: Icons.edit_calendar_outlined, tone: Tone.primary, dense: true),
              },
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(plan.title, style: t.headlineSmall),
          const SizedBox(height: Space.lg),

          // ── 언제 · 어디서 ──
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(Radii.lg)),
            child: Column(
              children: [
                _Row(icon: Icons.calendar_today_outlined, label: l10n.planWhen, title: dateText, subtitle: timeText),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.md),
                  child: Divider(height: 1, color: p.border),
                ),
                _Row(
                  icon: plan.location == null ? Icons.location_off_outlined : Icons.place_outlined,
                  label: l10n.planWhere,
                  title: plan.locationText.isEmpty ? l10n.noLocation : plan.locationText,
                  subtitle: plan.city.isEmpty ? null : plan.city,
                  trailing: plan.location == null
                      ? null
                      : IconButton.filledTonal(
                          tooltip: l10n.showOnMap,
                          onPressed: map,
                          icon: const Icon(Icons.map_outlined, size: 20),
                        ),
                ),
                if (plan.location != null) ...[
                  const SizedBox(height: Space.md),
                  Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: WeatherChip(location: plan.location!, date: plan.start),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── 주변 소식 ──
          SectionHeader(l10n.planAround, padding: const EdgeInsets.fromLTRB(0, Space.xl, 0, Space.sm)),
          if (signals.isEmpty)
            Text(l10n.planNothingAround, style: t.bodyMedium!.copyWith(color: p.textMuted))
          else
            for (final s in signals) ...[
              _SignalTile(signal: s, onTap: () => openSignal(context, ref, s.insight)),
              const SizedBox(height: Space.sm),
            ],

          // ── 메모 ──
          if (plan.note != null && plan.note!.isNotEmpty) ...[
            SectionHeader(l10n.planNote, padding: const EdgeInsets.fromLTRB(0, Space.xl, 0, Space.sm)),
            Text(plan.note!, style: t.bodyLarge),
          ],
        ],
      ),
      // ── 행동 ──
      bottom: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.md),
            child: Row(
              children: [
                if (plan.isEditable) ...[
                  IconButton.outlined(
                    tooltip: l10n.planDelete,
                    style: IconButton.styleFrom(
                      foregroundColor: p.danger,
                      side: BorderSide(color: p.danger.withValues(alpha: 0.4)),
                      minimumSize: const Size(52, 52),
                    ),
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      if (await deletePlanWithConfirm(context, ref, plan)) nav.pop();
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  const SizedBox(width: Space.sm),
                ],
                if (plan.htmlLink != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openCalendar(htmlLink: plan.htmlLink, at: plan.start),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(l10n.calendarOpenGoogle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: edit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(l10n.edit),
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

/// 아이콘 원 + 작은 라벨 + 본문 (+ 선택 버튼).
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.title, this.subtitle, this.trailing});
  final IconData icon;
  final String label;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Row(
      children: [
        IconTile(icon, size: 36),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.labelSmall),
              const SizedBox(height: 2),
              Text(title, style: t.titleSmall),
              if (subtitle != null) Text(subtitle!, style: t.bodySmall),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({required this.signal, required this.onTap});
  final PlanSignal signal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: p.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            children: [
              IconTile(signal.icon, tone: signal.tone, size: 36),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(signal.text, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(signal.insight.why),
                      style: t.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
