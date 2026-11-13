import 'dart:convert';

import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferadar_core/liferadar_core.dart';

import 'providers.dart';
import 'session.dart';

/// 사용자가 일정에 직접 적은 이동 방법. 'air'는 앱 안에서만 쓰는 값이다
/// (항공 운항 정보는 아직 연결하지 않았으므로 알림 근거로 쓰지 않는다).
const planTravelModes = ['bus', 'subway', 'rail', 'air', 'car'];

IconData planTravelIcon(String mode) => switch (mode) {
  'bus' => Icons.directions_bus_rounded,
  'subway' => Icons.subway_rounded,
  'rail' => Icons.train_rounded,
  'air' => Icons.flight_rounded,
  _ => Icons.directions_car_rounded,
};

/// 일정 하나에 대해 사용자가 직접 입력한 이동 정보.
/// 앞뒤 일정 사이에 저장한 경로(PlanRoute)가 있으면 그쪽이 우선한다.
class PlanTravel {
  const PlanTravel({
    required this.planId,
    required this.fingerprint,
    required this.mode,
    this.lines = const [],
    this.originName,
    this.origin,
    this.departure,
  });

  final String planId, fingerprint, mode;
  final List<String> lines;
  final String? originName;
  final GeoPoint? origin;
  final DateTime? departure;

  /// 캘린더로 저장하면 일정 ID가 바뀌므로, 제목+시작 시각으로도 찾는다.
  static String fingerprintOf(String title, DateTime start) =>
      jsonEncode([title.trim(), start.toLocal().toIso8601String()]);

  /// "2호선, 750" 같은 입력을 노선 목록으로 나눈다. "→"는 방향 표시라 나누지 않는다.
  static List<String> parseLines(String text) => [
    for (final part in text.split(RegExp(r'[,，/·]')))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  /// 출발 시각은 일정 시작 전 24시간 안에서만 확인된 사실로 쓴다.
  bool departureValidFor(Plan plan) {
    final d = departure;
    if (d == null) return false;
    return !d.isAfter(plan.start) &&
        plan.start.difference(d) <= const Duration(hours: 24);
  }

  /// 교통 판정에 넘길 이동 맥락. 출발 시각이 없으면 일정 시작 2시간 전부터를
  /// 후보 구간으로만 쓴다(timeConfirmed: false) — 없는 출발 시각을 지어내지 않는다.
  TripContext toTrip(
    Plan plan, {
    required List<TrafficReference> references,
  }) {
    final confirmed = departureValidFor(plan);
    final from = confirmed
        ? departure!
        : plan.start.subtract(const Duration(hours: 2));
    final anchor = plan.location ?? origin;
    final ids = anchor == null || mode == 'air' || mode == 'car'
        ? <String>{}
        : resolveTripFacilityIds(
            lines: lines,
            modes: {mode},
            region: KoreaRegions.regionOf(anchor),
            departure: from,
            demo: plan.source == 'sample',
            references: references,
          );
    return TripContext(
      id: 'travel:${plan.id}',
      version: jsonEncode([toJson(), (ids.toList()..sort())]),
      departure: from,
      arrival: plan.start,
      timeConfirmed: confirmed,
      modes: {mode},
      lines: lines,
      facilityIds: ids,
      // 항공편은 대중교통 경로로 다시 찾지 않도록 출발지를 넘기지 않는다.
      points: [if (origin != null && mode != 'air') origin!],
    );
  }

  Map<String, dynamic> toJson() => {
    'planId': planId,
    'fingerprint': fingerprint,
    'mode': mode,
    'lines': lines,
    if (originName != null) 'originName': originName,
    if (origin != null) 'lat': origin!.lat,
    if (origin != null) 'lng': origin!.lng,
    if (departure != null) 'departure': departure!.toIso8601String(),
  };

  factory PlanTravel.fromJson(Map<String, dynamic> j) {
    final mode = j['mode'] as String;
    if (!planTravelModes.contains(mode)) {
      throw const FormatException('Invalid travel mode');
    }
    return PlanTravel(
      planId: j['planId'] as String,
      fingerprint: j['fingerprint'] as String,
      mode: mode,
      lines: (j['lines'] as List? ?? const []).cast<String>(),
      originName: j['originName'] as String?,
      origin: j['lat'] is num && j['lng'] is num
          ? GeoPoint((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble())
          : null,
      departure: j['departure'] == null
          ? null
          : DateTime.parse(j['departure'] as String),
    );
  }
}

final planTravelProvider =
    NotifierProvider<PlanTravelController, Map<String, PlanTravel>>(
      PlanTravelController.new,
    );

class PlanTravelController extends Notifier<Map<String, PlanTravel>> {
  late String _key;

  @override
  Map<String, PlanTravel> build() {
    _key = 'plan_travel:${accountScope(ref.watch(sessionProvider))}';
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return {};
    try {
      final rows = (jsonDecode(raw) as List).map(
        (j) => PlanTravel.fromJson(j as Map<String, dynamic>),
      );
      return {for (final r in rows) r.planId: r};
    } catch (_) {
      // 깨진 저장값은 이동 사실로 쓰지 않는다.
      return {};
    }
  }

  /// ID로 먼저, 없으면 제목+시작 시각으로 찾는다.
  PlanTravel? lookup(Plan plan) => lookupIn(state, plan);

  static PlanTravel? lookupIn(Map<String, PlanTravel> all, Plan plan) {
    final byId = all[plan.id];
    if (byId != null) return byId;
    final fp = PlanTravel.fingerprintOf(plan.title, plan.start);
    for (final t in all.values) {
      if (t.fingerprint == fp) return t;
    }
    return null;
  }

  /// [travel]이 null이면 [previousPlanId]의 이동 정보를 지운다.
  Future<void> save(PlanTravel? travel, {String? previousPlanId}) async {
    final next = {...state};
    if (previousPlanId != null) next.remove(previousPlanId);
    if (travel != null) {
      next.removeWhere((_, t) => t.fingerprint == travel.fingerprint);
      next[travel.planId] = travel;
    }
    final key = _key;
    final saved = await ref
        .read(sharedPrefsProvider)
        .setString(key, jsonEncode(next.values.map((t) => t.toJson()).toList()));
    if (!saved) throw StateError('Could not save travel');
    if (ref.mounted && _key == key) state = next;
  }
}
