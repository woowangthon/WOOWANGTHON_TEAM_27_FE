import 'package:flutter/material.dart' show IconData, Icons;
import 'package:liferadar_core/liferadar_core.dart';

/// 알림 종류 — 신호 ID의 앞부분으로 정한다 (규칙 엔진이 붙이는 이름).
enum AlertTopic { road, transit, weather, crowd }

AlertTopic alertTopicOf(Insight i) {
  final id = i.id;
  if (id.startsWith('rain:')) return AlertTopic.weather;
  if (id.startsWith('crowd:')) return AlertTopic.crowd;
  if (id.startsWith('strike:') || id.startsWith('travel:transit:')) return AlertTopic.transit;
  // 뉴스 교통 영향은 종류가 섞여 있다: 파업·운행 중단은 대중교통, 마라톤·집회·행사 통제는 도로.
  if (id.startsWith('news-traffic:') && _transitWords.hasMatch(i.title.ko)) return AlertTopic.transit;
  return AlertTopic.road;
}

final _transitWords = RegExp(r'파업|운행|지하철|전철|버스|열차|철도|KTX|SRT');

IconData alertTopicIcon(AlertTopic t) => switch (t) {
  AlertTopic.road => Icons.traffic_rounded,
  AlertTopic.transit => Icons.directions_subway_rounded,
  AlertTopic.weather => Icons.umbrella_rounded,
  AlertTopic.crowd => Icons.groups_rounded,
};

/// 홈의 "소식"과 섞이지 않도록, 일정에 대한 경고(planAlert)만 알림 탭에 모은다.
bool isAlert(Insight i) => i.kind == InsightKind.planAlert;

/// 알림 탭: 숨기지 않은 일정 경고, 일정 시작이 이른 순.
/// (파생 provider로 만들지 않는다 — 가려진 탭이 다시 보일 때 build 중 갱신 오류가 난다.)
List<Insight> alertsFrom(List<Insight> insights, List<Plan> plans) {
  final byId = {for (final p in plans) p.id: p};
  // 같은 일정에 같은 제목의 경고(예: 같은 마라톤을 다룬 기사 두 개)는 한 줄로.
  final seen = <String>{};
  final list = [
    for (final i in insights)
      if (isAlert(i) && i.feedback != InsightFeedback.hidden && seen.add('${i.planId}|${i.title.ko}')) i,
  ];
  DateTime startOf(Insight i) => byId[i.planId]?.start ?? DateTime(9999);
  list.sort((a, b) => startOf(a).compareTo(startOf(b)));
  return list;
}
