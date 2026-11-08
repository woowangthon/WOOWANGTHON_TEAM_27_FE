import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:liferadar_core/liferadar_core.dart';
import '../services/google_api.dart';
import '../services/kakao_api.dart';
import 'ai_insights.dart';
import 'event_feed.dart';
import 'interests.dart';
import 'live_events.dart';
import 'live_news.dart';
import 'live_traffic.dart';
import 'package:liferadar_core/demo.dart';
import 'session.dart';

export 'event_feed.dart' show EventFeed;
export 'seen.dart' show seenProvider;
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
  @override
  EventFeed build() {
    final initial = ref.watch(initialEventFeedProvider);
    if (ref.watch(liveEventsEnabledProvider)) Future.microtask(refresh);
    return initial;
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
  (ref) => [...ref.watch(eventFeedProvider).events, ...sampleEventsAt(ref.watch(nowProvider))],
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
    _base = samplePlansAt(ref.watch(nowProvider));
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

  void resetToSample() => setPlans(samplePlansAt(ref.read(nowProvider)));

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
      .where((e) => !e.isSample && !e.placeless && !e.end.isBefore(today) && e.start.isBefore(horizon))
      .toList()
    ..sort((a, b) {
      final s = taste.score(b, interests).compareTo(taste.score(a, interests));
      return s != 0 ? s : a.start.compareTo(b.start);
    });
  return [...all.where((e) => e.isSample), ...real.take(mapEventLimit)];
});

final eventByIdProvider = Provider.family<RadarEvent?, String>((ref, id) {
  for (final e in ref.watch(eventsProvider)) {
    if (e.id == id) return e;
  }
  return null;
});

/// "오늘" — 테스트에서는 고정 날짜로 override한다.
final nowProvider = Provider<DateTime>((ref) => DateTime.now());

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
    state = state.copyWith(feed: feed, its: its, itsFetchedAt: its == null ? null : DateTime.now());
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
  return Taste.from(ref.watch(insightFeedbackProvider), events);
});

/// 규칙 기반 인사이트 = InsightEngine(일정, 행사, 관심사, 날씨).
/// 입력이 하나라도 바뀌면 자동으로 다시 계산한다.
final baseInsightsProvider = Provider<List<Insight>>((ref) {
  final plans = ref.watch(plansProvider);
  final now = ref.watch(nowProvider);
  final today = DateTime(now.year, now.month, now.day);

  // 10일 예보 범위 안의 일정에 대한 날씨 (캐시된 provider 사용).
  final weather = <String, DailyWeather>{};
  for (final p in plans) {
    if (p.location == null) continue;
    final day = DateTime(p.start.year, p.start.month, p.start.day);
    final ahead = day.difference(today).inDays;
    if (ahead < 0 || ahead > 9) continue;
    final days = ref.watch(forecastProvider(forecastKey(p.location!, 'ko'))).value;
    final w = days?.where((d) => d.date == day).firstOrNull;
    if (w != null) weather[p.id] = w;
  }

  return const InsightEngine().build(
    plans: plans,
    events: ref.watch(eventsProvider),
    interests: ref.watch(interestsProvider),
    now: now,
    weatherByPlanId: weather,
    taste: ref.watch(tasteProvider),
    traffic: ref.watch(trafficFeedProvider).activeAt(now),
    strikes: ref.watch(newsFeedProvider).active,
  );
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
