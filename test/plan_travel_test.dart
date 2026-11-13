import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferadar/data/alerts.dart';
import 'package:liferadar/data/plan_routes.dart';
import 'package:liferadar/data/plan_travel.dart';
import 'package:liferadar/data/providers.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _plan = Plan(
  id: 'p1',
  title: '부산 출장',
  start: DateTime(2026, 11, 20, 13),
  end: DateTime(2026, 11, 20, 15),
  locationText: '부산역',
  city: '부산',
  location: const GeoPoint(35.1151, 129.0415),
  source: 'local',
);

PlanTravel _travel({String mode = 'rail', DateTime? departure, String id = 'p1'}) => PlanTravel(
  planId: id,
  fingerprint: PlanTravel.fingerprintOf(_plan.title, _plan.start),
  mode: mode,
  lines: PlanTravel.parseLines('KTX 오송→부산'),
  originName: '오송역',
  origin: const GeoPoint(36.6203, 127.3275),
  departure: departure,
);

Insight _insight(String id, {InsightKind kind = InsightKind.planAlert}) => Insight(
  id: id,
  kind: kind,
  title: const LocalizedText(ko: '제목', en: 'Title'),
  body: const LocalizedText(ko: '본문', en: 'Body'),
  why: const LocalizedText(ko: '이유', en: 'Why'),
  confidence: 0.8,
  planId: 'p1',
);

void main() {
  test('노선 입력: 쉼표로 나누고, "→"는 방향 표시라 나누지 않는다', () {
    expect(PlanTravel.parseLines('KTX 오송→부산'), ['KTX 오송→부산']);
    expect(PlanTravel.parseLines(' 2호선, 750 / 신분당선 '), ['2호선', '750', '신분당선']);
    expect(PlanTravel.parseLines('  '), isEmpty);
  });

  test('출발 시각이 있으면 확인된 이동, 없으면 일정 2시간 전 후보 구간', () {
    final confirmed = _travel(departure: DateTime(2026, 11, 20, 10, 30)).toTrip(_plan, references: const []);
    expect(confirmed.timeConfirmed, isTrue);
    expect(confirmed.departure, DateTime(2026, 11, 20, 10, 30));
    expect(confirmed.arrival, _plan.start);
    expect(confirmed.modes, {'rail'});
    expect(confirmed.points.single.lat, closeTo(36.62, 0.01)); // 출발지

    final unknown = _travel().toTrip(_plan, references: const []);
    expect(unknown.timeConfirmed, isFalse);
    expect(unknown.departure, DateTime(2026, 11, 20, 11));

    // 일정 시작보다 늦거나 24시간보다 이른 출발은 사실로 쓰지 않는다.
    expect(_travel(departure: DateTime(2026, 11, 20, 14)).departureValidFor(_plan), isFalse);
    expect(_travel(departure: DateTime(2026, 11, 19, 9)).departureValidFor(_plan), isFalse);
  });

  test('비행기: 출발지로 대중교통 경로를 다시 찾지 않는다 (항공 정보 미연결)', () {
    final trip = _travel(mode: 'air').toTrip(_plan, references: const []);
    expect(trip.modes, {'air'});
    expect(trip.points, isEmpty);
    expect(trip.facilityIds, isEmpty);
  });

  test('저장·복원, 캘린더로 옮겨 ID가 바뀌어도 제목+시작 시각으로 찾는다', () async {
    SharedPreferences.setMockInitialValues({'session': '{"kind":"guest"}'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
    ]);
    addTearDown(c.dispose);
    c.read(plansProvider.notifier).setPlans([_plan]);

    await c.read(planTravelProvider.notifier).save(_travel(id: 'local-1'));
    // 캘린더 일정이 된 같은 일정 (ID만 다름)
    final moved = Plan(
      id: 'gcal-9', title: _plan.title, start: _plan.start, end: _plan.end,
      locationText: _plan.locationText, city: _plan.city, location: _plan.location, source: 'gcal',
    );
    expect(c.read(planTravelProvider.notifier).lookup(moved)?.mode, 'rail');

    // 새 컨테이너 = 앱 재시작
    final c2 = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
    ]);
    addTearDown(c2.dispose);
    final restored = c2.read(planTravelProvider)['local-1']!;
    expect(restored.lines, ['KTX 오송→부산']);
    expect(restored.originName, '오송역');

    // 이동 방법을 "선택 안 함"으로 바꾸면 지운다
    await c2.read(planTravelProvider.notifier).save(null, previousPlanId: 'local-1');
    expect(c2.read(planTravelProvider), isEmpty);
  });

  test('직접 적은 이동 방법은 교통 판정의 이동 맥락이 된다', () async {
    SharedPreferences.setMockInitialValues({'session': '{"kind":"guest"}'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
    ]);
    addTearDown(c.dispose);
    c.read(plansProvider.notifier).setPlans([_plan]);
    expect(c.read(tripsByPlanIdProvider), isEmpty);
    await c.read(planTravelProvider.notifier).save(_travel(mode: 'bus'));
    final trip = c.read(tripsByPlanIdProvider)['p1']!;
    expect(trip.modes, {'bus'});
    expect(trip.id, 'travel:p1');
  });

  test('알림 종류: 신호 ID로 도로·대중교통·날씨·혼잡을 나눈다', () {
    expect(alertTopicOf(_insight('rain:p1:20261120')), AlertTopic.weather);
    expect(alertTopicOf(_insight('crowd:p1:ev')), AlertTopic.crowd);
    expect(alertTopicOf(_insight('news-traffic:p1:x')), AlertTopic.road); // 마라톤·집회 통제
    expect(
      alertTopicOf(Insight(
        id: 'news-traffic:p1:y', kind: InsightKind.planAlert, confidence: 0.5,
        title: const LocalizedText(ko: '서울 지하철 파업 — 이동 안내', en: 'Strike'),
        body: const LocalizedText(ko: '', en: ''), why: const LocalizedText(ko: '', en: ''),
      )),
      AlertTopic.transit,
    );
    expect(alertTopicOf(_insight('strike:x')), AlertTopic.transit);
    expect(alertTopicOf(_insight('travel:transit:p1:n')), AlertTopic.transit);
    expect(alertTopicOf(_insight('traffic:p1:g')), AlertTopic.road);
    expect(alertTopicOf(_insight('travel:road:p1')), AlertTopic.road);
  });

  test('알림 탭은 일정 경고만 — 기회·마감은 홈에 남는다', () {
    final list = alertsFrom([
      _insight('rain:p1:1'),
      _insight('nearby:p1:ev', kind: InsightKind.opportunity),
      _insight('deadline:ev', kind: InsightKind.deadline),
      _insight('crowd:p1:ev').copyWith(feedback: InsightFeedback.hidden),
      _insight('news-traffic:p1:dup'), // 같은 일정·같은 제목 → 한 줄
    ], [_plan]);
    expect(list.map((i) => i.id), ['rain:p1:1']);
  });
}
