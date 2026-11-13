import 'dart:convert';
import 'dart:async';
import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:liferadar_core/liferadar_core.dart';
import '../services/google_api.dart';
import '../services/kakao_api.dart';
import 'ai_insights.dart';
import 'event_feed.dart';
import 'interests.dart';
import 'profile.dart';
import 'live_events.dart';
import 'live_news.dart';
import 'live_traffic.dart';
import 'package:liferadar_core/demo.dart';
import 'session.dart';
import 'plan_routes.dart';
import 'news_traffic.dart';
import 'travel_impact.dart';
import 'weekly_contests.dart';
import 'contest_background.dart';

export 'event_feed.dart' show EventFeed;
export 'seen.dart' show seenProvider;
export 'profile.dart';
export 'interests.dart'
    show interestsProvider, interestOptions, InterestOption, InterestGroup, interestByTag, sharedPrefsProvider, accountScope;

final kakaoApiProvider = Provider<KakaoApi>((ref) => KakaoApi());
final googleApiProvider = Provider<GoogleApi>((ref) => GoogleApi());



/// 앱 시작 시 행사 — main()에서 에셋/캐시로 로드해 override한다 (테스트에서는 비어 있음).
final initialEventFeedProvider = Provider<EventFeed>((ref) => EventFeed.empty);

/// 인터넷 갱신 사용 여부 (main()에서 true; 테스트는 네트워크를 쓰지 않는다).
final liveEventsEnabledProvider = Provider<bool>((ref) => false);

/// 실제 행사: 먼저 [initialEventFeedProvider], 이후 인터넷의 더 최신 피드 (있으면).
final eventFeedProvider = NotifierProvider<EventFeedController, EventFeed>(EventFeedController.new);

class EventFeedController extends Notifier<EventFeed> {
  WeeklyContests? _contests;
  @override
  EventFeed build() {
    final initial = ref.watch(initialEventFeedProvider);
    if (ref.watch(liveEventsEnabledProvider)) {
      _contests = WeeklyContests(ref.read(sharedPrefsProvider), seed: initial);
      Future.microtask(refresh);
      Future.microtask(refreshContests);
      final timer = Timer.periodic(const Duration(minutes: 5), (_) => refreshContests());
      final lifecycle = AppLifecycleListener(onResume: refreshContests);
      ref.onDispose(() { timer.cancel(); lifecycle.dispose(); });
      final cached = _contests!.cached();
      if (cached != null) return initial.withMissingContestSourceFrom(cached);
    }
    return initial;
  }

  Future<void> refreshContests() async {
    final collector = _contests;
    if (collector == null) return;
    try {
      final collected = await ContestBackground.collect(collector);
      await collector.prefs.reload();
      final fresh = collected ?? collector.cached();
      if (fresh != null && ref.mounted) state = state.withMissingContestSourceFrom(fresh);
    } catch (error) {
      debugPrint('Contest refresh: ${error.runtimeType}');
    }
  }

  /// 새 피드가 있으면 교체한다. 결과: 갱신 여부.
  Future<bool> refresh() async {
    final fresh = await LiveEvents.fetch(ref.read(sharedPrefsProvider), state);
    if (fresh == null || !ref.mounted) return false;
    state = fresh;
    return true;
  }
}

/// 전체 행사: 실제(공개 API) + 데모 시나리오용 샘플 ("Sample" 배지).
final eventsProvider = Provider<List<RadarEvent>>(
  (ref) => [...ref.watch(eventFeedProvider).events,
    if (!ref.watch(liveEventsEnabledProvider)) ...sampleEventsAt(ref.watch(nowProvider))],
);

/// 일정 = 기본 출처 (Google 캘린더 연결 전에는 샘플, 이후 캘린더)
/// + 앱에서 직접 만든 일정 (기기에 계정별 저장).
/// 같은 id의 직접 만든 일정이 기본 출처의 일정을 대체한다 (예: 수정한 샘플).
final plansProvider = NotifierProvider<PlansController, List<Plan>>(PlansController.new);

class PlansController extends Notifier<List<Plan>> {
  List<Plan> _base = samplePlans;
  List<Plan> _own = const [];
  late String _key;

  @override
  List<Plan> build() {
    _key = 'plans:${accountScope(ref.watch(sessionProvider))}';
    // Clock ticks must not replace synchronized calendar plans with samples.
    _base = ref.read(liveEventsEnabledProvider) ? const [] : samplePlansAt(ref.read(nowProvider));
    _own = _load();
    return _merge();
  }

  List<Plan> _load() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return [for (final j in jsonDecode(raw) as List) Plan.fromJson(j as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }

  List<Plan> _merge() {
    final ownIds = {for (final p in _own) p.id};
    return [..._base.where((p) => !ownIds.contains(p.id)), ..._own]..sort((a, b) => a.start.compareTo(b.start));
  }

  Future<void> _persist() async {
    state = _merge();
    await ref.read(sharedPrefsProvider).setString(_key, jsonEncode([for (final p in _own) p.toJson()]));
  }

  void setPlans(List<Plan> plans) {
    _base = plans;
    state = _merge();
  }

  void resetToSample() => setPlans(ref.read(liveEventsEnabledProvider) ? const [] : samplePlansAt(ref.read(nowProvider)));

  /// 앱에서 만든 일정을 추가하거나 수정한다 (source = 'local').
  Future<void> saveLocal(Plan plan) async {
    final p = plan.copyWith(source: 'local');
    _own = [..._own.where((x) => x.id != p.id), p];
    await _persist();
  }

  Future<void> removeLocal(String id) async {
    _own = _own.where((x) => x.id != id).toList();
    await _persist();
  }
}

/// 지도의 "Recommended" 레이어: 30일 이내, 관심사에 가장 맞는 행사 [mapEventLimit]개.
/// 샘플은 데모 시나리오를 위해 항상 유지한다.
const mapEventLimit = 60;
final mapEventsProvider = Provider<List<RadarEvent>>((ref) {
  final now = ref.watch(nowProvider);
  final today = DateTime(now.year, now.month, now.day);
  final horizon = today.add(const Duration(days: 30));
  final interests = ref.watch(interestsProvider);
  final taste = ref.watch(tasteProvider);
  final all = ref.watch(eventsProvider);
  final real = all
      .where((e) => !e.isSample && !e.placeless && e.applicationVisible(now) &&
          !e.end.isBefore(today) && e.start.isBefore(horizon))
      .toList()
    ..sort((a, b) {
      final s = taste.score(b, interests).compareTo(taste.score(a, interests));
      return s != 0 ? s : a.start.compareTo(b.start);
    });
  return [...all.where((e) => e.isSample), ...real.take(mapEventLimit)];
});

/// Physical contest sessions have their own map layer, independent of the
/// recommendation limit. Reception dates never stand in for venue dates.
final mapContestEventsProvider = Provider<List<RadarEvent>>((ref) {
  final now = ref.watch(nowProvider);
  final today = DateTime(now.year, now.month, now.day);
  final horizon = today.add(const Duration(days: 90));
  return ref.watch(eventsProvider).where((e) => e.isApplication && !e.isSample &&
      !e.placeless && e.applicationVisible(now) && !e.end.isBefore(today) &&
      e.start.isBefore(horizon) && e.location.lat.isFinite && e.location.lng.isFinite &&
      e.location.lat >= 33 && e.location.lat <= 39 && e.location.lng >= 124 && e.location.lng <= 132)
      .toList()..sort((a,b) => a.start.compareTo(b.start));
});

final eventByIdProvider = Provider.family<RadarEvent?, String>((ref, id) {
  for (final e in ref.watch(eventsProvider)) {
    if (e.id == id) return e;
  }
  return null;
});

/// "오늘" — 테스트에서는 고정 날짜로 override한다.
final _clockProvider = StreamProvider<DateTime>((ref) =>
    Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now()));
final nowProvider = Provider<DateTime>((ref) {
  ref.watch(_clockProvider);
  return DateTime.now();
});

/// 사용자 피드백 (인사이트 id → like/dislike/hidden), 기기에 저장.
final insightFeedbackProvider =
    NotifierProvider<InsightFeedbackController, Map<String, InsightFeedback>>(InsightFeedbackController.new);

class InsightFeedbackController extends Notifier<Map<String, InsightFeedback>> {
  static const _key = 'insight_feedback';

  @override
  Map<String, InsightFeedback> build() {
    final raw = ref.read(sharedPrefsProvider).getStringList(_key) ?? const [];
    return {
      for (final r in raw)
        if (r.contains('|'))
          r.substring(0, r.lastIndexOf('|')): InsightFeedback.values.byName(r.substring(r.lastIndexOf('|') + 1)),
    };
  }

  Future<void> set(String id, InsightFeedback f) async {
    state = {...state, id: f};
    await _persist();
  }

  /// 평가 취소 (👍/👎 해제).
  Future<void> clear(String id) async {
    state = {...state}..remove(id);
    await _persist();
  }

  Future<void> _persist() => ref
      .read(sharedPrefsProvider)
      .setStringList(_key, [for (final e in state.entries) '${e.key}|${e.value.name}']);
}

/// 공식 교통 영향: 먼저 캐시, 이후 인터넷의 더 최신 데이터.
final trafficFeedProvider = NotifierProvider<TrafficFeedController, TrafficFeed>(TrafficFeedController.new);

class TrafficFeedController extends Notifier<TrafficFeed> {
  @override
  TrafficFeed build() {
    final cached = LiveTraffic.cached(ref.read(sharedPrefsProvider));
    if (ref.watch(liveEventsEnabledProvider)) Future.microtask(refresh);
    return cached;
  }

  /// `traffic.json`(서울)과 ITS(전국)를 함께 받는다. 하나가 실패해도 다른 쪽은 반영한다.
  Future<bool> refresh() async {
    final prefs = ref.read(sharedPrefsProvider);
    final (feed, its) = await (LiveTraffic.fetch(prefs, state), LiveTraffic.fetchIts(prefs)).wait;
    if ((feed == null && its == null) || !ref.mounted) return false;
    state = state.copyWith(feed: feed, its: its, itsFetchedAt: its == null ? null : DateTime.now().toUtc());
    return true;
  }
}

/// 뉴스 판독 파업: 먼저 캐시, 이후 인터넷의 더 최신 데이터.
final newsFeedProvider = NotifierProvider<NewsFeedController, NewsFeed>(NewsFeedController.new);

class NewsFeedController extends Notifier<NewsFeed> {
  @override
  NewsFeed build() {
    final cached = LiveNews.cached(ref.read(sharedPrefsProvider));
    if (ref.watch(liveEventsEnabledProvider)) Future.microtask(refresh);
    return cached;
  }

  Future<bool> refresh() async {
    final fresh = await LiveNews.fetch(ref.read(sharedPrefsProvider), state);
    if (fresh == null || !ref.mounted) return false;
    state = fresh;
    return true;
  }
}

/// 피드백으로 학습한 취향: 홈, 발견, 지도, 경로의 순서에 반영된다.
final tasteProvider = Provider<Taste>((ref) {
  final events = {for (final e in ref.watch(eventsProvider)) e.id: e};
  // 지금 상황(학생·구직…)에 맞는 행사를 조금 올린다.
  return Taste.from(ref.watch(insightFeedbackProvider), events).withStage(ref.watch(lifeStageProvider));
});

/// 일정별 날씨 (10일 예보 범위 안). 예보는 장소마다 따로 도착하므로 0.4초 동안 모아
/// 한 번에 바꾼다 — 일정이 많으면 도착할 때마다 엔진을 다시 돌려 화면이 멈췄다.
final planWeatherProvider = NotifierProvider<PlanWeatherController, Map<String, DailyWeather>>(PlanWeatherController.new);

class PlanWeatherController extends Notifier<Map<String, DailyWeather>> {
  Timer? _timer;
  String _signature = '';

  @override
  Map<String, DailyWeather> build() {
    final plans = ref.watch(plansProvider);
    final now = ref.watch(nowProvider);
    ref.onDispose(() => _timer?.cancel());
    for (final k in _keys(plans, now)) {
      ref.listen(forecastProvider(k), (_, _) => _schedule());
    }
    final value = _read(plans, now);
    _signature = _sign(value);
    return value;
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), () {
      if (!ref.mounted) return;
      final value = _read(ref.read(plansProvider), ref.read(nowProvider));
      final sig = _sign(value);
      if (sig == _signature) return; // 같은 내용이면 다시 계산하지 않는다
      _signature = sig;
      state = value;
    });
  }

  static Iterable<(Plan, DateTime, ForecastKey)> _eligible(List<Plan> plans, DateTime now) sync* {
    final today = DateTime(now.year, now.month, now.day);
    for (final p in plans) {
      if (p.location == null) continue;
      final day = DateTime(p.start.year, p.start.month, p.start.day);
      final ahead = day.difference(today).inDays;
      if (ahead < 0 || ahead > 9) continue;
      yield (p, day, forecastKey(p.location!, 'ko'));
    }
  }

  static Set<ForecastKey> _keys(List<Plan> plans, DateTime now) => {for (final e in _eligible(plans, now)) e.$3};

  Map<String, DailyWeather> _read(List<Plan> plans, DateTime now) {
    final out = <String, DailyWeather>{};
    for (final (p, day, k) in _eligible(plans, now)) {
      final w = ref.read(forecastProvider(k)).value?.where((d) => d.date == day).firstOrNull;
      if (w != null) out[p.id] = w;
    }
    return out;
  }

  static String _sign(Map<String, DailyWeather> m) =>
      [for (final e in m.entries) '${e.key}:${e.value.date}:${e.value.rainChance}:${e.value.likelyRain}'].join('|');
}

/// 규칙 엔진 결과 (일정·행사·관심사·날씨·교통 통제·파업). 가장 무거운 계산이라
/// 교통 영향 확인 결과처럼 자주 바뀌는 값은 여기에 넣지 않고 아래에서 합친다.
final engineInsightsProvider = Provider<List<Insight>>((ref) {
  final plans = ref.watch(plansProvider);
  final now = ref.watch(nowProvider);
  final news = ref.watch(newsFeedProvider);
  final verifiedStrikeSources = {for (final impact in news.trafficImpacts) if (impact.type == 'STRIKE') impact.sourceUrl};
  return const InsightEngine().build(
    plans: plans,
    events: ref.watch(eventsProvider),
    interests: ref.watch(interestsProvider),
    now: now,
    weatherByPlanId: ref.watch(planWeatherProvider),
    taste: ref.watch(tasteProvider),
    traffic: ref.watch(trafficFeedProvider).activeAt(now.toUtc()),
    trafficNow: now.toUtc(),
    strikes: news.active.where((s) => !verifiedStrikeSources.contains(s.url)).toList(),
    tripsByPlanId: ref.watch(tripsByPlanIdProvider),
  );
});

/// 규칙 기반 인사이트 = 엔진 결과 + 일정별 교통 영향 확인 + 뉴스 교통 판정.
final baseInsightsProvider = Provider<List<Insight>>((ref) {
  final plans = ref.watch(plansProvider);
  final now = ref.watch(nowProvider);
  final regular = ref.watch(engineInsightsProvider);
  return InsightEngine.rank([
    ...{for (final i in [
      ...regular,
      for (final entry in ref.watch(travelImpactProvider).entries)
        if (plans.any((p) => p.id == entry.key && p.source != 'sample' &&
            entry.value.matches(p, ref.watch(tripsByPlanIdProvider)[p.id])) &&
            now.difference(entry.value.checkedAt) < const Duration(minutes: 10))
          ...entry.value.insights,
    ]) i.id: i}.values,
    for (final evaluation in ref.watch(newsTrafficDecisionsProvider))
      if (evaluation.visible) evaluation.toInsight(),
  ]);
});

/// 홈의 인사이트 = 규칙 카드 + Gemini 문장(있으면) + 피드백.
final insightsProvider = Provider<List<Insight>>((ref) {
  final ai = ref.watch(aiInsightTextProvider);
  final feedback = ref.watch(insightFeedbackProvider);
  final withFeedback = [
    for (final i in ref.watch(baseInsightsProvider))
      switch (ai[i.id]) {
        final w? => i.copyWith(feedback: feedback[i.id], body: w.body, why: w.why, aiModel: w.model),
        null => i.copyWith(feedback: feedback[i.id]),
      },
  ];
  // 👎 누른 카드는 아래로.
  return [
    ...withFeedback.where((i) => i.feedback != InsightFeedback.dislike),
    ...withFeedback.where((i) => i.feedback == InsightFeedback.dislike),
  ];
});

/// 홈/발견에서 "지도에서 보기"를 누르면 지도가 해당 행사로 이동한다.
final mapFocusProvider = NotifierProvider<MapFocusController, String?>(MapFocusController.new);

class MapFocusController extends Notifier<String?> {
  @override
  String? build() => null;

  void focus(String? eventId) => state = eventId;
}

/// 행사가 관심사와 얼마나 맞는지 (0..1).
double interestScore(RadarEvent event, Set<String> interests) {
  if (event.tags.isEmpty) return 0;
  final hits = event.tags.where(interests.contains).length;
  return hits / event.tags.length;
}

/// 예보 키: 좌표를 약 1 km 정밀도로 반올림한다 (가까운 장소는 같은 요청을 공유).
typedef ForecastKey = ({double lat, double lng, String lang});

ForecastKey forecastKey(GeoPoint p, String lang) =>
    (lat: (p.lat * 100).round() / 100, lng: (p.lng * 100).round() / 100, lang: lang);

/// 10일 예보 — Riverpod이 캐시한다 (장소당 한 번 요청).
final forecastProvider = FutureProvider.family<List<DailyWeather>, ForecastKey>((ref, k) {
  return ref.read(googleApiProvider).dailyForecast(GeoPoint(k.lat, k.lng), lang: k.lang);
});

/// 앱 버전 "1.0.0 (2)" — pubspec.yaml의 version.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty ? info.version : '${info.version} (${info.buildNumber})';
});
