import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notify/notify.dart';
import '../l10n/app_localizations.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'providers.dart';
import 'session.dart';

/// 알림 사용 여부 (프로필 → 설정). 브라우저 권한도 있어야 한다.
final notificationsEnabledProvider =
    NotifierProvider<NotificationsController, bool>(NotificationsController.new);

class NotificationsController extends Notifier<bool> {
  static const _key = 'notify_enabled';

  @override
  bool build() => (ref.read(sharedPrefsProvider).getBool(_key) ?? false) && notifyPermission() == 'granted';

  /// 권한을 요청해 켠다. 결과: 'granted' | 'denied' | 'default' | 'unsupported'.
  Future<String> enable() async {
    final r = notifyPermission() == 'granted' ? 'granted' : await requestNotifyPermission();
    if (r == 'granted') {
      state = true;
      await ref.read(sharedPrefsProvider).setBool(_key, true);
    }
    return r;
  }

  Future<void> disable() async {
    state = false;
    await ref.read(sharedPrefsProvider).setBool(_key, false);
  }
}

/// 새 중요 신호를 시스템 알림으로 보낸다 — 신호마다 한 번만.
/// 중요 = 2일 이내 마감 또는 3일 이내 일정에 관한 경고.
class SignalNotifier {
  SignalNotifier(this.ref);
  final Ref ref;

  static const _maxPerRun = 3;
  static const _keep = 300;

  String get _key => 'notified:${accountScope(ref.read(sessionProvider))}';

  void dispatch(List<Insight> insights) {
    if (!ref.read(notificationsEnabledProvider)) return;
    final prefs = ref.read(sharedPrefsProvider);
    final sent = prefs.getStringList(_key) ?? const [];
    final now = ref.read(nowProvider);
    final today = DateTime(now.year, now.month, now.day);
    final plans = {for (final p in ref.read(plansProvider)) p.id: p};

    bool important(Insight i) {
      if (i.feedback == InsightFeedback.dislike || i.feedback == InsightFeedback.hidden) return false;
      // 근처 대형 행사 — 참고 정보일 뿐 (교통 영향 미확인): 알림 없음.
      if (i.id.startsWith('crowd:')) return false;
      if (i.kind == InsightKind.deadline) {
        final e = i.eventIds.isEmpty ? null : ref.read(eventByIdProvider(i.eventIds.first));
        final d = e?.deadline;
        if (d == null) return false;
        final left = DateTime(d.year, d.month, d.day).difference(today).inDays;
        return left >= 0 && left <= 2;
      }
      if (i.kind == InsightKind.planAlert) {
        final plan = plans[i.planId];
        if (plan == null) return false;
        final until = DateTime(plan.start.year, plan.start.month, plan.start.day).difference(today).inDays;
        return until >= 0 && until <= 3;
      }
      return false;
    }

    final fresh = insights.where((i) => !sent.contains(i.id) && important(i)).take(_maxPerRun).toList();
    if (fresh.isEmpty) return;

    final lang = _lang();
    final l10n = lookupAppLocalizations(Locale(lang));
    for (final i in fresh) {
      final kind = switch (i.kind) {
        InsightKind.deadline => l10n.kindDeadline,
        InsightKind.planAlert => l10n.kindPlanAlert,
        InsightKind.opportunity => l10n.kindOpportunity,
        InsightKind.route => l10n.kindRoute,
      };
      showSystemNotification('$kind · ${i.title.of(lang)}', i.body.of(lang), tag: i.id);
    }
    final all = [...sent, ...fresh.map((i) => i.id)];
    prefs.setStringList(_key, all.length > _keep ? all.sublist(all.length - _keep) : all);
  }

  /// 테스트 알림 (프로필의 버튼).
  void test() {
    final l10n = lookupAppLocalizations(Locale(_lang()));
    showSystemNotification('LifeRadar', l10n.notifyTestBody, tag: 'test');
  }

  String _lang() {
    final code = ref.read(localeProvider)?.languageCode ?? PlatformDispatcher.instance.locale.languageCode;
    return code == 'ko' ? 'ko' : 'en';
  }
}

final signalNotifierProvider = Provider<SignalNotifier>(SignalNotifier.new);
