import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferadar_core/liferadar_core.dart';

import 'plan_travel.dart';
import 'providers.dart';
import 'session.dart';

/// Only connect timed, non-overlapping appointments on the same local day.
bool canConnectPlans(Plan from, Plan to) {
  final start = from.start.toLocal(),
      end = from.end.toLocal(),
      next = to.start.toLocal();
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  return !from.isAllDay &&
      !to.isAllDay &&
      sameDay(start, next) &&
      sameDay(end, next) &&
      !end.isAfter(next);
}

String planRouteKey(Plan from, Plan to) => jsonEncode([from.id, to.id]);

// A route becomes invalid when either appointment's time or location changes.
String _signature(Plan p) => jsonEncode([
  p.id,
  p.start.toIso8601String(),
  p.end.toIso8601String(),
  p.locationText,
  p.location?.lat,
  p.location?.lng,
]);

class PlanRoute {
  const PlanRoute({
    required this.key,
    required this.fromSignature,
    required this.toSignature,
    required this.origin,
    required this.destination,
    required this.originLocation,
    required this.destinationLocation,
    required this.departure,
    required this.durationSeconds,
    required this.lines,
    this.modes = const {},
    this.facilityIds = const {},
    this.points = const [],
  });

  final String key, fromSignature, toSignature, origin, destination;
  final GeoPoint originLocation, destinationLocation;
  final DateTime departure;
  final int durationSeconds;
  final List<String> lines;
  final Set<String> modes, facilityIds;
  final List<GeoPoint> points;
  DateTime get arrival => departure.add(Duration(seconds: durationSeconds));

  bool matches(Plan from, Plan to) =>
      canConnectPlans(from, to) &&
      key == planRouteKey(from, to) &&
      fromSignature == _signature(from) &&
      toSignature == _signature(to);

  factory PlanRoute.fromSearch({
    required Plan from,
    required Plan to,
    required String origin,
    required String destination,
    required GeoPoint originLocation,
    required GeoPoint destinationLocation,
    required DateTime departure,
    required TravelRoute route,
  }) => PlanRoute(
    key: planRouteKey(from, to),
    fromSignature: _signature(from),
    toSignature: _signature(to),
    origin: origin,
    destination: destination,
    departure: departure,
    originLocation: originLocation,
    destinationLocation: destinationLocation,
    durationSeconds: route.durationSeconds,
    lines: List.unmodifiable(route.transitLines),
    modes: route.mode == TravelMode.car ? const {'car'} : Set.unmodifiable(route.transportModes),
    facilityIds: Set.unmodifiable(route.facilityIds),
    points: List.unmodifiable(route.points),
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'from': fromSignature,
    'to': toSignature,
    'origin': origin,
    'destination': destination,
    'departure': departure.toIso8601String(),
    'seconds': durationSeconds,
    'lines': lines,
    'modes': modes.toList()..sort(),
    'facilityIds': facilityIds.toList()..sort(),
    'points': [for (final p in points) [p.lat, p.lng]],
    'originLat': originLocation.lat,
    'originLng': originLocation.lng,
    'destinationLat': destinationLocation.lat,
    'destinationLng': destinationLocation.lng,
  };

  factory PlanRoute.fromJson(Map<String, dynamic> j) => PlanRoute(
    key: j['key'] as String,
    fromSignature: j['from'] as String,
    toSignature: j['to'] as String,
    origin: j['origin'] as String,
    destination: j['destination'] as String,
    departure: DateTime.parse(j['departure'] as String),
    durationSeconds: j['seconds'] as int,
    lines: (j['lines'] as List).cast<String>(),
    modes: Set<String>.from(j['modes'] as List? ?? const []),
    facilityIds: Set<String>.from(j['facilityIds'] as List? ?? const []),
    points: [for (final p in j['points'] as List? ?? const []) GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble())],
    originLocation: GeoPoint(
      (j['originLat'] as num).toDouble(),
      (j['originLng'] as num).toDouble(),
    ),
    destinationLocation: GeoPoint(
      (j['destinationLat'] as num).toDouble(),
      (j['destinationLng'] as num).toDouble(),
    ),
  );
}

/// Only currently adjacent, unchanged appointments may supply route facts.
final tripsByPlanIdProvider = Provider<Map<String, TripContext>>((ref) {
  final plans = [...ref.watch(plansProvider)]..sort((a, b) => a.start.compareTo(b.start));
  final stored = ref.watch(planRoutesProvider);
  final references = ref.watch(newsFeedProvider).transportReferences;
  final trips = <String, TripContext>{};
  for (var index = 1; index < plans.length; index++) {
    final from = plans[index - 1], to = plans[index];
    final r = stored[planRouteKey(from, to)];
    if (r == null || !r.matches(from, to)) continue;
    final ids = {...r.facilityIds, if (to.location != null) ...resolveTripFacilityIds(
      lines: r.lines, modes: r.modes, region: KoreaRegions.regionOf(to.location!),
      departure: r.departure, demo: to.source == 'sample', references: references)};
    trips[to.id] = TripContext(id: r.key, version: jsonEncode([r.toJson(), ids.toList()..sort()]), departure: r.departure,
      arrival: r.arrival, modes: r.modes, facilityIds: ids, lines: r.lines, points: r.points);
  }
  // 앞뒤 일정 경로가 없으면, 일정에 직접 적은 이동 방법을 쓴다.
  final travels = ref.watch(planTravelProvider);
  for (final plan in plans) {
    if (trips.containsKey(plan.id)) continue;
    final travel = PlanTravelController.lookupIn(travels, plan);
    if (travel != null) trips[plan.id] = travel.toTrip(plan, references: references);
  }
  return trips;
});

final planRoutesProvider =
    NotifierProvider<PlanRoutesController, Map<String, PlanRoute>>(
      PlanRoutesController.new,
    );

class PlanRoutesController extends Notifier<Map<String, PlanRoute>> {
  late String _key;

  @override
  Map<String, PlanRoute> build() {
    _key = 'plan_routes:${accountScope(ref.watch(sessionProvider))}';
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return {};
    try {
      final routes = (jsonDecode(raw) as List).map(
        (j) => PlanRoute.fromJson(j as Map<String, dynamic>),
      );
      return {for (final route in routes) route.key: route};
    } catch (_) {
      return {};
    }
  }

  Future<void> save(PlanRoute route) async {
    final next = {...state, route.key: route};
    await _persist(next);
  }

  Future<void> remove(String key) async {
    final next = {...state}..remove(key);
    await _persist(next);
  }

  Future<void> _persist(Map<String, PlanRoute> next) async {
    final key = _key;
    final saved = await ref
        .read(sharedPrefsProvider)
        .setString(
          key,
          jsonEncode(next.values.map((r) => r.toJson()).toList()),
        );
    if (!saved) throw StateError('Could not save route');
    if (ref.mounted && _key == key) state = next;
  }
}
