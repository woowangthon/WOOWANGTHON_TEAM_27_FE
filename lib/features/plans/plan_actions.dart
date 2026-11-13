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
  // 1) 토스트가 먼저 (같은 프레임), 2) 확인 창이 닫히는 첫 프레임이 그려진 뒤에 지운다 —
  // 목록·신호 다시 계산이 닫히는 애니메이션과 겹쳐 멈춘 것처럼 보이지 않게.
  // 3) 캘린더 요청은 뒤에서. 실패하면 일정이 돌아오고 토스트가 오류로 바뀐다.
  final plans = ref.read(plansProvider.notifier);
  final calendar = ref.read(calendarProvider.notifier);
  Toast.show(l10n.planDeleted, type: ToastType.info);
  unawaited(() async {
    await WidgetsBinding.instance.endOfFrame;
    try {
      if (plan.source == 'gcal') {
        await calendar.deletePlan(plan);
      } else {
        await plans.removeLocal(plan.id);
      }
    } catch (e) {
      Toast.show(l10n.planSaveError(friendlyError(l10n, e)), type: ToastType.error);
    }
  }());
  return true;
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
