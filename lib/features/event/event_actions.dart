import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferadar_core/liferadar_core.dart';

import '../../core/l10n_ext.dart';
import '../../core/toast.dart';
import '../../data/calendar_added.dart';
import '../../data/calendar_controller.dart';
import '../../services/calendar_api.dart';
import '../../data/providers.dart';

/// 행사를 Google 캘린더에 추가한다. 연결되지 않았다면 Google 권한 창이 열린다.
/// 공고(장소 없음 + 마감)는 몇 주짜리 일정이 아니라 마감일 09:00에 1시간짜리 알림으로 넣는다.
/// 행사 상세와 AI 비서(사용자가 [추가]를 누른 뒤)가 같은 흐름을 쓴다. 성공하면 true.
Future<bool> addEventToCalendar(BuildContext context, WidgetRef ref, RadarEvent event) async {
  final l10n = context.l10n;
  if (!event.applicationActionable(ref.read(nowProvider))) return false;
  var title = context.tr(event.title);
  var target = event;
  if (event.isApplication) {
    title = '${l10n.applicationDeadline}: $title';
  } else if (event.placeless && event.deadline != null) {
    final d = event.deadline!;
    target = RadarEvent.fromJson({
      ...event.toJson(),
      'start': DateTime(d.year, d.month, d.day, 9).toIso8601String(),
      'end': DateTime(d.year, d.month, d.day, 10).toIso8601String(),
    });
    title = '${l10n.kindDeadline}: $title';
  }
  // 며칠·몇 달 이어지는 전시·축제를 그대로 넣으면 캘린더의 모든 날이 막힌다 →
  // 갈 날 하루를 고르게 하고 그날만 넣는다.
  if (!event.isApplication && !event.placeless && spansSeveralDays(event)) {
    final day = await _pickVisitDay(context, event, ref.read(nowProvider));
    if (day == null) return false; // 취소
    target = visitOn(event, day);
  }
  if (!context.mounted) return false;
  final added = ref.read(calendarAddedProvider.notifier);
  Toast.progress(l10n.addingToCalendar);
  try {
    await ref.read(calendarProvider.notifier).addEvent(target, title: title);
    await added.mark(event.id);
    Toast.show(l10n.addedToCalendar);
    return true;
  } on CalendarAlreadyAdded {
    await added.mark(event.id);
    Toast.show(l10n.calendarAlreadyAdded, type: ToastType.info);
    return true;
  } on CalendarAddInProgress {
    return false; // 첫 요청이 끝나면 그쪽이 결과를 알린다 (진행 토스트는 그대로)
  } catch (e) {
    final notConfigured = e.toString().contains('not-configured');
    Toast.show(
      notConfigured ? l10n.calendarNotConfigured : l10n.calendarAddFailed,
      type: notConfigured ? ToastType.warning : ToastType.error,
    );
    return false;
  }
}

/// 시작일과 끝나는 날이 다르다 (밤 12시를 넘는 공연 하나는 제외: 24시간 이하).
bool spansSeveralDays(RadarEvent e) {
  final a = DateTime(e.start.year, e.start.month, e.start.day);
  final b = DateTime(e.end.year, e.end.month, e.end.day);
  return b.isAfter(a) && e.end.difference(e.start) > const Duration(hours: 24);
}

/// [day] 하루만의 일정. 행사에 하루 운영 시간(예: 10:00–18:00)이 있으면 그 시간,
/// 없으면 종일 — 시간을 지어내지 않는다.
RadarEvent visitOn(RadarEvent e, DateTime day) {
  final hasHours = (e.start.hour != 0 || e.start.minute != 0) &&
      (e.end.hour * 60 + e.end.minute) > (e.start.hour * 60 + e.start.minute);
  final start = hasHours ? DateTime(day.year, day.month, day.day, e.start.hour, e.start.minute) : DateTime(day.year, day.month, day.day);
  final end = hasHours
      ? DateTime(day.year, day.month, day.day, e.end.hour, e.end.minute)
      : DateTime(day.year, day.month, day.day).add(const Duration(days: 1));
  return RadarEvent.fromJson({...e.toJson(), 'start': start.toIso8601String(), 'end': end.toIso8601String()});
}

Future<DateTime?> _pickVisitDay(BuildContext context, RadarEvent e, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final first = DateTime(e.start.year, e.start.month, e.start.day);
  final last = DateTime(e.end.year, e.end.month, e.end.day);
  final from = first.isBefore(today) ? today : first;
  final to = last.isBefore(from) ? from : last;
  return showDatePicker(
    context: context,
    initialDate: from,
    firstDate: from,
    lastDate: to,
    helpText: context.l10n.visitDayTitle,
    confirmText: context.l10n.visitDayConfirm,
  );
}
