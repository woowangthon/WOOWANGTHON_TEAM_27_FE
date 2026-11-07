import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import 'package:liferadar_core/liferadar_core.dart';

/// 월간 달력: 일정이 있는 날은 점, 신호가 있으면 노란 점.
/// 주는 일요일부터 시작 (한국 / Google 캘린더 관례); 일요일 빨강, 토요일 파랑.
class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.month,
    required this.selected,
    required this.today,
    required this.plans,
    required this.signalPlanIds,
    required this.onSelect,
    required this.onMonth,
  });

  /// 표시 중인 달의 아무 날짜.
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final List<Plan> plans;

  /// 신호가 있는 일정 id.
  final Set<String> signalPlanIds;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onMonth;

  static DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  /// 일정이 이 날을 포함하는지 (여러 날·종일 일정 포함).
  static bool covers(Plan p, DateTime day) {
    final start = _d(p.start);
    final lastDay = _d(p.isAllDay ? p.end.subtract(const Duration(minutes: 1)) : p.end);
    return !day.isBefore(start) && !day.isAfter(lastDay);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final lang = context.lang;
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final lead = first.weekday % 7; // 일요일 = 0
    final cells = ((lead + daysInMonth) / 7).ceil() * 7;
    final d = Motion.of(context, Motion.fast);

    // 요일 이름 (일요일부터), 현재 언어 기준.
    final sunday = DateTime(2026, 11, 1); // 일요일
    final weekdays = [for (var i = 0; i < 7; i++) DateFormat.E(lang).format(sunday.add(Duration(days: i)))];

    Color dayColor(int weekdayIndex, bool inMonth) {
      if (!inMonth) return p.textMuted.withValues(alpha: 0.45);
      if (weekdayIndex == 0) return p.danger;
      if (weekdayIndex == 6) return p.info;
      return p.text;
    }

    return Column(
      children: [
        // ── 월 제목 ──
        Row(
          children: [
            Expanded(child: Text(DateFormat.yMMMM(lang).format(first), style: t.titleLarge)),
            IconButton(
              tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
              onPressed: () => onMonth(DateTime(first.year, first.month - 1)),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            TextButton(onPressed: () => onMonth(today), child: Text(context.l10n.today)),
            IconButton(
              tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
              onPressed: () => onMonth(DateTime(first.year, first.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    weekdays[i],
                    style: t.labelSmall!.copyWith(color: dayColor(i, true).withValues(alpha: 0.8)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.9),
          itemBuilder: (context, i) {
            final day = DateTime(first.year, first.month, i - lead + 1);
            final inMonth = day.month == first.month;
            final dayPlans = plans.where((x) => covers(x, day)).toList();
            final hasSignal = dayPlans.any((x) => signalPlanIds.contains(x.id));
            final isToday = DateUtils.isSameDay(day, today);
            final isSel = DateUtils.isSameDay(day, selected);
            // 각 칸은 하나의 노드 ("11월 10일, 1") — 안쪽 텍스트가 반복 읽히지 않게.
            return Semantics(
              container: true,
              button: true,
              selected: isSel,
              label: '${DateFormat.MMMMd(lang).format(day)}, ${dayPlans.length}',
              onTap: () => onSelect(day),
              excludeSemantics: true,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onSelect(day),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: d,
                      curve: Motion.curve,
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSel ? p.primary : Colors.transparent,
                        border: isToday && !isSel ? Border.all(color: p.primary, width: 1.5) : null,
                      ),
                      child: Text(
                        '${day.day}',
                        style: t.bodyMedium!.copyWith(
                          color: isSel ? p.onPrimary : dayColor(i % 7, inMonth),
                          fontWeight: isSel || isToday ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var k = 0; k < dayPlans.length.clamp(0, 3); k++) _dot(inMonth ? p.primary : p.border),
                          if (hasSignal) _dot(p.accent),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static Widget _dot(Color c) => Container(
    width: 5,
    height: 5,
    margin: const EdgeInsets.symmetric(horizontal: 1),
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}
