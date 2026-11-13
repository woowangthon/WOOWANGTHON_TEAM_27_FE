import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferadar_core/liferadar_core.dart';

import '../../core/confirm.dart';
import '../../core/errors.dart';
import '../../core/l10n_ext.dart';
import '../../core/toast.dart';
import '../../data/calendar_controller.dart';
import '../../data/providers.dart';

/// 일정 삭제 (확인 후). Google 캘린더 일정은 캘린더에서도 지우고, 직접 만든 일정은 기기에서 지운다.
/// 상세 창·목록 밀기·수정 창이 같은 흐름을 쓴다. 지웠으면 true.
Future<bool> deletePlanWithConfirm(BuildContext context, WidgetRef ref, Plan plan) async {
  if (!plan.isEditable) return false;
  final l10n = context.l10n;
  final ok = await showConfirm(
    context,
    icon: Icons.delete_outline_rounded,
    title: l10n.planDeleteConfirm(plan.title),
    body: plan.source == 'gcal' ? l10n.planDeleteCalendarNote : null,
    confirmLabel: l10n.delete,
    cancelLabel: l10n.cancel,
    destructive: true,
  );
  if (!ok) return false;
  try {
    if (plan.source == 'gcal') {
      // 목록에서 바로 지우고(deletePlan이 먼저 지운다) 캘린더 요청은 뒤에서.
      // 실패하면 일정이 다시 나타나고 토스트가 오류로 바뀐다.
      unawaited(ref.read(calendarProvider.notifier).deletePlan(plan).catchError((Object e) {
        Toast.show(l10n.planSaveError(friendlyError(l10n, e)), type: ToastType.error);
      }));
    } else {
      await ref.read(plansProvider.notifier).removeLocal(plan.id);
    }
    Toast.show(l10n.planDeleted, type: ToastType.info);
    return true;
  } catch (e) {
    Toast.show(l10n.planSaveError(friendlyError(l10n, e)), type: ToastType.error);
    return false;
  }
}


/// 캘린더 다시 불러오기 + 결과 토스트 (동기화 버튼·당겨서 새로 고침).
Future<void> syncCalendarWithToast(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  Toast.progress(l10n.calendarSyncing);
  await ref.read(calendarProvider.notifier).sync();
  final s = ref.read(calendarProvider);
  if (s.status == CalendarStatus.error) {
    Toast.show(
      s.error == 'expired' ? l10n.calendarExpiredToast : l10n.calendarErrorToast,
      type: s.error == 'expired' ? ToastType.warning : ToastType.error,
    );
  } else {
    Toast.show(l10n.calendarSyncedToast, type: ToastType.info);
  }
}
