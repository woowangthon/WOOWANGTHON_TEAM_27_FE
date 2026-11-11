import 'dart:ui' show Locale, PlatformDispatcher;
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notify/notify.dart';
import '../l10n/app_localizations.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'providers.dart';
import 'session.dart';

typedef SystemNotificationSender = Future<bool> Function(String title, String body, {String? tag});
final systemNotificationSenderProvider = Provider<SystemNotificationSender>((ref) => showSystemNotification);

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
  bool _dispatching = false;
  List<Insight>? _pending;

  static const _maxPerRun = 3;
  static const _keep = 300;

  String get _key => 'notified:${accountScope(ref.read(sessionProvider))}';

  Future<void> dispatch(List<Insight> insights) async {
    if (_dispatching) { _pending = insights; return; }
    if (!ref.read(notificationsEnabledProvider)) return;
    _dispatching = true;
    try {
    final prefs = ref.read(sharedPrefsProvider);
    final accountKey = _key;
    final sent = prefs.getStringList(accountKey) ?? const [];
    final now = ref.read(nowProvider);
    final today = DateTime(now.year, now.month, now.day);
    final plans = {for (final p in ref.read(plansProvider)) p.id: p};

    bool important(Insight i) {
      if (ref.read(liveEventsEnabledProvider) &&
          (plans[i.planId]?.source == 'sample' ||
            i.eventIds.any((id) => ref.read(eventByIdProvider(id))?.isSample == true))) return false;
      if (i.feedback == InsightFeedback.dislike || i.feedback == InsightFeedback.hidden) return false;
      if (i.notificationEligible == false) return false;
      // Corrections are allowed even if the edited appointment is now in the past.
      if (i.notificationEligible == true && i.notificationKey != null) {
        final tuple = _trafficKey(i.notificationKey!);
        if (tuple != null && tuple[3] == 'resolved') {
          // No new system correction for a regional reference that never sent
          // a warning. Match the same schedule + impact, across older versions.
          return sent.any((key) {
            final old = _trafficKey(key);
            return old != null && old[0] == tuple[0] && old[1] == tuple[1] &&
                (old[3] == 'recommend' || old[3] == 'caution');
          });
        }
      }
      // 근처 대형 행사 — 참고 정보일 뿐 (교통 영향 미확인): 알림 없음.
      if (i.id.startsWith('crowd:')) return false;
      // 뉴스 보도 기반 파업 — 공식 공지가 아니므로 참고 카드만, 알림 없음.
      if (i.id.startsWith('strike:')) return false;
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

    final fresh = insights.where((i) => !sent.contains(i.notificationKey ?? i.id) && important(i)).take(_maxPerRun).toList();
    if (fresh.isEmpty) return;

    final lang = _lang();
    final l10n = lookupAppLocalizations(Locale(lang));
    final delivered = <String>[];
    for (final i in fresh) {
      if (!ref.mounted || _key != accountKey || !ref.read(notificationsEnabledProvider)) break;
      final kind = switch (i.kind) {
        InsightKind.deadline => l10n.kindDeadline,
        InsightKind.planAlert => l10n.kindPlanAlert,
        InsightKind.opportunity => l10n.kindOpportunity,
        InsightKind.route => l10n.kindRoute,
      };
      if (await ref.read(systemNotificationSenderProvider)('$kind · ${i.title.of(lang)}', i.body.of(lang), tag: i.id)) {
        delivered.add(i.notificationKey ?? i.id);
      }
    }
    final all = [...sent, ...delivered];
    if (delivered.isNotEmpty) await prefs.setStringList(accountKey, all.length > _keep ? all.sublist(all.length - _keep) : all);
    } finally {
      _dispatching = false;
      final pending = _pending;
      _pending = null;
      if (pending != null && ref.mounted) unawaited(dispatch(pending));
    }
  }

  /// 테스트 알림 (프로필의 버튼).
  Future<void> test() async {
    final l10n = lookupAppLocalizations(Locale(_lang()));
    await ref.read(systemNotificationSenderProvider)('LifeRadar', l10n.notifyTestBody, tag: 'test');
  }

  String _lang() {
    final code = ref.read(localeProvider)?.languageCode ?? PlatformDispatcher.instance.locale.languageCode;
    return code == 'ko' ? 'ko' : 'en';
  }

  static List<dynamic>? _trafficKey(String key) {
    try {
      final value = jsonDecode(key);
      return value is List && value.length == 4 ? value : null;
    } catch (_) { return null; }
  }
}

final signalNotifierProvider = Provider<SignalNotifier>(SignalNotifier.new);
