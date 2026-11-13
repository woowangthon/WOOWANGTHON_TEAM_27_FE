import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferadar_core/liferadar_core.dart';

import '../../core/l10n_ext.dart';
import '../../core/toast.dart';
import '../../data/calendar_controller.dart';
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
  try {
    await ref.read(calendarProvider.notifier).addEvent(target, title: title);
    Toast.show(l10n.addedToCalendar);
    return true;
  } catch (e) {
    final notConfigured = e.toString().contains('not-configured');
    Toast.show(
      notConfigured ? l10n.calendarNotConfigured : l10n.calendarAddFailed,
      type: notConfigured ? ToastType.warning : ToastType.error,
    );
    return false;
  }
}
